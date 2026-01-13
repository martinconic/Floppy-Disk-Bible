# The Smallest Bible Reader Challenge

**Goal**: Fit the entire Romanian Bible (Cornilescu translation) + a searchable, functional CLI reader onto a standard **1.44 MB Floppy Disk**.

The Bible text data, compressed with `xz`, occupies **~1.16 MB**. This leaves approximately **280 KB** for the executable logic. This project explores implementing the same logic in various programming languages to compare binary sizes and efficiency.

## Binary Size Comparison (Final Results)

All binaries are verified to parse the data, handle formatting (e.g., Red Text for Jesus' words), and provide search functionality.

| Language | Binary Size | Floppy Fit | Notes |
| :--- | :--- | :--- | :--- |
| **Forth** | `~4.5 KB`* | ✅ Yes | *Script source size. Requires `gforth` VM installed. |
| **C (Nostart)** | `~9.0 KB` | ✅ Yes | Experimental `-nostartfiles`. (Crash prone on macOS). |
| **C (Standard)** | `~9.4 KB` | ✅ Yes | Standard GCC build. |
| **C++** | `~9.5 KB` | ✅ Yes | Optimized with `-fno-rtti -fno-exceptions`. |
| **Fortran (Optimized)** | `~13 KB` | ✅ Yes | `gfortran -Os -s` + C bindings. |
| **Fortran (Standard)** | `~14 KB` | ✅ Yes | `gfortran -O3 -s`. Very lean. |
| **Odin** | `~23 KB` | ✅ Yes | Uses `core:c` bindings, minimal runtime. |
| **Zig (Optimized)** | `~17 KB` | ✅ Yes | Manual `libc` bindings, stripped. |
| **Zig (Standard)** | `~51 KB` | ✅ Yes | `ReleaseSmall`, stripped. |
| **Go (Optimized)** | `~90 KB` | ✅ Yes | TinyGo + LibC bindings (No FMT). |
| **Pascal (Optimized)** | `~107 KB` | ✅ Yes | Free Pascal (`-XX -Xs`), No SysUtils, Stripped. |
| **Pascal (Standard)** | `~130 KB` | ✅ Yes | Standard Free Pascal build. |
| **Rust (Optimized)** | `~9 KB` | ✅ Yes | `no_std`, `libc`, manually stripped. |
| **Rust (Standard)** | `~371 KB` | ❌ No | Standard build stripped. |
| **Go (Standard)** | `~1,700 KB` | ❌ No | Standard build. Garbage collector/runtime overhead. |

---

## Build Instructions

### Prerequisites
-   `gcc`, `g++`, `gfortran` (GCC suite)
-   `fpc` (Free Pascal Compiler)
-   `zig` (Zig Compiler)
-   `rustc` / `cargo` (Rust)
-   `go` (Go)
-   `gforth` (GNU Forth)
-   `odin` (Odin Compiler)
-   `xz` (XZ Utils - runtime dependency for decompression)

### Instructions

1.  **C Implementation** (Winner)
    ```bash
    cd bible_reader_c
    gcc -O3 -s -o main main.c
    ./main read Ioan 3 16
    ```

2.  **C Implementation (Experimental -nostartfiles)**
    ```bash
    cd bible_reader_c_nostart
    gcc -Os -s -nostartfiles -Wl,-e,_start -o main main.c
    ./main read Ioan 3 16
    ```

3.  **C++ Implementation**
    ```bash
    cd bible_reader_cpp
    g++ -O3 -s -fno-rtti -fno-exceptions -o main main.cpp
    ./main read Ioan 3 16
    ```

3.  **Fortran Implementation (Optimized)**
    ```bash
    cd bible_reader_fortran_opt
    gfortran -Os -s -Wl,-dead_strip -o main main.f90
    ./main read Ioan 3 16
    ```

4.  **Fortran Implementation (Standard)**
    ```bash
    cd bible_reader_fortran
    gfortran -O3 -s -o main main.f90
    ./main read Ioan 3 16
    ```

5.  **Odin Implementation**
    ```bash
    cd bible_reader_odin
    odin build main.odin -file -o:speed -no-bounds-check
    ./main read Ioan 3 16
    ```

5.  **Forth Implementation** (Script)
    ```bash
    cd bible_reader_forth
    gforth main.fs read Ioan 3 16
    ```

6.  **Zig Implementation (Optimized)**
    ```bash
    cd bible_reader_zig_opt
    zig build-exe main.zig -O ReleaseSmall -fstrip -lc
    ./main read Ioan 3 16
    ```

7.  **Zig Implementation (Standard)**
    ```bash
    cd bible_reader_zig
    zig build-exe main.zig -O ReleaseSmall -fstrip -fsingle-threaded
    ./main read Ioan 3 16
    ```

9.  **Pascal Implementation (Optimized)**
    ```bash
    cd bible_reader_pascal_opt
    fpc -O3 -XX -Xs -omain main.pas
    strip main
    ./main read Ioan 3 16
    ```

10. **Pascal Implementation (Standard)**
    ```bash
    cd bible_reader_pascal
    fpc -O3 -XX -Xs -o main main.pas
    ./main read Ioan 3 16
    ```

11. **Rust Implementation**
    ```bash
    cd bible_reader_rust
    cargo build --release
    strip target/release/bible_reader_rust
    mv target/release/bible_reader_rust main
    ./main read Ioan 3 16
    ```

12. **Rust Implementation (Optimized)**
    ```bash
    cd bible_reader_rust_opt
    RUSTFLAGS="-C link-arg=-lSystem" cargo build --release
    strip target/release/bible_reader_rust_opt
    mv target/release/bible_reader_rust_opt main
    ./main read Ioan 3 16
    ```

13. **Go Implementation (Optimized)**
    ```bash
    cd bible_reader_go_opt
    tinygo build -o main -opt=z -no-debug main.go
    ./main read Ioan 3 16
    ```

14. **Go Implementation (Standard)**
    ```bash
    cd bible_reader
    go build -ldflags="-s -w" -o main main.go
    ./main read Ioan 3 16
    ```

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
