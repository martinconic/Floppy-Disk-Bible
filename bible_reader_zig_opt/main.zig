// const std = @import("std"); // Removed to avoid overhead

// Manual LibC bindings to avoid @cImport hang/overhead
extern "c" fn printf(format: [*:0]const u8, ...) c_int;
extern "c" fn putchar(c: c_int) c_int;
extern "c" fn puts(s: [*:0]const u8) c_int;
extern "c" fn popen(command: [*:0]const u8, mode: [*:0]const u8) ?*anyopaque;
extern "c" fn pclose(stream: *anyopaque) c_int;
// extern "c" fn fgets(s: [*c]u8, size: c_int, stream: *anyopaque) ?[*c]u8; 
extern "c" fn fgets(s: [*c]u8, size: c_int, stream: *anyopaque) [*c]u8; // [*c]u8 is nullable C-pointer
extern "c" fn fgetc(stream: *anyopaque) c_int;
extern "c" fn ungetc(c: c_int, stream: *anyopaque) c_int;
extern "c" fn atoi(nptr: [*c]const u8) c_int;
extern "c" fn strcpy(dest: [*c]u8, src: [*c]const u8) [*c]u8;
extern "c" fn strcasecmp(s1: [*c]const u8, s2: [*c]const u8) c_int;
extern "c" fn strncmp(s1: [*c]const u8, s2: [*c]const u8, n: usize) c_int;
extern "c" fn strchr(s: [*c]const u8, c: c_int) [*c]u8;

const MAX_LINE = 4096;

fn trimNewline(buf: [*c]u8) void {
    var i: usize = 0;
    while (true) : (i += 1) {
        const ch = buf[i];
        if (ch == 0) break;
        if (ch == '\n') {
            buf[i] = 0;
            return;
        }
    }
}

pub export fn main(argc: c_int, argv: [*c][*c]u8) c_int {
    if (argc < 3) {
        _ = printf("Usage: bible_reader_zig_opt read Book <Chap> <Verse>\n");
        return 0;
    }

    const arg_book = argv[2];
    
    var target_chap: c_int = 0;
    if (argc > 3) {
        target_chap = atoi(argv[3]);
    }
    
    var target_verse: c_int = 0;
    if (argc > 4) {
        target_verse = atoi(argv[4]);
    }

    const cmd = "xz -d -c ../bible_data.txt.xz";
    const mode = "r";
    
    const fp = popen(cmd, mode);
    if (fp == null) {
        _ = printf("popen failed\n");
        return 1;
    }
    // defer _ = pclose(fp.?); // Moved to end

    var line_buf: [MAX_LINE]u8 = undefined;
    var book_buf: [100]u8 = undefined;
    var title_buf: [MAX_LINE]u8 = undefined;
    var refs_buf: [MAX_LINE]u8 = undefined;
    
    var current_chap: c_int = 0;
    var has_title = false;
    
    while (true) {
        const ptr = fgets(&line_buf, MAX_LINE, fp.?);
        // check null. In Zig [*c]u8 compared to null?
        // [*c]u8 can be compared to 0? Or use @intFromPtr?
        // idiomatic: if (ptr == null)
        if (ptr == null) break;
        
        const ch = line_buf[0];
        
        if (ch == '#') {
            // Book
            const src: [*c]const u8 = @ptrCast(&line_buf[2]);
            const dest: [*c]u8 = &book_buf;
            _ = strcpy(dest, src);
            trimNewline(dest);
            
            current_chap = 0;
            has_title = false;
        } else if (ch == '=') {
            // Chapter
            const src: [*c]const u8 = @ptrCast(&line_buf[2]);
            current_chap = atoi(src);
            has_title = false;
        } else if (ch == 'T') {
            // Title
            const src: [*c]const u8 = @ptrCast(&line_buf[2]);
            const dest: [*c]u8 = &title_buf;
            _ = strcpy(dest, src);
            trimNewline(dest);
            has_title = true;
        } else if (ch >= '0' and ch <= '9') {
            // Verse
            const v_num_src: [*c]const u8 = @ptrCast(&line_buf[0]);
            const v_num = atoi(v_num_src);
            
            const abook_ptr: [*c]const u8 = @ptrCast(arg_book);
            const book_ptr: [*c]const u8 = &book_buf;
            
            if (strcasecmp(abook_ptr, book_ptr) == 0) {
                if (current_chap == target_chap or target_chap == 0) {
                    if (target_verse == 0 or target_verse == v_num) {
                        
                        const rc = fgetc(fp.?);
                        if (rc == 'R') {
                            _ = fgets(&refs_buf, MAX_LINE, fp.?);
                            trimNewline(&refs_buf);
                        } else {
                            if (rc != -1) {
                                _ = ungetc(rc, fp.?);
                            }
                            refs_buf[0] = 0;
                        }
                        
                        if (has_title) {
                            const t_ptr: [*c]const u8 = &title_buf;
                            _ = printf("\n### %s ###\n", t_ptr);
                            has_title = false;
                        }
                        
                        _ = printf("[%d:%d] ", current_chap, v_num);
                        
                        const l_ptr: [*c]const u8 = &line_buf;
                        const space_ptr = strchr(l_ptr, ' ');
                        if (space_ptr != null) {
                            const text_start = @as([*c]const u8, @ptrCast(space_ptr)) + 1;
                            printFormatted(text_start);
                        }
                        
                        if (refs_buf[0] != 0) {
                            const r_ptr: [*c]const u8 = &refs_buf;
                            _ = printf(" (%s)", r_ptr + 1);
                        }
                        _ = printf("\n");
                    }
                }
            }
            has_title = false;
        }
    }
    _ = pclose(fp.?);
    return 0;
}

fn printFormatted(s: [*c]const u8) void {
    var i: usize = 0;
    const red = "\x1b[31m";
    const reset = "\x1b[0m";
    
    while (true) : (i += 1) {
        const ch = s[i];
        if (ch == 0) break;
        
        if (ch == '<') {
            const curr = s + i;
            if (strncmp(curr, "<span class='Isus'>", 19) == 0) {
                _ = printf(red);
                i += 19;
                continue;
            }
            if (strncmp(curr, "<span class=\"Isus\">", 19) == 0) {
                _ = printf(red);
                i += 19;
                continue;
            }
             if (strncmp(curr, "<span class=\\'Isus\\'>", 21) == 0) {
                _ = printf(red);
                i += 21;
                continue;
            }
            if (strncmp(curr, "</span>", 7) == 0) {
                _ = printf(reset);
                i += 7;
                continue;
            }
        }
        _ = putchar(ch);
    }
}
