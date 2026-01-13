#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define MAX_LINE 4096
#define COLOR_RED "\x1b[31m"
#define COLOR_RESET "\x1b[0m"

// Function to normalize string (remove diacritics and lowercase)
// Returning a static buffer for simplicity in this small tool
char* normalize(const char* str) {
    static char buf[MAX_LINE * 2]; // *2 for safety
    char* out = buf;
    
    while (*str) {
        // Handle lowercasing basic ASCII
        if ((*str >= 'A' && *str <= 'Z')) {
            *out++ = *str + 32;
            str++;
            continue;
        }

        // Handle specific Romanian diacritics bytes (UTF-8)
        // ă: c4 83 -> a
        // â: c3 a2 -> a
        // î: c3 ae -> i
        // ș: c8 99 -> s  (comma below)
        // ş: c5 9f -> s  (cedilla)
        // ț: c8 9b -> t  (comma below)
        // ţ: c5 a3 -> t  (cedilla)
        // Also uppercase variants if any appear, though we lowercase first usually.
        // Actually, let's just match the bytes.
        
        unsigned char c1 = (unsigned char)str[0];
        unsigned char c2 = (unsigned char)str[1];
        
        if (c1 == 0xC4 && c2 == 0x83) { *out++ = 'a'; str += 2; continue; } // ă
        if (c1 == 0xC3 && c2 == 0xA2) { *out++ = 'a'; str += 2; continue; } // â
        if (c1 == 0xC3 && c2 == 0xAE) { *out++ = 'i'; str += 2; continue; } // î
        if (c1 == 0xC8 && c2 == 0x99) { *out++ = 's'; str += 2; continue; } // ș
        if (c1 == 0xC5 && c2 == 0x9F) { *out++ = 's'; str += 2; continue; } // ş
        if (c1 == 0xC8 && c2 == 0x9B) { *out++ = 't'; str += 2; continue; } // ț
        if (c1 == 0xC5 && c2 == 0xA3) { *out++ = 't'; str += 2; continue; } // ţ

        // Upper case diacritics handling just in case
        if (c1 == 0xC4 && c2 == 0x82) { *out++ = 'a'; str += 2; continue; } // Ă
        if (c1 == 0xC3 && c2 == 0x82) { *out++ = 'a'; str += 2; continue; } // Â
        if (c1 == 0xC3 && c2 == 0x8E) { *out++ = 'i'; str += 2; continue; } // Î
        if (c1 == 0xC8 && c2 == 0x98) { *out++ = 's'; str += 2; continue; } // Ș
        if (c1 == 0xC5 && c2 == 0x9E) { *out++ = 's'; str += 2; continue; } // Ş
        if (c1 == 0xC8 && c2 == 0x9A) { *out++ = 't'; str += 2; continue; } // Ț
        if (c1 == 0xC5 && c2 == 0xA2) { *out++ = 't'; str += 2; continue; } // Ţ

        // Copy other chars as is (but lowercase if ASCII)
        if ((unsigned char)*str < 128) {
             *out++ = tolower(*str);
        } else {
             *out++ = *str;
        }
        str++;
    }
    *out = 0;
    return buf;
}

void print_formatted(const char* text) {
    const char* p = text;
    while (*p) {
        if (strncmp(p, "<span class=\\'Isus\\'>", 21) == 0) {
            printf("%s", COLOR_RED);
            p += 21;
        } else if (strncmp(p, "<span class='Isus'>", 19) == 0) {
             printf("%s", COLOR_RED);
             p += 19;
        } else if (strncmp(p, "</span>", 7) == 0) {
            printf("%s", COLOR_RESET);
            p += 7;
        } else {
            putchar(*p);
            p++;
        }
    }
}

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Usage: %s <list|read|search> [args...]\n", argv[0]);
        return 1;
    }

    char* command = argv[1];
    
    // Open compressed file stream
    // Using relative path assuming binary is in same dir as data or parent
    // Try local first then ../
    FILE* fp = popen("xz -d -c bible_data.txt.xz 2>/dev/null || xz -d -c ../bible_data.txt.xz", "r");
    if (!fp) {
        fprintf(stderr, "Error: Could not open bible_data.txt.xz (install xz-utils)\n");
        return 1;
    }

    char line[MAX_LINE];
    char current_book[100] = "";
    int current_chapter = 0;
    char current_title[MAX_LINE] = "";
    char last_refs[MAX_LINE] = ""; // To store refs for previous verse, strictly implementation might differ
    
    // For SEARCH: pre-normalize query
    char query_norm[MAX_LINE] = "";
    if (strcmp(command, "search") == 0 && argc >= 3) {
        // join args
        char raw_query[MAX_LINE] = "";
        for(int i=2; i<argc; i++) {
            strcat(raw_query, argv[i]);
            if(i<argc-1) strcat(raw_query, " ");
        }
        strcpy(query_norm, normalize(raw_query));
    }

    // For LIST
    int listed_books = 0;

    int search_count = 0;

    while (fgets(line, sizeof(line), fp)) {
        // Strip newline
        line[strcspn(line, "\n")] = 0;
        if (strlen(line) == 0) continue;

        if (line[0] == '#') {
            strcpy(current_book, line + 2);
            current_chapter = 0;
            current_title[0] = 0;
            
            if (strcmp(command, "list") == 0) {
                printf("- %s\n", current_book);
            }
            continue;
        }

        if (line[0] == '=') {
            current_chapter = atoi(line + 2);
            current_title[0] = 0;
            continue;
        }

        if (line[0] == 'T') {
            strcpy(current_title, line + 2);
            continue;
        }
        
        if (line[0] == 'R') {
             // Refs line, usually follows a verse but for now we process stream linearly
             // logic: verse printed -> refs follows. 
             // In this loop we process line by line.
             // If we just printed a verse, and now see R, we should have printed it?
             // Actually: The format is Verse then R. 
             // If we want to print R with the verse, we'd need to peek ahead or buffer.
             // In C stream, peeking is hard. 
             // Alternative: Store the previous verse and print ON THE NEXT iteration?
             
             // Simpler approach for this version: Just print on new line indented if matching
             continue; 
        }

        // Verse line? Starts with digit
        if (isdigit(line[0])) {
            char* text_start = strchr(line, ' ');
            if (!text_start) continue;
            *text_start = 0; // null terminate verse num
            int verse_num = atoi(line);
            char* text = text_start + 1;

            if (strcmp(command, "read") == 0) {
                 if (argc < 4) continue;
                 char* target_book = argv[2];
                 int target_chapter = atoi(argv[3]);
                 int target_verse = 0;
                 if (argc >= 5) target_verse = atoi(argv[4]);

                 if (strcasecmp(current_book, target_book) == 0 && current_chapter == target_chapter) {
                     if (target_verse == 0 || target_verse == verse_num) {
                         if (current_title[0]) {
                             printf("\n### %s ###\n", current_title);
                             // don't clear here, clear after block
                         }
                         printf("[%d:%d] ", current_chapter, verse_num);
                         print_formatted(text);
                         
                         int c = fgetc(fp);
                         if (c == 'R') {
                             char ref_Line[MAX_LINE];
                             fgets(ref_Line, sizeof(ref_Line), fp);
                             ref_Line[strcspn(ref_Line, "\n")] = 0;
                             // ref_Line contains " Refs...", skip space at 0
                             char* refs = ref_Line + 1;
                             printf(" (");
                             while(*refs) {
                                 if(*refs == ';') printf(", ");
                                 else putchar(*refs);
                                 refs++;
                             }
                             printf(")");
                         } else if (c != EOF) {
                             ungetc(c, fp);
                         }
                         
                         printf("\n");
                     }
                 }
            } else if (strcmp(command, "search") == 0) {
                 // Check if text matches normalized query
                 // Normalize text
                 char* norm_text = normalize(text);
                 if (strstr(norm_text, query_norm)) {
                      printf("%s %d:%d - ", current_book, current_chapter, verse_num);
                      print_formatted(text);
                      printf("\n");
                      search_count++;
                      if (search_count > 50) {
                          printf("... too many results\n");
                          break;
                      }
                 }
            }
            // IMPORTANT: Clear title after processing the verse line,
            // regardless of whether we printed it or not. 
            // The title applies ONLY to this verse.
            current_title[0] = 0;
        }
        }

    pclose(fp);
    return 0;
}
