program bible_reader
    use iso_c_binding
    implicit none

    ! LibC Interface
    interface
        function popen(command, mode) bind(C, name="popen")
            use iso_c_binding
            type(c_ptr) :: popen
            type(c_ptr), value :: command, mode ! Change to c_ptr
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

        function strlen(s) bind(C, name="strlen")
            use iso_c_binding
            type(c_ptr), value :: s
            integer(c_size_t) :: strlen
        end function strlen
        
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
        
        function printf(format) bind(C, name="printf")
            use iso_c_binding
            integer(c_int) :: printf
            character(kind=c_char), dimension(*), intent(in) :: format
            ! Varargs not supported directly in Fortran interface block usually
            ! We might need wrappers or just use Fortran write for standard output?
            ! Or simply defining specific interfaces if needed, but 'write' is fine for most.
            ! Use 'write' for standard output, simpler.
        end function printf
        
    end interface

    type(c_ptr) :: fp, ret_ptr
    character(kind=c_char, len=4096) :: line
    character(kind=c_char, len=100) :: book_buf
    character(kind=c_char, len=4096) :: title_buf
    character(kind=c_char, len=4096) :: refs_buf
    character(kind=c_char, len=100) :: cmd_buf
    character(kind=c_char, len=100) :: arg_book
    
    character(len=100) :: arg_val
    integer :: arg_len, status
    
    integer(c_int) :: target_chap, target_verse, current_chap, v_num
    integer :: i, j, k
    integer(c_int) :: c_val
    integer :: argc
    
    character(len=20) :: fmt_str
    
    character(kind=c_char, len=100), target :: cmd_buf_target
    character(kind=c_char, len=10), target :: mode_buf_target
    integer(c_int8_t), target :: cmd_bytes(100)
    integer(c_int8_t), target :: mode_bytes(3)
    character(len=100) :: temp_str
    
    ! Constants removed
    current_chap = 0
    target_chap = 0
    target_verse = 0
    title_buf(1:1) = C_NULL_CHAR
    
    argc = command_argument_count()
    if (argc < 1) then
        print *, "Usage: bible_reader_fortran read Book [Chap] [Verse]"
        stop
    end if
    
    call get_command_argument(1, arg_val, arg_len, status)
    cmd_buf = trim(arg_val) // C_NULL_CHAR
    
    if (argc >= 2) then
       call get_command_argument(2, arg_val, arg_len, status)
       arg_book = trim(arg_val) // C_NULL_CHAR
    end if
    
    if (argc >= 3) then
       call get_command_argument(3, arg_val, arg_len, status)
       read(arg_val, *) target_chap
    end if

    if (argc >= 4) then
       call get_command_argument(4, arg_val, arg_len, status)
       read(arg_val, *) target_verse
    end if

    ! Change fp, ret_ptr to type(c_ptr) - done
    temp_str = "xz -d -c ../bible_data.txt.xz" // C_NULL_CHAR
    do i = 1, 100
       cmd_bytes(i) = ichar(temp_str(i:i), c_int8_t)
    end do
    
    temp_str = "r" // C_NULL_CHAR
    do i = 1, 3
       mode_bytes(i) = ichar(temp_str(i:i), c_int8_t)
    end do
    
    fp = popen(c_loc(cmd_bytes), c_loc(mode_bytes))
    if (.not. c_associated(fp)) then
       print *, "popen failed."
       stop
    end if
    
    do
        ret_ptr = fgets(line, 4096, fp)
        if (.not. c_associated(ret_ptr)) exit
        
        ! Trim newline?
        ! C string null termination search
        i = 1
        do while(line(i:i) /= C_NULL_CHAR .and. i < 4096)
           if (line(i:i) == C_NEW_LINE) then 
              line(i:i) = C_NULL_CHAR
              exit
           end if
           i = i + 1
        end do
        
        if (line(1:1) == '#') then
            book_buf = line(3:) ! offset 2 in C is 3 in Fortran 1-based index?
            ! line(3) is 3rd character. line[2] in C.
            ! book_buf needs to be null terminated correctly.
            ! manual copy loop to be safe or slicing.
            ! line starts at 1. line(3) is 'G...'.
            ! Copy until null.
            current_chap = 0
            title_buf(1:1) = C_NULL_CHAR
            
        else if (line(1:1) == '=') then
             ! Parse current_chap
             ! line(3:) is number string.
             ! Use internal read
             ! Fortran string read stops at non-digit?
             ! Copy to temp string
             call parse_int(line(3:), current_chap)
             title_buf(1:1) = C_NULL_CHAR
             
        else if (line(1:1) == 'T') then
             title_buf = line(3:)
             
        else if (line(1:1) >= '0' .and. line(1:1) <= '9') then
             ! Verse
             call parse_int(line, v_num)
             
             ! Check match
             if (strcasecmp(arg_book, book_buf) == 0) then
                if (current_chap == target_chap .or. target_chap == 0) then
                   if (target_verse == 0 .or. target_verse == v_num) then
                       
                       ! Match Logic
                       
                       ! Check ref
                       c_val = fgetc(fp)
                       if (c_val == 82) then ! 'R'
                           ret_ptr = fgets(refs_buf, 4096, fp)
                           ! Trim newline
                           call trim_newline(refs_buf)
                       else
                           if (c_val /= -1) then
                               c_val = ungetc(c_val, fp)
                           end if
                           refs_buf(1:1) = C_NULL_CHAR
                       end if
                       
                       if (title_buf(1:1) /= C_NULL_CHAR) then
                           call print_c_str_nl("### ", title_buf, " ###")
                           title_buf(1:1) = C_NULL_CHAR
                       end if
                       
                       ! Print Verse [C:V]
                       write(*, '(A, I0, A, I0, A)', advance='no') "[", current_chap, ":", v_num, "] "
                       
                       ! Print Text (find space after digit)
                       ! 'line' has the text.
                       k = 1
                       do while(line(k:k) /= ' ')
                          k = k + 1
                       end do
                       ! line(k+1:) is text.
                       call print_formatted(line(k+1:))
                       
                       if (refs_buf(1:1) /= C_NULL_CHAR) then
                           call print_c_str_base(" (", refs_buf(2:), ")") ! skip ' ' at start of refs
                       end if
                       print * ! Newline
                       
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

    subroutine print_c_str(prefix, str, suffix)
        character(len=*), intent(in) :: prefix, suffix
        character(kind=c_char, len=*), intent(in) :: str
        integer :: i
        write(*, '(A)', advance='no') prefix
        i = 1
        do while(str(i:i) /= C_NULL_CHAR)
           write(*, '(A)', advance='no') str(i:i)
           i = i + 1
        end do
        write(*, '(A)', advance='yes') suffix
    end subroutine
    
    subroutine print_c_str_nl(prefix, str, suffix)
        character(len=*), intent(in) :: prefix, suffix
        character(kind=c_char, len=*), intent(in) :: str
        integer :: i
        write(*, '(A)', advance='no') prefix
        i = 1
        do while(str(i:i) /= C_NULL_CHAR)
           write(*, '(A)', advance='no') str(i:i)
           i = i + 1
        end do
        write(*, '(A)', advance='yes') suffix
    end subroutine

    subroutine print_c_str_base(prefix, str, suffix)
        character(len=*), intent(in) :: prefix, suffix
        character(kind=c_char, len=*), intent(in) :: str
        integer :: i
        write(*, '(A)', advance='no') prefix
        i = 1
        do while(str(i:i) /= C_NULL_CHAR)
           write(*, '(A)', advance='no') str(i:i)
           i = i + 1
        end do
        write(*, '(A)', advance='no') suffix
    end subroutine

    ! Print with Red Text parsing
    subroutine print_formatted(str)
        character(kind=c_char, len=*), intent(in) :: str
        integer :: i
        character(len=25) :: span_start
        character(len=25) :: span_start2
        character(len=10) :: span_end
        logical :: check_start, check_start2, check_end
        
        span_start = "<span class='Isus'>"
        span_start2 = '<span class="Isus">' ! Escaping issue in Fortran string literals?
        span_end = "</span>"
        
        i = 1
        do while(str(i:i) /= C_NULL_CHAR)
             ! Simple check lookahead
             if (str(i:i) == '<') then
                 ! Check start
                 if (str(i:i+18) == span_start(1:19)) then
                     write(*, '(A)', advance='no') achar(27) // "[31m"
                     i = i + 19
                     cycle
                 end if
                 ! Check start2? (escaped quote variant)
                 ! Just basic check
                 if (str(i:i+6) == "</span>") then
                     write(*, '(A)', advance='no') achar(27) // "[0m"
                     i = i + 7
                     cycle
                 end if
             end if
             
             write(*, '(A)', advance='no') str(i:i)
             i = i + 1
        end do
    end subroutine

end program bible_reader
