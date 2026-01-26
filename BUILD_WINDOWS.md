# Build on Windows

## Prerequisites

1.  **C Compiler**: You need either:
    *   **MinGW (GCC)**: `winget install MinGW`
    *   **Visual Studio (MSVC)**: "Desktop development with C++" workload.

2.  **No Extra Tools**: We use the built-in Windows `tar` command for compression.

## Build

1.  Open Command Prompt or PowerShell in `bible_reader_c`.
2.  Run the build script:
    ```cmd
    build.bat
    ```
    *   This will automatically:
        *   Compress `bible_data.txt` to `bible_data.tar.bz2` (fits on floppy!).
        *   Compile the reader.

## Run

```cmd
.\main_win.exe read Ioan 3 16
.\main_win.exe search miazazi
```

## Notes

*   **Floppy Fit**: The final `.tar.bz2` file is ~1.1 MB. The exe is ~15-20 KB. This fits on a standard 1.44 MB floppy disk.
*   **Performance**: Reading from bzip2 is fast enough for the CLI.
