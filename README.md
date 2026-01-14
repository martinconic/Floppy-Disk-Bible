# The Smallest Bible Reader Challenge

**Goal**: Fit the entire Romanian Bible (Cornilescu translation) + a searchable, functional CLI reader onto a standard **1.44 MB Floppy Disk**.

The Bible text data, compressed with `xz`, occupies **~1.16 MB**. This leaves approximately **280 KB** for the executable logic. This project explores implementing the same logic in various programming languages to compare binary sizes and efficiency.

## Binary Size Comparison (Final Results)

All binaries are verified to parse the data, handle formatting (e.g., Red Text for Jesus' words), and provide search functionality.

| Language | Size (macOS) | Size (Linux) | Floppy Fit | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Forth** | `~4.5 KB`* | `~4.5 KB`* | ✅ Yes | *Script/Image size. Requires `gforth` VM (or bundled). |
| **C (Nostart)** | `~9.0 KB` | `~13.5 KB` | ✅ Yes | `-nostartfiles`. Linux uses `start` symbol. |
| **C (Standard)** | `~9.4 KB` | `~14.5 KB` | ✅ Yes | Standard GCC build. |
| **C++** | `~9.5 KB` | `~14.5 KB` | ✅ Yes | Optimized with `-fno-rtti -fno-exceptions`. |
| **Fortran (Optimized)** | `~13 KB` | `~14.4 KB` | ✅ Yes | `gfortran -Os -s` + C bindings. |
| **Fortran (Standard)** | `~14 KB` | `~18.5 KB` | ✅ Yes | `gfortran -O3 -s`. |
| **Rust (Optimized)** | `~9 KB` | `~6.7 KB` | ✅ Yes | `no_std`, `libc`, manually stripped. |
| **Zig (Optimized)** | `~17 KB` | TBD | ✅ Yes | Manual `libc` bindings, stripped. |
| **Zig (Standard)** | `~51 KB` | TBD | ✅ Yes | `ReleaseSmall`, stripped. |
| **Odin** | `~23 KB` | `~27.0 KB` | ✅ Yes | Uses `core:c` bindings, minimal runtime. |
| **Go (Optimized)** | `~90 KB` | TBD | ✅ Yes | TinyGo + LibC bindings (No FMT). |
| **Pascal (Optimized)** | `~107 KB` | TBD | ✅ Yes | Free Pascal (`-XX -Xs`), No SysUtils, Stripped. |
| **Pascal (Standard)** | `~130 KB` | TBD | ✅ Yes | Standard Free Pascal build. |
| **Rust (Standard)** | `~371 KB` | `~375 KB` | ❌ No | Standard build stripped. |
| **Go (Standard)** | `~1,700 KB` | `~1,860 KB` | ❌ No | Standard build. Garbage collector/runtime overhead. |

---

## Build Instructions

### Prerequisites

| Tool | macOS | Linux (Debian/Ubuntu) | Windows (PowerShell) |
| :--- | :--- | :--- | :--- |
| **GCC Suite** | `xcode-select --install` | `sudo apt install build-essential gfortran` | Install [MinGW-w64](https://www.mingw-w64.org/) |
| **Free Pascal** | [Installer](https://www.freepascal.org/download.var) | `sudo apt install fpc` | [Download](https://www.freepascal.org/download.var) |
| **Zig** | `brew install zig` | [Download](https://ziglang.org/download/) | `winget install zig.zig` |
| **Rust** | `brew install rust` | `curl ... \| sh` | [Rustup.rs](https://rustup.rs/) |
| **Go** | `brew install go` | `sudo apt install golang` | [Go Installer](https://go.dev/dl/) |
| **XZ Utils** | `brew install xz` | `sudo apt install xz-utils` | [XZ for Windows](https://tukaani.org/xz/) (Add to PATH) |

### Setup (All Platforms)
Ensure `xz` (or `xz.exe`) is in your system PATH. The readers rely on `popen("xz -d ...")` to read the compressed data.

### Instructions

1.  **C Implementation (Recommended)**
    *Platform: All*
    ```bash
    cd bible_reader_c
    # macOS:
    gcc -O3 -s -o main main.c
    
    # Linux:
    gcc -O3 -s -o main_linux main.c
    
    ./main_linux read Ioan 3 16 (or ./main on macOS)
    ```

2.  **C Nostartfiles (Experimental)**
    *Platform: macOS / Linux (x86_64)*
    ```bash
    cd bible_reader_c_nostart
    # macOS:
    gcc -Os -s -nostartfiles -Wl,-e,_start -o main main.c
    
    # Linux:
    gcc -Os -s -nostartfiles -Wl,-e,start -flto -fno-asynchronous-unwind-tables -fno-stack-protector -ffunction-sections -fdata-sections -Wl,--gc-sections -o main_linux main.c
    
    ./main_linux read Ioan 3 16 (or ./main on macOS)
    ```

3.  **C++ Implementation**
    *Platform: All*
    ```bash
    cd bible_reader_cpp
    # macOS:
    g++ -O3 -s -fno-rtti -fno-exceptions -o main main.cpp
    
    # Linux:
    g++ -O3 -s -fno-rtti -fno-exceptions -o main_linux main.cpp
    
    ./main_linux read Ioan 3 16
    ```

4.  **Fortran Implementation (Optimized)**
    *Platform: All*
    ```bash
    cd bible_reader_fortran_opt
    # macOS:
    gfortran -Os -s -Wl,-dead_strip -o main main.f90
    
    # Linux:
    gfortran -Os -s -o main_linux main.f90

    ./main_linux read Ioan 3 16
    ```

5.  **Zig Implementation (Optimized)**
    *Platform: All*
    ```bash
    cd bible_reader_zig_opt
    # macOS:
    zig build-exe main.zig -O ReleaseSmall -fstrip -lc
    
    # Linux:
    zig build-exe main.zig --name main_linux -O ReleaseSmall -fstrip -lc
    
    ./main_linux read Ioan 3 16
    ```

6.  **Pascal Implementation (Optimized)**
    *Platform: All (Windows uses `main.exe`)*
    ```bash
    cd bible_reader_pascal_opt
    # macOS:
    fpc -O3 -XX -Xs -omain main.pas
    
    # Linux:
    fpc -O3 -XX -Xs -omain_linux main.pas
    
    # Optional: strip main_linux
    ./main_linux read Ioan 3 16
    ```

7.  **Rust Implementation (Optimized)**
    *Platform: All*
    ```bash
    cd bible_reader_rust_opt
    # macOS:
    RUSTFLAGS="-C link-arg=-lSystem" cargo build --release
    mv target/release/bible_reader_rust_opt main
    
    # Linux:
    cargo build --release
    mv target/release/bible_reader_rust_opt main_linux
    strip main_linux

    ./main_linux read Ioan 3 16
    ```
    
8.  **Rust Implementation (Standard)**
    *Platform: All*
    ```bash
    cd bible_reader_rust
    # macOS:
    rustc -C opt-level=z -C lto -C panic=abort -C strip=symbols main.rs -o main
    
    # Linux:
    rustc -C opt-level=z -C lto -C panic=abort -C strip=symbols main.rs -o main_linux
    
    ./main_linux read Ioan 3 16
    ```

9.  **Go Implementation (Optimized)**
    *Platform: All*
    ```bash
    cd bible_reader_go_opt
    # macOS:
    tinygo build -o main -opt=z -no-debug main.go
    
    # Linux:
    tinygo build -o main_linux -opt=z -no-debug main.go
    
    ./main_linux read Ioan 3 16
    ```

10. **Odin Implementation**
    *Platform: All*
    ```bash
    cd bible_reader_odin
    # macOS:
    odin build main.odin -file -o:speed -no-bounds-check
    
    # Linux:
    odin build main.odin -file -o:speed -no-bounds-check -out:main_linux
    
    ./main_linux read Ioan 3 16
    ```

11. **Forth Implementation (Termkey Image)**
    *Platform: All*
    ```bash
    cd bible_reader_forth
    # Generate 'reader.fi' image (Turnkey)
    gforth -e "include main.fs savesystem reader.fi bye"

    # Run the image (Requires Gforth installed)
    gforth -i reader.fi read Ioan 3 16
    ```

    *Linux "Standalone" Trick:*
    ```bash
    # Concatenate engine + image
    cat `which gforth-fast` reader.fi > bible_reader_linux
    chmod +x bible_reader_linux
    ./bible_reader_linux read Ioan 3 16
    ```

    *Windows:*
    Ship `reader.fi` with `gforth.exe`, and create a shortcut to run `gforth.exe -i reader.fi`.

## CLI Usage

All implementations (except Forth which takes arguments directly to script) follow this pattern:

```bash
./main read <Book> <Chapter> <Verse>
# Example: ./main read Ioan 3 16
```

Or for search (where implemented):
```bash
./main search <Query>
# Example: ./main search miazăzi
```
