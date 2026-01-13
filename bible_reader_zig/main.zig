const std = @import("std");

const MAX_LINE = 4096;
const COLOR_RED = "\x1b[31m";
const COLOR_RESET = "\x1b[0m";

// Custom readLine using unbuffered read from File directly
fn readLine(file: std.fs.File, out: []u8) !?[]u8 {
    var i: usize = 0;
    while (i < out.len) {
        var byte: [1]u8 = undefined;
        // Direct read from file (unbuffered syscall)
        const n = try file.read(&byte);
        if (n == 0) {
            if (i == 0) return null;
            return out[0..i];
        }
        if (byte[0] == '\n') return out[0..i];
        out[i] = byte[0];
        i += 1;
    }
    return error.StreamTooLong;
}

// Normalizer
fn normalize(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, 0);
    var i: usize = 0;
    while (i < input.len) {
        if (i + 1 < input.len) {
            const c1 = input[i];
            const c2 = input[i+1];
            // Romanian Diacritics (UTF-8)
            if (c1 == 0xC4 and c2 == 0x83) { try out.append(allocator, 'a'); i += 2; continue; } // ă
            if (c1 == 0xC3 and c2 == 0xA2) { try out.append(allocator, 'a'); i += 2; continue; } // â
            if (c1 == 0xC3 and c2 == 0xAE) { try out.append(allocator, 'i'); i += 2; continue; } // î
            if (c1 == 0xC8 and c2 == 0x99) { try out.append(allocator, 's'); i += 2; continue; } // ș
            if (c1 == 0xC5 and c2 == 0x9F) { try out.append(allocator, 's'); i += 2; continue; } // ş
            if (c1 == 0xC8 and c2 == 0x9B) { try out.append(allocator, 't'); i += 2; continue; } // ț
            if (c1 == 0xC5 and c2 == 0xA3) { try out.append(allocator, 't'); i += 2; continue; } // ţ
            // Upper cases
            if (c1 == 0xC4 and c2 == 0x82) { try out.append(allocator, 'a'); i += 2; continue; } // Ă
        }
        const c = input[i];
        if (c < 128) {
             try out.append(allocator, std.ascii.toLower(c));
        } else {
             try out.append(allocator, c);
        }
        i += 1;
    }
    return out.toOwnedSlice(allocator);
}

fn printFormatted(text: []const u8) void {
    var i: usize = 0;
    while (i < text.len) {
        if (std.mem.startsWith(u8, text[i..], "<span class=\\'Isus\\'>")) {
            std.debug.print("{s}", .{COLOR_RED});
            i += 21;
        } else if (std.mem.startsWith(u8, text[i..], "<span class='Isus'>")) {
             std.debug.print("{s}", .{COLOR_RED});
             i += 19;
        } else if (std.mem.startsWith(u8, text[i..], "</span>")) {
            std.debug.print("{s}", .{COLOR_RESET});
            i += 7;
        } else {
            std.debug.print("{c}", .{text[i]});
            i += 1;
        }
    }
}

const VerseData = struct {
    book: []const u8,
    chapter: i32,
    verse: i32,
    text: []const u8, // Owned
    title: ?[]const u8, // Owned
    refs: ?[]const u8, // Owned
};

fn freeVerseData(allocator: std.mem.Allocator, v: *VerseData) void {
    allocator.free(v.book);
    allocator.free(v.text);
    if (v.title) |t| allocator.free(t);
    if (v.refs) |r| allocator.free(r);
}

fn printVerse(v: VerseData) void {
    if (v.title) |title| {
        std.debug.print("\n### {s} ###\n", .{title});
    }
    std.debug.print("[{d}:{d}] ", .{v.chapter, v.verse});
    printFormatted(v.text);
    if (v.refs) |r| {
        std.debug.print(" (", .{});
        var i: usize = 0;
        while (i < r.len) {
            if (r[i] == ';') {
                std.debug.print(", ", .{});
            } else {
                std.debug.print("{c}", .{r[i]});
            }
            i += 1;
        }
        std.debug.print(")", .{});
    }
    std.debug.print("\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <list|read|search> [args...]\n", .{args[0]});
        return;
    }

    const command = args[1];
    const file_path = "../bible_data.txt.xz";
    const argv = [_][]const u8{ "xz", "-d", "-c", file_path };
    
    var child = std.process.Child.init(&argv, allocator);
    child.stdout_behavior = .Pipe;
    
    child.spawn() catch |err| {
        std.debug.print("Error spawning xz: {}\n", .{err});
        return;
    };
    
    var buf: [MAX_LINE]u8 = undefined;

    var current_book = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer current_book.deinit(allocator);
    var current_chapter: i32 = 0;
    var current_title: ?[]u8 = null; // Stored title
    var pending_verse: ?VerseData = null;

    var query_norm: []u8 = &[_]u8{};
    if (std.mem.eql(u8, command, "search") and args.len >= 3) {
         var raw_query = try std.ArrayList(u8).initCapacity(allocator, 0);
         defer raw_query.deinit(allocator);
         var i: usize = 2;
         while(i < args.len) : (i += 1) {
             try raw_query.appendSlice(allocator, args[i]);
             if (i < args.len - 1) try raw_query.append(allocator, ' ');
         }
         query_norm = try normalize(allocator, raw_query.items);
    }
    defer if (query_norm.len > 0) allocator.free(query_norm);
    
    var search_count: i32 = 0;
    const target_book = if (args.len > 2) args[2] else "";
    const target_chapter = if (args.len > 3) try std.fmt.parseInt(i32, args[3], 10) else 0;
    var target_verse_num: i32 = 0;
    if (args.len > 4) target_verse_num = try std.fmt.parseInt(i32, args[4], 10);

    // Pass File directly to readLine
    while (try readLine(child.stdout.?, &buf)) |line| {
        if (line.len == 0) continue;
        
        if (std.mem.startsWith(u8, line, "R ")) {
            if (pending_verse) |*v| {
                v.refs = try allocator.dupe(u8, line[2..]);
            }
            continue;
        }

        if (pending_verse) |*v| {
            printVerse(v.*);
            freeVerseData(allocator, v);
            pending_verse = null;
        }

        if (std.mem.startsWith(u8, line, "# ")) {
            current_book.clearRetainingCapacity();
            try current_book.appendSlice(allocator, line[2..]);
            current_chapter = 0;
            if (current_title) |t| { allocator.free(t); current_title = null; }
            continue;
        }

        if (std.mem.startsWith(u8, line, "= ")) {
            current_chapter = try std.fmt.parseInt(i32, line[2..], 10);
            if (current_title) |t| { allocator.free(t); current_title = null; }
            continue;
        }
        
        if (std.mem.startsWith(u8, line, "T ")) {
             if (current_title) |t| allocator.free(t);
             current_title = try allocator.dupe(u8, line[2..]);
             continue;
        }

        if (std.ascii.isDigit(line[0])) {
            var it = std.mem.splitScalar(u8, line, ' ');
            const verse_str = it.first();
            const v_num = try std.fmt.parseInt(i32, verse_str, 10);
            const text = line[verse_str.len + 1 ..];

            var match = false;
            if (std.mem.eql(u8, command, "read")) {
                 if (std.ascii.eqlIgnoreCase(current_book.items, target_book) and current_chapter == target_chapter) {
                     if (target_verse_num == 0 or target_verse_num == v_num) {
                         match = true;
                     }
                 }
            } else if (std.mem.eql(u8, command, "search")) {
                 const text_norm = try normalize(allocator, text);
                 defer allocator.free(text_norm);
                 if (std.mem.indexOf(u8, text_norm, query_norm) != null) {
                      match = true;
                      search_count += 1;
                 }
            }

            if (match) {
                var title_copy: ?[]u8 = null;
                if (current_title) |t| {
                    title_copy = try allocator.dupe(u8, t);
                    allocator.free(t);
                    current_title = null;
                }
                pending_verse = VerseData{
                    .book = try allocator.dupe(u8, current_book.items),
                    .chapter = current_chapter,
                    .verse = v_num,
                    .text = try allocator.dupe(u8, text),
                    .title = title_copy,
                    .refs = null
                };
            }
            if (current_title) |t| { allocator.free(t); current_title = null; }
            if (std.mem.eql(u8, command, "search") and search_count > 50) break;
        }
    }
    
    if (pending_verse) |*v| {
        printVerse(v.*);
        freeVerseData(allocator, v);
    }
}
