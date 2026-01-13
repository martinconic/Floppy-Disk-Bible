package main

/*
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void print_title(const char* title) { printf("\n### %s ###\n", title); }
void print_ref(const char* ref) { printf(" (%s)", ref); }
void print_verse_meta(int c, int v) { printf("[%d:%d] ", c, v); }
void print_newline() { printf("\n"); }
void print_usage() { printf("Usage: main read Book <Chap> <Verse>\n"); }
void print_error(const char* msg) { printf("%s\n", msg); }

// ANSI Colors
#define RED "\x1b[31m"
#define RESET "\x1b[0m"

void print_formatted(const char* s) {
    int i = 0;
    while (s[i] != 0) {
        if (s[i] == '<') {
            if (strncmp(&s[i], "<span class='Isus'>", 19) == 0) {
                printf(RED);
                i += 19;
                continue;
            }
             if (strncmp(&s[i], "<span class=\"Isus\">", 19) == 0) {
                printf(RED);
                i += 19; // assume same length
                continue;
            }
            if (strncmp(&s[i], "</span>", 7) == 0) {
                printf(RESET);
                i += 7;
                continue;
            }
        }
        putchar(s[i]);
        i++;
    }
}
*/
import "C"
import (
	"os"
	"unsafe"
)

const MAX_LINE = 4096

func main() {
	args := os.Args
	if len(args) < 3 {
		C.print_usage()
		return
	}

	argBook := args[2]
	targetChap := 0
	if len(args) > 3 {
		targetChap = atoi(args[3])
	}
	targetVerse := 0
	if len(args) > 4 {
		targetVerse = atoi(args[4])
	}

	modeR := C.CString("r")
	defer C.free(unsafe.Pointer(modeR))

	cmdXZ := C.CString("xz -d -c ../bible_data.txt.xz")
	defer C.free(unsafe.Pointer(cmdXZ))

	fp := C.popen(cmdXZ, modeR)
	if fp == nil {
		C.print_error(C.CString("popen failed"))
		return
	}
	defer C.pclose(fp)

	lineBuf := make([]byte, MAX_LINE)
	cLineBuf := (*C.char)(unsafe.Pointer(&lineBuf[0]))

	bookBuf := make([]byte, 100)
	titleBuf := make([]byte, MAX_LINE)
	refsBuf := make([]byte, MAX_LINE)

	var currentChap int
	hasTitle := false

	argBookCStr := C.CString(argBook)
	defer C.free(unsafe.Pointer(argBookCStr))

	for {
		ptr := C.fgets(cLineBuf, MAX_LINE, fp)
		if ptr == nil {
			break
		}

		ch := lineBuf[0]

		if ch == '#' {
			// Book
			C.strcpy((*C.char)(unsafe.Pointer(&bookBuf[0])), (*C.char)(unsafe.Pointer(&lineBuf[2])))
			trimNewline(bookBuf)

			currentChap = 0
			hasTitle = false
		} else if ch == '=' {
			// Chapter
			currentChap = int(C.atoi((*C.char)(unsafe.Pointer(&lineBuf[2]))))
			hasTitle = false
		} else if ch == 'T' {
			// Title
			C.strcpy((*C.char)(unsafe.Pointer(&titleBuf[0])), (*C.char)(unsafe.Pointer(&lineBuf[2])))
			trimNewline(titleBuf)
			hasTitle = true
		} else if ch >= '0' && ch <= '9' {
			// Verse
			vNum := int(C.atoi(cLineBuf))

			if C.strcasecmp(argBookCStr, (*C.char)(unsafe.Pointer(&bookBuf[0]))) == 0 {
				if currentChap == targetChap || targetChap == 0 {
					if targetVerse == 0 || targetVerse == vNum {

						rc := C.fgetc(fp)
						if rc == 'R' {
							C.fgets((*C.char)(unsafe.Pointer(&refsBuf[0])), MAX_LINE, fp)
							trimNewline(refsBuf)
						} else {
							if rc != -1 {
								C.ungetc(rc, fp)
							}
							refsBuf[0] = 0
						}

						if hasTitle {
							titleCStr := (*C.char)(unsafe.Pointer(&titleBuf[0]))
							C.print_title(titleCStr)
							hasTitle = false
						}

						C.print_verse_meta(C.int(currentChap), C.int(vNum))

						// Text
						textPtr := C.strchr(cLineBuf, ' ')
						if textPtr != nil {
							textStart := (*C.char)(unsafe.Pointer(uintptr(unsafe.Pointer(textPtr)) + 1))
							C.print_formatted(textStart)
						}

						if refsBuf[0] != 0 {
							C.print_ref((*C.char)(unsafe.Pointer(&refsBuf[1])))
						}
						C.print_newline()
					}
				}
			}
			hasTitle = false
		}
	}
}

func trimNewline(buf []byte) {
	for i := 0; i < len(buf); i++ {
		if buf[i] == 0 {
			break
		}
		if buf[i] == '\n' {
			buf[i] = 0
			return
		}
	}
}

func atoi(s string) int {
	n := 0
	for i := 0; i < len(s); i++ {
		if s[i] >= '0' && s[i] <= '9' {
			n = n*10 + int(s[i]-'0')
		}
	}
	return n
}
