#![no_std]
#![no_main]

extern crate libc;

use libc::{c_char, c_int, c_void};
use core::panic::PanicInfo;

// Constants
const MAX_LINE: usize = 4096;

// Helper to convert C string to slice (limited usage)
// We will mostly work with raw pointers for minimal overhead, C-style.



unsafe fn strncmp(s1: *const c_char, s2: *const c_char, n: usize) -> i32 {
    libc::strncmp(s1, s2, n)
}

unsafe fn atoi(s: *const c_char) -> c_int {
    libc::atoi(s)
}

unsafe fn strcasecmp(s1: *const c_char, s2: *const c_char) -> c_int {
    libc::strcasecmp(s1, s2)
}



// Custom formatted print for red text
unsafe fn print_formatted(s: *const c_char) {
    let mut i = 0;
    let red = "\x1b[31m\0";
    let reset = "\x1b[0m\0";
    
    loop {
        let ch = *s.add(i);
        if ch == 0 { break; }
        
        if ch == b'<' as i8 {
            if strncmp(s.add(i), "<span class='Isus'>\0".as_ptr() as *const c_char, 19) == 0 {
                libc::printf(red.as_ptr() as *const c_char);
                i += 19;
                continue;
            }
             if strncmp(s.add(i), "<span class=\"Isus\">\0".as_ptr() as *const c_char, 19) == 0 {
                libc::printf(red.as_ptr() as *const c_char);
                i += 19;
                continue;
            }
             if strncmp(s.add(i), "<span class=\\'Isus\\'>\0".as_ptr() as *const c_char, 21) == 0 {
                libc::printf(red.as_ptr() as *const c_char);
                i += 21;
                continue;
            }
            if strncmp(s.add(i), "</span>\0".as_ptr() as *const c_char, 7) == 0 {
                libc::printf(reset.as_ptr() as *const c_char);
                i += 7;
                continue;
            }
        }
        
        libc::putchar(ch as c_int);
        i += 1;
    }
}

unsafe fn trim_newline(buf: *mut c_char) {
    let mut i = 0;
    loop {
        let ch = *buf.add(i);
        if ch == 0 { break; }
        if ch == b'\n' as i8 {
            *buf.add(i) = 0;
            return;
        }
        i += 1;
    }
}

// Entry Point
#[no_mangle]
pub extern "C" fn main(argc: c_int, argv: *const *const c_char) -> c_int {
    unsafe {
        if argc < 3 {
             libc::printf("Usage: bible_reader_rust_opt read Book <Chap> <Verse>\n\0".as_ptr() as *const c_char);
             return 0;
        }
        
        let arg_book = *argv.add(2);
        
        let mut target_chap = 0;
        if argc > 3 {
            target_chap = atoi(*argv.add(3));
        }
        
        let mut target_verse = 0;
        if argc > 4 {
            target_verse = atoi(*argv.add(4));
        }
        
        let cmd = "xz -d -c ../bible_data.txt.xz\0";
        let mode = "r\0";
        
        let fp = libc::popen(cmd.as_ptr() as *const c_char, mode.as_ptr() as *const c_char);
        if fp.is_null() {
            libc::printf("popen failed\n\0".as_ptr() as *const c_char);
            return 1;
        }
        
        let mut line_buf = [0i8; MAX_LINE];
        let mut book_buf = [0i8; 100];
        let mut title_buf = [0i8; MAX_LINE];
        let mut refs_buf = [0i8; MAX_LINE];
        
        let mut current_chap = 0;
        let mut has_title = false;
        
        let line_ptr = line_buf.as_mut_ptr();
        let book_ptr = book_buf.as_mut_ptr();
        let title_ptr = title_buf.as_mut_ptr();
        let refs_ptr = refs_buf.as_mut_ptr();
        
        loop {
            let ptr = libc::fgets(line_ptr, MAX_LINE as c_int, fp);
            if ptr.is_null() { break; }
            
            let ch = *line_ptr;
            
            if ch == b'#' as i8 {
                // Book
                // Skip "# " (2 chars)
                let content = line_ptr.add(2);
                let _ = libc::strcpy(book_ptr, content); 
                trim_newline(book_ptr);
                
                current_chap = 0;
                has_title = false;
            } else if ch == b'=' as i8 {
                // Chapter
                let content = line_ptr.add(2);
                current_chap = atoi(content);
                has_title = false;
            } else if ch == b'T' as i8 {
                // Title
                let content = line_ptr.add(2);
                let _ = libc::strcpy(title_ptr, content);
                trim_newline(title_ptr);
                has_title = true;
            } else if ch >= b'0' as i8 && ch <= b'9' as i8 {
                // Verse
                let v_num = atoi(line_ptr);
                
                if strcasecmp(arg_book, book_ptr) == 0 {
                    if current_chap == target_chap || target_chap == 0 {
                        if target_verse == 0 || target_verse == v_num {
                            
                            // Check Refs
                            let rc = libc::fgetc(fp);
                            if rc == b'R' as c_int {
                                libc::fgets(refs_ptr, MAX_LINE as c_int, fp);
                                trim_newline(refs_ptr);
                            } else {
                                if rc != -1 {
                                    libc::ungetc(rc, fp);
                                }
                                *refs_ptr = 0;
                            }
                            
                            if has_title {
                                libc::printf("\n### %s ###\n\0".as_ptr() as *const c_char, title_ptr);
                                has_title = false;
                            }
                            
                            libc::printf("[%d:%d] \0".as_ptr() as *const c_char, current_chap, v_num);
                            
                            // Text
                            let space_ptr = libc::strchr(line_ptr, b' ' as c_int);
                            if !space_ptr.is_null() {
                                let text_start = space_ptr.add(1);
                                print_formatted(text_start);
                            }
                            
                            if *refs_ptr != 0 {
                                // Usually starts with space?
                                libc::printf(" (%s)\0".as_ptr() as *const c_char, refs_ptr.add(1));
                            }
                            libc::printf("\n\0".as_ptr() as *const c_char);
                        }
                    }
                }
                has_title = false;
            }
        }
        
        libc::pclose(fp);
    }
    0
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    unsafe {
        libc::abort();
    }
}
