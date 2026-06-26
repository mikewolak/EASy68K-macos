# EASy68K → macOS Port

Porting **EASy68K** (Editor/Assembler + Simulator for the Motorola 68000) from
Borland C++ Builder 6 / VCL (Windows) to a native macOS application.

Upstream: https://github.com/ProfKelly/EASy68K.git (v5.16.01, March 2018)

## Ground rules

- **Core in C99 only.** The assembler and simulator are essentially portable C
  already. The only C++-isms are Borland's `AnsiString` (used lightly in ~6
  core files) and a couple of `#include <vcl.h>` lines — all removable.
- **Objective-C only for the Cocoa GUI** (and only where AppKit requires it).
  Obj-C is a strict superset of C, so the GUI calls the C99 core directly — no
  C++ bridging layer.
- **Lowercase filenames** throughout (`ASSEMBLE.CPP` → `assemble.c`).
- **Goal:** 1:1 functionality with the original, plus a modern, beautiful,
  Mac-native look & feel.

## Architecture

```
src/
  common/   shared helpers (string utils replacing AnsiString, platform shims)
  asm/      assembler core (libasm68k)   — pure C99, no GUI
  sim/      simulator/CPU core (libsim68k) — pure C99, GUI behind a host iface
app/
  macos/    Cocoa app (Objective-C, AppKit): editor, simulator, I/O console
tests/      C test harnesses for asm + sim, run on macOS
reference/  pristine originals (upstream zips + unpacked sources) — not built
```

The two cores build & unit-test as standalone CLI tools on macOS, fully
decoupled from any GUI. The GUI is layered on top last.

## Source mapping (upstream → port)

### Assembler core (from Edit68K, the UPPERCASE files = portable logic)
ASSEMBLE, BUILD, CODEGEN, DIRECTIV, ERROR, EVAL, INSTLOOK, INSTTABL, LISTING,
MACRO, MOVEM, OBJECT, OPPARSE, STRUCTURED, SYMBOL, BINFILE, GLOBALS, util
  → `src/asm/*.c`, headers `asm.h`, `proto.h`
The `*S.cpp/.dfm` files are VCL forms — replaced by the Cocoa editor.

### Simulator core (from Sim68K)
CODE1..9, SIMOPS1, SIMOPS2, RUN, SCAN, STARTSIM, STRUTILS, UTILS, BPoint,
BPointExpr, Net  → `src/sim/*.c`, headers `def.h`, `extern.h`, `var.h`,
`opcodes.h`, `proto.h`
GUI coupling is confined to RUN.CPP / SIMOPS2.CPP (run-loop + I/O TRAP #15) —
abstracted behind a `sim_host` callback interface.

### EASyBIN (S-record/binary utility) — port after the two cores.

## Phases

1. **Scaffold + assembler core** — port assembler to C99, build a CLI
   `asm68k` that assembles `.X68` → `.S68`/`.L68`. Verify against originals.
2. **Simulator core** — port CPU emulation to C99 behind a host interface,
   build a CLI `sim68k` runner. Verify execution of assembled programs.
3. **Cocoa app shell** — document model, native menus, editor window with
   68K syntax highlighting (replaces RichEditPlus).
4. **Simulator UI** — registers, memory, disassembly, breakpoints, I/O console.
5. **Polish** — EASyBIN, examples, help, app packaging, modern Mac look & feel.
```
