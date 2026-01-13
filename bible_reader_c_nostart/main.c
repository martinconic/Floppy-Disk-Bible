#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifdef __APPLE__
#include <crt_externs.h>
#else
extern char **environ;
#endif

#define MAX_LINE 4096
#define RED "\x1b[31m"
#define RESET "\x1b[0m"

void print_formatted(const char *s) {
    const char *curr = s;
    while (*curr) {
        if (*curr == '<') {
             if (strncmp(curr, "<span class='Isus'>", 19) == 0) {
                 printf(RED);
                 curr += 19;
                 continue;
             }
             if (strncmp(curr, "<span class=\"Isus\">", 19) == 0) {
                 printf(RED);
                 curr += 19;
                 continue;
             }
             if (strncmp(curr, "</span>", 7) == 0) {
                 printf(RESET);
                 curr += 7;
                 continue;
             }
        }
        putchar(*curr);
        curr++;
    }
}

void trim_newline(char *s) {
    char *p = strchr(s, '\n');
    if (p) *p = 0;
}

void bible_logic(int argc, char **argv, char **envp) {
    // Manually set environ for libc so popen works
#ifdef __APPLE__
    *_NSGetEnviron() = envp;
#else
    environ = envp;
#endif

    if (argc < 3) {
        printf("Usage: bible_reader_c_nostart read Book <Chap> <Verse>\n");
        exit(0);
    }

    char *arg_book = argv[2];
    int target_chap = 0;
    if (argc > 3) target_chap = atoi(argv[3]);
    int target_verse = 0;
    if (argc > 4) target_verse = atoi(argv[4]);

    FILE *fp = popen("xz -d -c ../bible_data.txt.xz", "r");
    if (!fp) {
        printf("popen failed (check environment setup)\n");
        exit(1);
    }

    char line[MAX_LINE];
    char book_buf[100];
    char title_buf[MAX_LINE];
    char refs_buf[MAX_LINE];
    
    int current_chap = 0;
    int has_title = 0;
    
    while (fgets(line, sizeof(line), fp)) {
        if (line[0] == '#') {
            strcpy(book_buf, line + 2);
            trim_newline(book_buf);
            current_chap = 0;
            has_title = 0;
        } else if (line[0] == '=') {
            current_chap = atoi(line + 2);
            has_title = 0;
        } else if (line[0] == 'T') {
            strcpy(title_buf, line + 2);
            trim_newline(title_buf);
            has_title = 1;
        } else if (line[0] >= '0' && line[0] <= '9') {
            int v_num = atoi(line);
            
            if (strcasecmp(arg_book, book_buf) == 0) {
                if (current_chap == target_chap || target_chap == 0) {
                    if (target_verse == 0 || target_verse == v_num) {
                        
                        int c = fgetc(fp);
                        if (c == 'R') {
                            fgets(refs_buf, sizeof(refs_buf), fp);
                            trim_newline(refs_buf);
                        } else {
                            if (c != EOF) ungetc(c, fp);
                            refs_buf[0] = 0;
                        }
                        
                        if (has_title) {
                            printf("\n### %s ###\n", title_buf);
                            has_title = 0;
                        }
                        
                        printf("[%d:%d] ", current_chap, v_num);
                        
                        char *text_start = strchr(line, ' ');
                        if (text_start) {
                            print_formatted(text_start + 1);
                        }
                        
                        if (refs_buf[0]) {
                            printf(" (%s)", refs_buf + 1);
                        }
                        printf("\n");
                    }
                }
            }
            has_title = 0;
        }
    }
    pclose(fp);
    exit(0);
}

void start() __attribute__((naked));
void start() {
    __asm__ volatile (
        "popq %rdi\n\t"        // argc -> rdi
        "movq %rsp, %rsi\n\t"  // argv -> rsi
        
        // Calculate envp -> rdx
        // envp = argv + (argc + 1) * 8
        // rsi is argv
        // rdi is argc
        "movq %rdi, %rax\n\t"
        "incq %rax\n\t"
        "shlq $3, %rax\n\t"    // * 8
        "addq %rsi, %rax\n\t"
        "movq %rax, %rdx\n\t"  // envp in rdx
        
        "andq $-16, %rsp\n\t"  // Align stack
        "call _bible_logic\n\t"
        "movq $0, %rdi\n\t"
        "call _exit\n\t"
    );
}
