package main

import "core:c"
import "core:os"
import "core:sys/posix"

// LibC Bindings
foreign import libc "system:c"

FILE :: struct {}

foreign libc {
    popen :: proc(command: cstring, mode: cstring) -> ^FILE ---
    pclose :: proc(stream: ^FILE) -> c.int ---
    fgets :: proc(s: cstring, size: c.int, stream: ^FILE) -> cstring ---
    fgetc :: proc(stream: ^FILE) -> c.int ---
    ungetc :: proc(char: c.int, stream: ^FILE) -> c.int ---
    strcasecmp :: proc(s1: cstring, s2: cstring) -> c.int ---
    atoi :: proc(str: cstring) -> c.int ---
    strchr :: proc(s: cstring, c: c.int) -> cstring ---
    strlen :: proc(s: cstring) -> c.size_t ---
    strncmp :: proc(s1: cstring, s2: cstring, n: c.size_t) -> c.int ---
    printf :: proc(fmt: cstring, #c_vararg args: ..any) -> c.int ---
    @(link_name="putchar")
    libc_putchar :: proc(ch: c.int) -> c.int ---
}

MAX_LINE :: 4096

main :: proc() {
    args := os.args
    if len(args) < 3 {
        printf("Usage: bible_reader_odin read Book <Chap> <Verse>\n")
        return
    }

    arg_book := args[2]
    
    target_chap := 0
    if len(args) > 3 {
        target_chap = parse_int(args[3])
    }
    
    target_verse := 0
    if len(args) > 4 {
        target_verse = parse_int(args[4])
    }

    // Buffers
    line_buf := [MAX_LINE]u8{}
    book_buf := [100]u8{}
    title_buf := [MAX_LINE]u8{}
    refs_buf := [MAX_LINE]u8{}
    
    // Command
    cmd_xz := "xz -d -c ../bible_data.txt.xz"
    cmd_cstr := strings_clone_to_cstring(cmd_xz)
    mode_r := strings_clone_to_cstring("r")
    
    fp := popen(cmd_cstr, mode_r)
    if fp == nil {
        printf("popen failed\n")
        return
    }
    
    // We need arg_book as cstring for comparison
    arg_book_cstr := strings_clone_to_cstring(arg_book)

    current_chap := 0
    has_title := false
    
    for {
        ptr := fgets(cstring(&line_buf[0]), MAX_LINE, fp)
        if ptr == nil do break
        
        trim_newline(cstring(&line_buf[0]))
        
        ch := line_buf[0]
        
        if ch == '#' {
            // Book: # Gen...
            copy_string(cstring(&book_buf[0]), cstring(&line_buf[2]))
            trim_newline(cstring(&book_buf[0]))
            
            current_chap = 0
            has_title = false
        } else if ch == '=' {
            // Chapter: = 1
            current_chap = int(atoi(cstring(&line_buf[2])))
            has_title = false
        } else if ch == 'T' {
            // Title
            copy_string(cstring(&title_buf[0]), cstring(&line_buf[2]))
            trim_newline(cstring(&title_buf[0]))
            has_title = true
        } else if ch >= '0' && ch <= '9' {
            // Verse
            v_num := int(atoi(cstring(&line_buf[0])))
            
            // Match Logic
            if strcasecmp(arg_book_cstr, cstring(&book_buf[0])) == 0 {
                if (current_chap == target_chap || target_chap == 0) {
                     if (target_verse == 0 || target_verse == v_num) {
                         
                         // Check Refs
                         rc := fgetc(fp)
                         if rc == 'R' {
                             fgets(cstring(&refs_buf[0]), MAX_LINE, fp)
                             trim_newline(cstring(&refs_buf[0]))
                         } else {
                             if rc != -1 do ungetc(rc, fp)
                             refs_buf[0] = 0 // Clear
                         }
                         
                         if has_title {
                             printf("\n### %s ###\n", cstring(&title_buf[0]))
                             has_title = false
                         }
                         
                         printf("[%d:%d] ", c.int(current_chap), c.int(v_num))
                         
                         // Print text (find space)
                         text_ptr := strchr(cstring(&line_buf[0]), ' ')
                         if text_ptr != nil {
                             // Advance past space
                             text_start := cstring(rawptr(uintptr(rawptr(text_ptr)) + 1))
                             print_formatted(text_start)
                         }
                         
                         if refs_buf[0] != 0 {
                             printf(" (%s)", cstring(&refs_buf[1])) 
                         }
                         printf("\n")
                     }
                }
            }
            has_title = false
        }
    }
    
    pclose(fp)
}

// Helpers

parse_int :: proc(s: string) -> int {
    n := 0
    for c in s {
        if c >= '0' && c <= '9' {
            n = n * 10 + int(c - '0')
        }
    }
    return n
}

strings_clone_to_cstring :: proc(s: string) -> cstring {
    data := make([]u8, len(s) + 1)
    copy(data, s)
    data[len(s)] = 0
    return cstring(&data[0])
}

copy_string :: proc(dest: cstring, src: cstring) {
    d := get_u8_ptr(dest)
    s := get_u8_ptr(src)
    i := 0
    for {
        b := s[i]
        d[i] = b
        if b == 0 do break
        i += 1
    }
}

trim_newline :: proc(s: cstring) {
    p := get_u8_ptr(s)
    i := 0
    for {
        if p[i] == 0 do break
        if p[i] == '\n' {
            p[i] = 0
            return
        }
        i += 1
    }
}

get_u8_ptr :: proc(s: cstring) -> [^]u8 {
    return cast([^]u8) s
}

print_formatted :: proc(s: cstring) {
    p := get_u8_ptr(s)
    i := 0
    
    // ANSI
    red := cstring("\x1b[31m")
    reset := cstring("\x1b[0m")
    
    for {
        ch := p[i]
        if ch == 0 do break
        
        // Check span class='Isus'
        if ch == '<' {
             if check_prefix(p, i, "<span class='Isus'>") {
                 printf("%s", red)
                 i += 19
                 continue
             }
             if check_prefix(p, i, "<span class=\"Isus\">") {
                 printf("%s", red)
                 i += 19 
                 continue
             }
             if check_prefix(p, i, "</span>") {
                 printf("%s", reset)
                 i += 7
                 continue
             }
        }
        
        libc_putchar(c.int(ch))
        i += 1
    }
}

check_prefix :: proc(p: [^]u8, offset: int, needle: string) -> bool {
    for j := 0; j < len(needle); j += 1 {
        if p[offset + j] != needle[j] do return false
    }
    return true
}
