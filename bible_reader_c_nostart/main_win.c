#include <ctype.h>
#include <fcntl.h>
#include <io.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>


// Link against msvcrt directly to use printf/popen without full CRT startup
// GCC (MinGW) usually links correctly with -nostartfiles if we use msvcrt
// functions. We define our own entry point.

#define MAX_LINE 4096
#define COLOR_RED "\x1b[31m"
#define COLOR_RESET "\x1b[0m"

// Imports from msvcrt if not strictly linked by compiler automatically
// In MinGW, headers usually suffice.

// Helper to normalized string
char *normalize(const char *str) {
  static char buf[MAX_LINE * 2];
  char *out = buf;
  while (*str) {
    if ((*str >= 'A' && *str <= 'Z')) {
      *out++ = *str + 32;
      str++;
      continue;
    }
    // Romanian diacritics
    unsigned char c1 = (unsigned char)str[0];
    unsigned char c2 = (unsigned char)str[1];
    if (c1 == 0xC4 && c2 == 0x83) {
      *out++ = 'a';
      str += 2;
      continue;
    }
    if (c1 == 0xC3 && c2 == 0xA2) {
      *out++ = 'a';
      str += 2;
      continue;
    }
    if (c1 == 0xC3 && c2 == 0xAE) {
      *out++ = 'i';
      str += 2;
      continue;
    }
    if (c1 == 0xC8 && c2 == 0x99) {
      *out++ = 's';
      str += 2;
      continue;
    }
    if (c1 == 0xC5 && c2 == 0x9F) {
      *out++ = 's';
      str += 2;
      continue;
    }
    if (c1 == 0xC8 && c2 == 0x9B) {
      *out++ = 't';
      str += 2;
      continue;
    }
    if (c1 == 0xC5 && c2 == 0xA3) {
      *out++ = 't';
      str += 2;
      continue;
    }
    if (c1 == 0xC4 && c2 == 0x82) {
      *out++ = 'a';
      str += 2;
      continue;
    }
    if (c1 == 0xC3 && c2 == 0x82) {
      *out++ = 'a';
      str += 2;
      continue;
    }
    if (c1 == 0xC3 && c2 == 0x8E) {
      *out++ = 'i';
      str += 2;
      continue;
    }
    if (c1 == 0xC8 && c2 == 0x98) {
      *out++ = 's';
      str += 2;
      continue;
    }
    if (c1 == 0xC5 && c2 == 0x9E) {
      *out++ = 's';
      str += 2;
      continue;
    }
    if (c1 == 0xC8 && c2 == 0x9A) {
      *out++ = 't';
      str += 2;
      continue;
    }
    if (c1 == 0xC5 && c2 == 0xA2) {
      *out++ = 't';
      str += 2;
      continue;
    }
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
      printf(COLOR_RED);
      p += 21;
    } else if (strncmp(p, "<span class='Isus'>", 19) == 0) {
      printf(COLOR_RED);
      p += 19;
    } else if (strncmp(p, "</span>", 7) == 0) {
      printf(COLOR_RESET);
      p += 7;
    } else {
      putchar(*p);
      p++;
    }
  }
}

// Simple manual argv parser
// Does not handle quotes inside quotes perfectly, but sufficient for our simple
// args
int parse_args(char *cmd_line, char **argv, int max_args) {
  int argc = 0;
  while (*cmd_line && argc < max_args) {
    while (*cmd_line && isspace((unsigned char)*cmd_line))
      cmd_line++; // skip space
    if (*cmd_line == 0)
      break;

    argv[argc++] = cmd_line;
    if (*cmd_line == '"') {
      argv[argc - 1]++; // skip quote
      cmd_line++;
      while (*cmd_line && *cmd_line != '"')
        cmd_line++;
    } else {
      while (*cmd_line && !isspace((unsigned char)*cmd_line))
        cmd_line++;
    }

    if (*cmd_line) {
      *cmd_line++ = 0; // null terminate
    }
  }
  return argc;
}

// Entry point
void start() {
  // Basic setup
  // Linker: -lmsvcrt -lkernel32

  // Parse args
  char *cmd_line = GetCommandLineA();
  char *argv[20]; // max 20 args
  int argc = parse_args(cmd_line, argv, 20);

  // FIX: Set console code page to UTF-8 to support Romanian
  SetConsoleOutputCP(65001);

  if (argc < 2) {
    printf("Usage: program <list|read|search> ...\n");
    ExitProcess(0);
  }

  char *command = argv[1];

  // Logic similar to main loop, assuming bible_data.tar.bz2
  const char *data_file = "bible_data.tar.bz2";
  if (_access(data_file, 0) == -1) {
    data_file = "..\\bible_data.tar.bz2";
    if (_access(data_file, 0) == -1) {
      printf("Error: bible_data.tar.bz2 not found.\n");
      ExitProcess(1);
    }
  }

  char cmd[1024];
  _snprintf(cmd, sizeof(cmd), "tar -xjOf \"%s\"", data_file);
  FILE *fp = _popen(cmd, "r");
  if (!fp) {
    ExitProcess(1);
  }

  char line[MAX_LINE];
  char current_book[100];
  int current_chapter = 0;
  char current_title[MAX_LINE] = "";

  // SEARCH Setup
  char query_norm[MAX_LINE] = "";
  if (stricmp(command, "search") == 0 && argc >= 3) {
    char raw_query[MAX_LINE] = "";
    for (int i = 2; i < argc; i++) {
      strcat(raw_query, argv[i]);
      if (i < argc - 1)
        strcat(raw_query, " ");
    }
    strcpy(query_norm, normalize(raw_query));
  }

  int search_count = 0;

  while (fgets(line, sizeof(line), fp)) {
    line[strcspn(line, "\n")] = 0;
    if (strlen(line) == 0)
      continue;

    if (line[0] == '#') {
      strcpy(current_book, line + 2);
      current_chapter = 0;
      current_title[0] = 0;
      if (stricmp(command, "list") == 0)
        printf("- %s\n", current_book);
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
    if (line[0] == 'R')
      continue;

    if (line[0] >= '0' && line[0] <= '9') {
      char *text_start = strchr(line, ' ');
      if (!text_start)
        continue;
      *text_start = 0;
      int verse_num = atoi(line);
      char *text = text_start + 1;

      if (stricmp(command, "read") == 0) {
        if (argc < 4)
          continue;
        char *target_book = argv[2];
        int target_chapter = atoi(argv[3]);
        int target_verse = (argc >= 5) ? atoi(argv[4]) : 0;

        if (stricmp(current_book, target_book) == 0 &&
            current_chapter == target_chapter) {
          if (target_verse == 0 || target_verse == verse_num) {
            if (current_title[0])
              printf("\n### %s ###\n", current_title);
            printf("[%d:%d] ", current_chapter, verse_num);
            print_formatted(text);

            int c = fgetc(fp);
            if (c == 'R') {
              char ref_l[MAX_LINE];
              fgets(ref_l, sizeof(ref_l), fp);
              // Wait, logic above was simpl, let's just print
              // removing newline
              ref_l[strcspn(ref_l, "\n")] = 0;
              printf(" (%s)", ref_l + 1);
            } else if (c != EOF)
              ungetc(c, fp);
            printf("\n");
          }
        }
      } else if (stricmp(command, "search") == 0) {
        if (strstr(normalize(text), query_norm)) {
          printf("%s %d:%d - ", current_book, current_chapter, verse_num);
          print_formatted(text);
          printf("\n");
          search_count++;
          if (search_count > 50) {
            printf("...\n");
            break;
          }
        }
      }
      current_title[0] = 0;
    }
  }
  _pclose(fp);
  ExitProcess(0);
}
