program bible_reader
    use iso_c_binding
    implicit none

    ! LibC Interface
    interface
        function popen(command, mode) bind(C, name="popen")
            use iso_c_binding
            type(c_ptr) :: popen
            type(c_ptr), value :: command, mode
        end function popen

        function pclose(stream) bind(C, name="pclose")
            use iso_c_binding
            integer(c_int) :: pclose
            type(c_ptr), value :: stream
        end function pclose

        function fgets(s, size, stream) bind(C, name="fgets")
            use iso_c_binding
            type(c_ptr) :: fgets
            character(kind=c_char), dimension(*), intent(out) :: s
            integer(c_int), value :: size
            type(c_ptr), value :: stream
        end function fgets
        
        function fgetc(stream) bind(C, name="fgetc")
            use iso_c_binding
            integer(c_int) :: fgetc
            type(c_ptr), value :: stream
        end function fgetc
        
        function ungetc(c, stream) bind(C, name="ungetc")
            use iso_c_binding
            integer(c_int) :: ungetc
            integer(c_int), value :: c
            type(c_ptr), value :: stream
        end function ungetc

        function strcasecmp(s1, s2) bind(C, name="strcasecmp")
           use iso_c_binding
           integer(c_int) :: strcasecmp
           character(kind=c_char), dimension(*), intent(in) :: s1, s2
        end function strcasecmp
        
        function atoi(s) bind(C, name="atoi")
           use iso_c_binding
           integer(c_int) :: atoi
           character(kind=c_char), dimension(*), intent(in) :: s
        end function atoi
        
        ! Specific printf wrappers
        function printf_str(format, s) bind(C, name="printf")
            use iso_c_binding
            integer(c_int) :: printf_str
            character(kind=c_char), dimension(*), intent(in) :: format
            character(kind=c_char), dimension(*), intent(in) :: s
        end function printf_str

        function printf_title(format, s) bind(C, name="printf")
            use iso_c_binding
            integer(c_int) :: printf_title
            character(kind=c_char), dimension(*), intent(in) :: format
            character(kind=c_char), dimension(*), intent(in) :: s
        end function printf_title
        
        function printf_meta(format, c, v) bind(C, name="printf")
            use iso_c_binding
            integer(c_int) :: printf_meta
            character(kind=c_char), dimension(*), intent(in) :: format
            integer(c_int), value :: c, v
        end function printf_meta

        function printf_simple(format) bind(C, name="printf")
            use iso_c_binding
            integer(c_int) :: printf_simple
            character(kind=c_char), dimension(*), intent(in) :: format
        end function printf_simple
        
        function putchar(c) bind(C, name="putchar")
            use iso_c_binding
            integer(c_int) :: putchar
            integer(c_int), value :: c
        end function putchar
        
    end interface

    type(c_ptr) :: fp, ret_ptr
    character(kind=c_char, len=4096) :: line
    character(kind=c_char, len=100) :: book_buf
    character(kind=c_char, len=4096) :: title_buf
    character(kind=c_char, len=4096) :: refs_buf
    character(kind=c_char, len=100) :: arg_book
    
    character(len=100) :: arg_val
    integer :: arg_len, status
    
    integer(c_int) :: target_chap, target_verse, current_chap, v_num
    integer :: i, k
    integer(c_int) :: c_val, p_ret
    integer :: argc
    
    character(kind=c_char, len=100), target :: cmd_bytes
    character(kind=c_char, len=4), target :: mode_bytes
    character(kind=c_char, len=30) :: fmt_title, fmt_meta, fmt_ref, fmt_nl, fmt_red, fmt_reset
    
    current_chap = 0
    target_chap = 0
    target_verse = 0
    title_buf(1:1) = C_NULL_CHAR
    
    fmt_title = C_NEW_LINE // "### %s ###" // C_NEW_LINE // C_NULL_CHAR
    fmt_title(1:1) = C_NEW_LINE
    fmt_title(2:9) = "### %s ###"
    fmt_title(10:10) = C_NEW_LINE
    fmt_title(11:11) = C_NULL_CHAR

    fmt_meta = "[%d:%d] " // C_NULL_CHAR
    fmt_meta(9:9) = C_NULL_CHAR
    
    fmt_ref = " (%s)" // C_NULL_CHAR
    fmt_ref(6:6) = C_NULL_CHAR
    
    fmt_nl = C_NEW_LINE // C_NULL_CHAR
    fmt_nl(2:2) = C_NULL_CHAR
    
    fmt_red = achar(27) // "[31m" // C_NULL_CHAR
    fmt_red(2:5) = "[31m"
    fmt_red(6:6) = C_NULL_CHAR
    
    fmt_reset = achar(27) // "[0m" // C_NULL_CHAR
    fmt_reset(2:4) = "[0m"
    fmt_reset(5:5) = C_NULL_CHAR
    
    argc = command_argument_count()
    if (argc < 1) then
        p_ret = printf_simple("Usage: bible_reader_fortran read Book [Chap] [Verse]" // C_NEW_LINE // C_NULL_CHAR)
        stop
    end if
    
    call get_command_argument(1, arg_val, arg_len, status)
    ! No easy way to direct string copy from Fortran string to C char array without explicit loop or correct assignment?
    ! Fortran assignment pads.
    ! We need null termination.
    arg_book = C_NULL_CHAR
    do i = 1, min(len(trim(arg_val)), 99)
       arg_book(i:i) = arg_val(i:i)
    end do
    arg_book(i:i) = C_NULL_CHAR
    
    if (argc >= 2) then
       call get_command_argument(2, arg_val, arg_len, status)
       ! arg_book logic reused? Wait, 1 is 'read'. 2 is 'Book'.
       ! Correct arg parsing: 1=action(read), 2=Book, 3=Chap, 4=Verse
    end if
    ! Actually standard args: 0=prog, 1=read, 2=Book
    ! My code above captured 1 into arg_book. That's wrong if 1 is 'read'.
    ! Let's fix.
    
    ! Arg 2 is Book
    if (argc >= 2) then
        call get_command_argument(2, arg_val, arg_len, status)
        do i = 1, min(len(trim(arg_val)), 99)
           arg_book(i:i) = arg_val(i:i)
        end do
        arg_book(i:i) = C_NULL_CHAR
    end if
    
    if (argc >= 3) then
       call get_command_argument(3, arg_val, arg_len, status)
       read(arg_val, *) target_chap
    end if

    if (argc >= 4) then
       call get_command_argument(4, arg_val, arg_len, status)
       read(arg_val, *) target_verse
    end if

    cmd_bytes = "xz -d -c ../bible_data.txt.xz" // C_NULL_CHAR
    mode_bytes = "r" // C_NULL_CHAR
    
    fp = popen(c_loc(cmd_bytes), c_loc(mode_bytes))
    if (.not. c_associated(fp)) then
       p_ret = printf_simple("popen failed." // C_NEW_LINE // C_NULL_CHAR)
       stop
    end if
    
    do
        ret_ptr = fgets(line, 4096, fp)
        if (.not. c_associated(ret_ptr)) exit
        
        i = 1
        do while(line(i:i) /= C_NULL_CHAR .and. i < 4096)
           if (line(i:i) == C_NEW_LINE) then 
              line(i:i) = C_NULL_CHAR
              exit
           end if
           i = i + 1
        end do
        
        if (line(1:1) == '#') then
            book_buf = line(3:)
            current_chap = 0
            title_buf(1:1) = C_NULL_CHAR
        else if (line(1:1) == '=') then
             call parse_int(line(3:), current_chap)
             title_buf(1:1) = C_NULL_CHAR
        else if (line(1:1) == 'T') then
             title_buf = line(3:)
        else if (line(1:1) >= '0' .and. line(1:1) <= '9') then
             call parse_int(line, v_num)
             
             if (strcasecmp(arg_book, book_buf) == 0) then
                if (current_chap == target_chap .or. target_chap == 0) then
                   if (target_verse == 0 .or. target_verse == v_num) then
                       
                       c_val = fgetc(fp)
                       if (c_val == 82) then ! 'R'
                           ret_ptr = fgets(refs_buf, 4096, fp)
                           call trim_newline(refs_buf)
                       else
                           if (c_val /= -1) then
                               c_val = ungetc(c_val, fp)
                           end if
                           refs_buf(1:1) = C_NULL_CHAR
                       end if
                       
                       if (title_buf(1:1) /= C_NULL_CHAR) then
                           p_ret = printf_title(fmt_title, title_buf)
                           title_buf(1:1) = C_NULL_CHAR
                       end if
                       
                       p_ret = printf_meta(fmt_meta, current_chap, v_num)
                       
                       k = 1
                       do while(line(k:k) /= ' ')
                          k = k + 1
                       end do
                       call print_formatted(line(k+1:))
                       
                       if (refs_buf(1:1) /= C_NULL_CHAR) then
                           p_ret = printf_str(fmt_ref, refs_buf(2:)) ! Skip space
                       end if
                       p_ret = printf_simple(fmt_nl)
                   end if
                end if
             end if
             title_buf(1:1) = C_NULL_CHAR
        end if 
    end do
    
    i = pclose(fp)
    
contains

    subroutine parse_int(str, val)
       character(kind=c_char, len=*), intent(in) :: str
       integer(c_int), intent(out) :: val
       val = atoi(str)
    end subroutine

    subroutine trim_newline(str)
       character(kind=c_char, len=*), intent(inout) :: str
       integer :: i
       i = 1
       do while(str(i:i) /= C_NULL_CHAR)
          if (str(i:i) == C_NEW_LINE) then
             str(i:i) = C_NULL_CHAR
             return
          end if
          i = i + 1
       end do
    end subroutine

    subroutine print_formatted(str)
        character(kind=c_char, len=*), intent(in) :: str
        integer :: i
        character(len=19) :: span_chk
        character(len=7) :: span_end
        
        span_chk = "<span class='Isus'>"
        span_end = "</span>"
        
        i = 1
        do while(str(i:i) /= C_NULL_CHAR)
             if (str(i:i) == '<') then
                 if (str(i:i+18) == span_chk) then
                     p_ret = printf_simple(fmt_red)
                     i = i + 19
                     cycle
                 end if
                 if (str(i:i+6) == span_end) then
                     p_ret = printf_simple(fmt_reset)
                     i = i + 7
                     cycle
                 end if
             end if
             
             p_ret = putchar(ichar(str(i:i), c_int))
             i = i + 1
        end do
    end subroutine

end program bible_reader
