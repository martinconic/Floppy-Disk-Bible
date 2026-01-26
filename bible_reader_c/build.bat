@echo off
setlocal EnableDelayedExpansion
echo Building Bible Reader for Windows...

:: Check/Create Data File
if not exist "..\bible_data.tar.bz2" (
    echo [INFO] Generating bible_data.tar.bz2 from bible_data.txt...
    if exist "..\bible_data.txt" (
        pushd ..
        :: bzip2 compression using tar
        tar -cjf bible_data.tar.bz2 bible_data.txt
        if !errorlevel! neq 0 (
             echo [ERROR] Failed to compress data. Ensure you have 'tar' working.
             popd
             goto :fail
        )
        popd
        echo [OK] Created bible_data.tar.bz2
    ) else (
        echo [ERROR] bible_data.txt not found in parent directory. Cannot generate data file.
        goto :fail
    )
)

:: 1. Try MinGW (gcc)
echo Checking for GCC...
where gcc >nul 2>nul
if !errorlevel! equ 0 (
    echo Found GCC. Compiling...
    gcc -O3 -s -o main_win.exe main_win.c
    if !errorlevel! equ 0 (
        echo Build successful with GCC: main_win.exe
        goto :success
    ) else (
        echo GCC build failed. Trying MSVC...
    )
) else (
    echo GCC not found.
)

:: 2. Try MSVC (cl)
echo Checking for MSVC...
where cl >nul 2>nul
if !errorlevel! equ 0 (
    echo Found MSVC. Compiling...
    cl /O2 /Fe:main_win.exe main_win.c
    if !errorlevel! equ 0 (
        echo Build successful with MSVC: main_win.exe
        del *.obj 2>nul
        goto :success
    ) else (
        echo MSVC build failed.
    )
) else (
    echo MSVC not found.
)

echo.
echo Error: Could not build with either GCC or MSVC.
echo Please ensure you have a C compiler installed and in your PATH.
goto :fail

:success
echo.
echo To run:
echo   .\main_win.exe read Ioan 3 16
goto :eof

:fail
exit /b 1
