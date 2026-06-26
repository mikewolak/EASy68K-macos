# ======================================================================
#  EASy68K for macOS — top-level build
#
#  Targets:
#    make            build everything that is currently portable
#    make asm68k     the command-line assembler  (bin/asm68k)
#    make libs       static libraries only        (build/lib/*.a)
#    make test       build + run the test suite
#    make clean      remove all build output
#
#  Layout:
#    src/common  -> libcommon.a   (C99 portability shim + host hooks)
#    src/asm     -> libasm68k.a   (68000 assembler core, C99)
#    src/sim     -> libsim68k.a   (68000 simulator core, C99)   [phase 2]
#    app/cli     -> bin/asm68k, bin/sim68k   command-line front ends
#    app/macos   -> EASy68K.app   (Cocoa, Objective-C)          [phase 3]
# ======================================================================

CC      ?= clang
CSTD    := -std=c99
CFLAGS  := $(CSTD) -O2 -Wall -Wno-unused-variable -Wno-unused-but-set-variable \
           -Wno-unused-function -Wno-parentheses -Wno-dangling-else
CPPFLAGS := -Isrc/common -Isrc/asm -Isrc/sim

BUILD   := build
OBJDIR  := $(BUILD)/obj
LIBDIR  := $(BUILD)/lib
BINDIR  := bin
AR      := ar
ARFLAGS := rcs

# ---- source groups ---------------------------------------------------
COMMON_SRC := $(wildcard src/common/*.c)
ASM_SRC    := $(wildcard src/asm/*.c)

COMMON_OBJ := $(patsubst src/%.c,$(OBJDIR)/%.o,$(COMMON_SRC))
ASM_OBJ    := $(patsubst src/%.c,$(OBJDIR)/%.o,$(ASM_SRC))

LIBCOMMON  := $(LIBDIR)/libcommon.a
LIBASM     := $(LIBDIR)/libasm68k.a

# ---- top-level -------------------------------------------------------
.PHONY: all libs asm68k clean test dirs
all: asm68k

libs: $(LIBCOMMON) $(LIBASM)

asm68k: $(BINDIR)/asm68k

# ---- pattern rule for all C objects ----------------------------------
$(OBJDIR)/%.o: src/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

# ---- static libraries ------------------------------------------------
$(LIBCOMMON): $(COMMON_OBJ)
	@mkdir -p $(LIBDIR)
	$(AR) $(ARFLAGS) $@ $^

$(LIBASM): $(ASM_OBJ)
	@mkdir -p $(LIBDIR)
	$(AR) $(ARFLAGS) $@ $^

# ---- command-line assembler -----------------------------------------
$(BINDIR)/asm68k: app/cli/asm68k.c $(LIBASM) $(LIBCOMMON)
	@mkdir -p $(BINDIR)
	$(CC) $(CFLAGS) $(CPPFLAGS) $< -o $@ $(LIBASM) $(LIBCOMMON)

# ---- tests -----------------------------------------------------------
test: asm68k
	@tests/run_tests.sh

# ---- housekeeping ----------------------------------------------------
clean:
	rm -rf $(BUILD) $(BINDIR)
