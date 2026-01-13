\ Bible Reader in Gforth

c-library libc
\c #include <stdio.h>
\c #include <stdlib.h>
\c #include <string.h>

c-function popen popen a a -- a
c-function pclose pclose a -- n
c-function fgets fgets a n a -- a
c-function fgetc fgetc a -- n
c-function ungetc ungetc n a -- n
c-function strcmp strcmp a a -- n
c-function strcasecmp strcasecmp a a -- n
c-function atoi atoi a -- n
c-function strchr strchr a n -- a
c-function strlen strlen a -- n
c-function strncmp strncmp a a n -- n

end-c-library

4096 constant MAX_LINE

create line_buf MAX_LINE allot
create book_buf 100 allot
create title_buf MAX_LINE allot
create refs_buf MAX_LINE allot
create cmd_buf 100 allot

\ ANSI Colors
s\" \e[31m" 2constant S_COLOR_RED
s\" \e[0m" 2constant S_COLOR_RESET

: c-type ( addr -- ) 
   dup strlen type ;

: print-formatted ( addr -- )
    begin
        dup c@ 0<>
    while
        2dup s" <span class=\'Isus\'>" drop 19 strncmp 0= if
            S_COLOR_RED type
            19 +
        else
            2dup s" <span class=\'Isus\'>" drop 21 strncmp 0= if 
               S_COLOR_RED type
               21 + 
            else
               2dup s" </span>" drop 7 strncmp 0= if
                   S_COLOR_RESET type
                   7 +
               else
                   dup c@ emit
                   1+
               then
            then
        then
    repeat
    drop
;

0 value fp
0 value current-chapter
0 value target-chapter
0 value target-verse
0 value v-num

: main
    argc @ 3 < if
        s" Usage: gforth main.fs <read> <Book> [Chap] [Verse]" type cr bye
    then

    \ Indices: 0=gforth 1=cmd 2=book 3=chap 4=verse
    
    \ Cmd (1 arg)
    1 arg drop cmd_buf 100 move
    1 arg nip cmd_buf + 0 swap c! 
    
    s\" xz -d -c ../bible_data.txt.xz\0" drop s\" r\0" drop popen to fp
    
    fp 0= if s" popen failed" type cr bye then
    
    argc @ 4 >= if 3 arg drop atoi to target-chapter else 0 to target-chapter then
    argc @ 5 >= if 4 arg drop atoi to target-verse else 0 to target-verse then
    
    begin
        line_buf MAX_LINE fp fgets line_buf = 
    while
        line_buf strlen line_buf + 1- dup c@ 10 = if 0 swap c! else drop then
        
        line_buf c@ 35 = if \ '#'
            line_buf 2 + book_buf 100 move 
            line_buf 2 + book_buf 100 0 fill 
            line_buf 2 + book_buf 100 move 
            0 to current-chapter
            title_buf 0 swap c! 
        else
            line_buf c@ 61 = if \ '='
                line_buf 2 + atoi to current-chapter
                title_buf 0 swap c!
            else
                line_buf c@ 84 = if \ 'T'
                     line_buf 2 + title_buf MAX_LINE move
                else
                    line_buf c@ 48 >= line_buf c@ 57 <= and if \ Digit
                        line_buf atoi to v-num
                        line_buf 32 strchr 1+ 
                        
                        \ Book match (2 arg)
                        2 arg drop book_buf strcasecmp 0= 
                        current-chapter target-chapter = and
                        target-verse 0= target-verse v-num = or and
                        if 
                            fp fgetc dup 82 = if \ 'R'
                                drop
                                refs_buf MAX_LINE fp fgets drop
                                refs_buf strlen refs_buf + 1- dup c@ 10 = if 0 swap c! else drop then
                            else
                                -1 <> if fp ungetc drop then
                                refs_buf 0 swap c!
                            then
                            
                            title_buf c@ 0<> if
                                s" \n### " type title_buf c-type s"  ###\n" type 
                                title_buf 0 swap c!
                            then
                            
                            s" [" type current-chapter 1 .r s" :" type v-num 1 .r s" ] " type 
                            dup c-type
                            
                            refs_buf c@ 0<> if
                                s"  (" type 
                                refs_buf 1+ c-type 
                                s" )" type
                            then
                            cr
                            
                        else
                            drop 
                            title_buf 0 swap c! 
                        then
                    then
                then
            then
        then
    repeat
    
    fp pclose drop
    bye
;
