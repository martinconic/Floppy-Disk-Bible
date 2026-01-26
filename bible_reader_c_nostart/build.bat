@echo off
setlocal EnableDelayedExpansion
echo Building Optimized Windows Reader...

:: Ensure Data
if not exist "..\bible_data.tar.bz2" (
    echo [INFO] Generating bible_data.tar.bz2...
    cd ..
    tar -cjf bible_data.tar.bz2 bible_data.txt
    cd bible_reader_c_nostart
)

:: Build with GCC
where gcc >nul 2>nul
if !errorlevel! equ 0 (
    echo Found GCC. Compiling nostart...
    
    :: Compile
    gcc -Os -s -nostartfiles -o main_win.exe main_win.c -lmsvcrt -lkernel32 -Wl,-e,start
    
    if !errorlevel! equ 0 (
        echo [SUCCESS] Built main_win.exe.
        for %%F in (main_win.exe) do echo Size: %%~zF bytes
        goto :eof
    ) else (
        echo [FAIL] GCC build failed.
    )
) else (
    echo Error: GCC not found.
)
