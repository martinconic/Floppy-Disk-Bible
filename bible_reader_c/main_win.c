#include <ctype.h>
#include <fcntl.h> // _O_U16TEXT, _O_TEXT
#include <io.h>    // _setmode, _access
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


// Windows compatibility macros
#define popen _popen
#define pclose _pclose
#define strcasecmp _stricmp
#define snprintf _snprintf
#define access _access
#define F_OK 0

#define MAX_LINE 4096

// ANSI Colors
#define COLOR_RED "\x1b[31m"
#define COLOR_RESET "\x1b[0m"

// Function to normalize string
char *normalize(const char *str) {
  static char buf[MAX_LINE * 2];
  char *out = buf;

  while (*str) {
    // Handle lowercasing basic ASCII
    if ((*str >= 'A' && *str <= 'Z')) {
      *out++ = *str + 32;
      str++;
      continue;
    }

    // Handle specific Romanian diacritics bytes (UTF-8)
    unsigned char c1 = (unsigned char)str[0];
    unsigned char c2 = (unsigned char)str[1];

    if (c1 == 0xC4 && c2 == 0x83) {
      *out++ = 'a';
      str += 2;
      continue;
    } // ă
    if (c1 == 0xC3 && c2 == 0xA2) {
      *out++ = 'a';
      str += 2;
      continue;
    } // â
    if (c1 == 0xC3 && c2 == 0xAE) {
      *out++ = 'i';
      str += 2;
      continue;
    } // î
    if (c1 == 0xC8 && c2 == 0x99) {
      *out++ = 's';
      str += 2;
      continue;
    } // ș
    if (c1 == 0xC5 && c2 == 0x9F) {
      *out++ = 's';
      str += 2;
      continue;
    } // ş
    if (c1 == 0xC8 && c2 == 0x9B) {
      *out++ = 't';
      str += 2;
      continue;
    } // ț
    if (c1 == 0xC5 && c2 == 0xA3) {
      *out++ = 't';
      str += 2;
      continue;
    } // ţ

    // Upper case diacritics handling just in case
    if (c1 == 0xC4 && c2 == 0x82) {
      *out++ = 'a';
      str += 2;
      continue;
    } // Ă
    if (c1 == 0xC3 && c2 == 0x82) {
      *out++ = 'a';
      str += 2;
      continue;
    } // Â
    if (c1 == 0xC3 && c2 == 0x8E) {
      *out++ = 'i';
      str += 2;
      continue;
    } // Î
    if (c1 == 0xC8 && c2 == 0x98) {
      *out++ = 's';
      str += 2;
      continue;
    } // Ș
    if (c1 == 0xC5 && c2 == 0x9E) {
      *out++ = 's';
      str += 2;
      continue;
    } // Ş
    if (c1 == 0xC8 && c2 == 0x9A) {
      *out++ = 't';
      str += 2;
      continue;
    } // Ț
    if (c1 == 0xC5 && c2 == 0xA2) {
      *out++ = 't';
      str += 2;
      continue;
    } // Ţ

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

void print_formatted(const char *text) {
  const char *p = text;
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

int main(int argc, char **argv) {
  // Enable UTF-8 output on Windows
  system("chcp 65001 > NUL");

  if (argc < 2) {
    printf("Usage: %s <list|read|search> [args...]\n", argv[0]);
    return 1;
  }

  char *command = argv[1];

  // 1. Locate the data file
  const char *data_file = "bible_data.tar.bz2";
  if (access(data_file, F_OK) == -1) {
    data_file = "..\\bible_data.tar.bz2";
    if (access(data_file, F_OK) == -1) {
      fprintf(stderr, "Error: bible_data.tar.bz2 not found in current or "
                      "parent directory.\n");
      return 1;
    }
  }

  // 2. Construct command
  // Use tar with -xjOf to decompress bzip2 to stdout
  char cmd[1024];
  // Note: tar on Windows (bsdtar) supports -j for bzip2
  snprintf(cmd, sizeof(cmd), "tar -xjOf \"%s\"", data_file);

  FILE *fp = popen(cmd, "r");
  if (!fp) {
    fprintf(stderr, "Error: popen failed. (System error)\n");
    return 1;
  }

  char line[MAX_LINE];
  char current_book[100] = "";
  int current_chapter = 0;
  char current_title[MAX_LINE] = "";

  // For SEARCH: pre-normalize query
  char query_norm[MAX_LINE] = "";
  if (strcmp(command, "search") == 0 && argc >= 3) {
    char raw_query[MAX_LINE] = "";
    for (int i = 2; i < argc; i++) {
      strcat(raw_query, argv[i]);
      if (i < argc - 1)
        strcat(raw_query, " ");
    }
    strcpy(query_norm, normalize(raw_query));
  }

  int search_count = 0;
  int line_count = 0;

  while (fgets(line, sizeof(line), fp)) {
    line_count++;
    // Strip newline
    line[strcspn(line, "\n")] = 0;
    if (strlen(line) == 0)
      continue;

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
      continue;
    }

    // Verse line? Starts with digit
    if (isdigit(line[0])) {
      char *text_start = strchr(line, ' ');
      if (!text_start)
        continue;
      *text_start = 0; // null terminate verse num
      int verse_num = atoi(line);
      char *text = text_start + 1;

      if (strcmp(command, "read") == 0) {
        if (argc < 4)
          continue;
        char *target_book = argv[2];
        int target_chapter = atoi(argv[3]);
        int target_verse = 0;
        if (argc >= 5)
          target_verse = atoi(argv[4]);

        if (strcasecmp(current_book, target_book) == 0 &&
            current_chapter == target_chapter) {
          if (target_verse == 0 || target_verse == verse_num) {
            if (current_title[0]) {
              printf("\n### %s ###\n", current_title);
            }
            printf("[%d:%d] ", current_chapter, verse_num);
            print_formatted(text);

            int c = fgetc(fp);
            if (c == 'R') {
              char ref_Line[MAX_LINE];
              fgets(ref_Line, sizeof(ref_Line), fp);
              ref_Line[strcspn(ref_Line, "\n")] = 0;
              char *refs = ref_Line + 1;
              printf(" (");
              while (*refs) {
                if (*refs == ';')
                  printf(", ");
                else
                  putchar(*refs);
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
        char *norm_text = normalize(text);
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
      current_title[0] = 0;
    }
  }

  pclose(fp);

  // Diagnosis if empty
  if (line_count == 0) {
    printf("\nError: No data read. This likely means 'tar' failed or the bzip2 "
           "archive is invalid.\n");
    printf("Troubleshooting:\n");
    printf("1. Ensure Windows 'tar' command works (try 'tar --version').\n");
    printf("2. Verify 'bible_data.tar.bz2' is not corrupted.\n");
  }

  return 0;
}
