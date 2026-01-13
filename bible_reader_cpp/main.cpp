#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <vector>
#include <string>

// Minimized C++ Implementation

#define MAX_LINE 4096
#define COLOR_RED "\x1b[31m"
#define COLOR_RESET "\x1b[0m"

static char* normalize(const char* str) {
    static char buf[MAX_LINE * 2];
    char* out = buf;
    while (*str) {
        unsigned char c1 = (unsigned char)str[0];
        if (c1 > 127 && str[1]) {
            unsigned char c2 = (unsigned char)str[1];
            // Romanian Diacritics
            if (c1 == 0xC4 && c2 == 0x83) { *out++ = 'a'; str += 2; continue; } // ă
            if (c1 == 0xC3 && c2 == 0xA2) { *out++ = 'a'; str += 2; continue; } // â
            if (c1 == 0xC3 && c2 == 0xAE) { *out++ = 'i'; str += 2; continue; } // î
            if (c1 == 0xC8 && c2 == 0x99) { *out++ = 's'; str += 2; continue; } // ș
            if (c1 == 0xC5 && c2 == 0x9F) { *out++ = 's'; str += 2; continue; } // ş
            if (c1 == 0xC8 && c2 == 0x9B) { *out++ = 't'; str += 2; continue; } // ț
            if (c1 == 0xC5 && c2 == 0xA3) { *out++ = 't'; str += 2; continue; } // ţ
            if (c1 == 0xC4 && c2 == 0x82) { *out++ = 'a'; str += 2; continue; } // Ă
        }
        *out++ = tolower((unsigned char)*str++);
    }
    *out = 0;
    return buf;
}

static void print_formatted(const char* text) {
    const char* p = text;
    while (*p) {
        if (strncmp(p, "<span class=\\'Isus\\'>", 21) == 0) {
            printf("%s", COLOR_RED); p += 21;
        } else if (strncmp(p, "<span class='Isus'>", 19) == 0) {
            printf("%s", COLOR_RED); p += 19;
        } else if (strncmp(p, "</span>", 7) == 0) {
            printf("%s", COLOR_RESET); p += 7;
        } else {
            putchar(*p); p++;
        }
    }
}

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Usage: %s <list|read|search> [args...]\n", argv[0]);
        return 1;
    }

    const char* command = argv[1];
    
    // Hardcode parent dir for this environment context
    FILE* fp = popen("xz -d -c ../bible_data.txt.xz", "r");
    if (!fp) {
        perror("popen");
        return 1;
    }

    char line[MAX_LINE];
    char current_book[100] = "";
    int current_chapter = 0;
    char current_title[MAX_LINE] = "";
    char last_refs[MAX_LINE] = "";

    // Search Prep
    char query_norm[MAX_LINE] = "";
    if (strcmp(command, "search") == 0 && argc >= 3) {
         // Join args
         std::string q;
         for(int i=2; i<argc; i++) {
             q += argv[i];
             if(i < argc-1) q += " ";
         }
         strcpy(query_norm, normalize(q.c_str()));
    }

    int search_count = 0;
    
    // Read args
    const char* target_book = (argc > 2) ? argv[2] : "";
    int target_chapter = (argc > 3) ? atoi(argv[3]) : 0;
    int target_verse_num = (argc > 4) ? atoi(argv[4]) : 0;

    // Line loop
    while (fgets(line, sizeof(line), fp)) {
        size_t len = strlen(line);
        if (len > 0 && line[len-1] == '\n') line[len-1] = 0;

        if (line[0] == '#') {
            strcpy(current_book, line + 2);
            current_chapter = 0;
            current_title[0] = 0;
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
        
        // Verses start with Digit
        if (isdigit(line[0])) {
            char* verse_end = strchr(line, ' ');
            if (!verse_end) continue;
            
            *verse_end = 0;
            int v_num = atoi(line);
            char* text = verse_end + 1;

            bool match = false;
            
            if (strcmp(command, "read") == 0) {
                 if (strcasecmp(current_book, target_book) == 0 && current_chapter == target_chapter) {
                     if (target_verse_num == 0 || target_verse_num == v_num) {
                         match = true;
                     }
                 }
            } else if (strcmp(command, "search") == 0) {
                 // Optimization: only normalize if needed?
                 // Simple strstr on normalized
                 // Note: normalize returns pointer to static buf, call twice is bad. copy first.
                 char text_norm[MAX_LINE * 2];
                 strcpy(text_norm, normalize(text));
                 if (strstr(text_norm, query_norm)) match = true;
            }

            if (match) {
                 // Check next character in stream for References
                 // PEEK logic from C version
                 int c = fgetc(fp);
                 if (c == 'R') {
                     // Read Refs
                     fgets(last_refs, sizeof(last_refs), fp);
                     last_refs[strcspn(last_refs, "\n")] = 0;
                 } else if (c != EOF) {
                     ungetc(c, fp);
                     last_refs[0] = 0;
                 } else {
                     last_refs[0] = 0;
                 }

                 if (current_title[0]) {
                     printf("\n### %s ###\n", current_title);
                     current_title[0] = 0;
                 }

                 printf("[%d:%d] ", current_chapter, v_num);
                 print_formatted(text);
                 
                 if (last_refs[1]) { // R Refs...
                     printf(" (");
                     char* r = last_refs + 2; // Skip " Renspace"
                     // Wait, line was "R Refs...". fgets read " Refs...".
                     // Actually c='R'. fgets reads " Refs...". so last_refs is " Refs..."
                     // last_refs[0] is space.
                     // C version code: `printf(" (%s)", ref_Line + 1);`
                     // New format: Replace ; with ,
                     char* rp = last_refs + 1; // skip space
                     while(*rp) {
                         if (*rp == ';') printf(", ");
                         else putchar(*rp);
                         rp++;
                     }
                     printf(")");
                 }
                 printf("\n");
                 
                 if (strcmp(command, "search") == 0) {
                     search_count++;
                     if (search_count > 50) return 0;
                 }
            }
            // Clear title after verse processed or skipped
            current_title[0] = 0;
        }
    }

    pclose(fp);
    return 0;
}
