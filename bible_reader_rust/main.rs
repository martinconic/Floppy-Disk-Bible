use std::env;
use std::process::{Command, Stdio};
use std::io::{BufRead, BufReader};

// Minimal Rust Implementation

const COLOR_RED: &str = "\x1b[31m";
const COLOR_RESET: &str = "\x1b[0m";

fn normalize(s: &str) -> String {
    // Basic normalization for search: Lowercase and remove common diacritics
    let mut out = String::with_capacity(s.len());
    let chars: Vec<char> = s.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        let c = chars[i];
        // Check next for combining or specific codes? 
        // Rust string handling is UTF-8 native.
        // Simple replacements for common Romanian chars
        match c {
            'ă' | 'Ă' | 'â' | 'Â' => out.push('a'),
            'î' | 'Î' => out.push('i'),
            'ș' | 'Ș' | 'ş' | 'Ş' => out.push('s'),
            'ț' | 'Ț' | 'ţ' | 'Ţ' => out.push('t'),
            _ => out.push(c.to_lowercase().next().unwrap_or(c)),
        }
        i += 1;
    }
    out
}

fn print_formatted(text: &str) {
    let mut p = text;
    while !p.is_empty() {
        if p.starts_with("<span class=\\'Isus\\'>") {
            print!("{}", COLOR_RED);
            p = &p[21..];
        } else if p.starts_with("<span class='Isus'>") {
            print!("{}", COLOR_RED);
            p = &p[19..];
        } else if p.starts_with("</span>") {
            print!("{}", COLOR_RESET);
            p = &p[7..];
        } else {
            let ch = p.chars().next().unwrap();
            print!("{}", ch);
            p = &p[ch.len_utf8()..];
        }
    }
}

fn main() -> std::io::Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        println!("Usage: {} <list|read|search> [args...]", args[0]);
        return Ok(());
    }

    let command_arg = &args[1];
    
    // xz stream
    let child = Command::new("xz")
        .args(&["-d", "-c", "../bible_data.txt.xz"])
        .stdout(Stdio::piped())
        .spawn()?;

    let stdout = child.stdout.ok_or_else(|| std::io::Error::new(std::io::ErrorKind::Other, "Could not capture stdout"))?;
    let mut reader = BufReader::new(stdout);
    
    // State
    let mut current_book = String::new();
    let mut current_chapter = 0;
    let mut current_title = String::new();
    let mut pending_verse: Option<(String, i32, i32, String, String)> = None; // (Book, Chap, Verse, Text, Title)

    // Search Prep
    let query_norm = if command_arg == "search" && args.len() >= 3 {
        normalize(&args[2..].join(" "))
    } else {
        String::new()
    };
    
    let mut search_count = 0;
    let target_book = if args.len() > 2 { args[2].as_str() } else { "" };
    let target_chapter: i32 = if args.len() > 3 { args[3].parse().unwrap_or(0) } else { 0 };
    let target_verse_num: i32 = if args.len() > 4 { args[4].parse().unwrap_or(0) } else { 0 };

    let mut line = String::new();
    while reader.read_line(&mut line)? > 0 {
        let trimmed = line.trim_end();
        if trimmed.is_empty() {
            line.clear();
            continue;
        }

        if trimmed.starts_with("R ") {
            if let Some((_, _, _, _, _)) = pending_verse {
                // Print pending
                print_verse(&pending_verse.take().unwrap(), Some(&trimmed[2..]));
            }
            line.clear();
            continue;
        }

        // Flush pending if not R
        if let Some((_, _, _, _, _)) = pending_verse {
            print_verse(&pending_verse.take().unwrap(), None);
        }

        if trimmed.starts_with("# ") {
            current_book = trimmed[2..].to_string();
            current_chapter = 0;
            current_title.clear();
        } else if trimmed.starts_with("= ") {
            current_chapter = trimmed[2..].parse().unwrap_or(0);
            current_title.clear();
        } else if trimmed.starts_with("T ") {
            current_title = trimmed[2..].to_string();
        } else if trimmed.chars().next().map_or(false, |c| c.is_digit(10)) {
            // Verse
            if let Some((v_num_str, text)) = trimmed.split_once(' ') {
                let v_num: i32 = v_num_str.parse().unwrap_or(0);
                
                let mut match_found = false;
                if command_arg == "read" {
                    if current_book.eq_ignore_ascii_case(target_book) && current_chapter == target_chapter {
                        if target_verse_num == 0 || target_verse_num == v_num {
                            match_found = true;
                        }
                    }
                } else if command_arg == "search" {
                    let text_norm = normalize(text);
                    if text_norm.contains(&query_norm) {
                        match_found = true;
                        search_count += 1;
                    }
                }

                if match_found {
                    // Store as pending
                    pending_verse = Some((
                        current_book.clone(),
                        current_chapter,
                        v_num,
                        text.to_string(),
                        current_title.clone()
                    ));
                }
                // Clear title
                current_title.clear();

                if command_arg == "search" && search_count > 50 {
                    break;
                }
            }
        }

        line.clear();
    }
    
    // Flush final
    if let Some((_, _, _, _, _)) = pending_verse {
        print_verse(&pending_verse.take().unwrap(), None);
    }

    Ok(())
}

fn print_verse(v: &(String, i32, i32, String, String), refs: Option<&str>) {
    let (book, chap, v_num, text, title) = v;
    if !title.is_empty() {
        println!("\n### {} ###", title);
    }
    
    // If search, print Book Name
    // Actually, C version behaviour:
    // Read: `[ch:v] Text`
    // Search: `Book ch:v - Text`
    // Wait, let's allow basic matching.
    // The previous output `[3:16] Fiindcă...` suggests Read format.
    // Let's stick to standard format for now.
    
    print!("[{}:{}] ", chap, v_num);
    print_formatted(text);
    
    if let Some(r) = refs {
        print!(" (");
        // Replace ; with ,
        // "Rom 5.8;1Ioan 4.9" -> "Rom 5.8, 1Ioan 4.9"
        // Also ensure space?
        // simple replace
        print!("{}", r.replace(";", ", "));
        print!(")");
    }
    println!("");
}
