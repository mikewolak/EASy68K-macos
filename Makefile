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
CFLAGS  := $(CSTD) -O2 -D_DARWIN_C_SOURCE \
           -Wall -Wno-unused-variable -Wno-unused-but-set-variable \
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
# net.c is the Winsock networking device; it lives in the host GUI layer.
SIM_SRC    := $(filter-out src/sim/net.c,$(wildcard src/sim/*.c))
# Sim core WITHOUT the CLI host (simhost_cli.c): the Cocoa app supplies its
# own host (SimBridge), so it links these objects directly.
SIM_CORE_SRC := $(filter-out src/sim/net.c src/sim/simhost_cli.c,$(wildcard src/sim/*.c))

COMMON_OBJ := $(patsubst src/%.c,$(OBJDIR)/%.o,$(COMMON_SRC))
ASM_OBJ    := $(patsubst src/%.c,$(OBJDIR)/%.o,$(ASM_SRC))
SIM_OBJ    := $(patsubst src/%.c,$(OBJDIR)/%.o,$(SIM_SRC))
SIM_CORE_OBJ := $(patsubst src/%.c,$(OBJDIR)/%.o,$(SIM_CORE_SRC))

LIBCOMMON  := $(LIBDIR)/libcommon.a
LIBASM     := $(LIBDIR)/libasm68k.a
LIBSIM     := $(LIBDIR)/libsim68k.a

# ---- macOS app -------------------------------------------------------
APP        := build/EASy68K.app
MACOS_M    := $(wildcard app/macos/*.m)
MACOS_C    := $(wildcard app/macos/*.c)
APP_EXE    := $(APP)/Contents/MacOS/EASy68K
# The sim core and the assembler share a few global names (buffer, eval,
# numBuf, newFile) — fine when they were separate .exe's, but they collide
# inside the unified app. Pre-link the sim core into one relocatable object
# with those symbols localized so each engine keeps its own.
SIMCORE_COMBINED := $(OBJDIR)/simcore_combined.o

# ---- top-level -------------------------------------------------------
.PHONY: all libs asm68k sim68k app run-app clean test dirs
all: asm68k sim68k

libs: $(LIBCOMMON) $(LIBASM) $(LIBSIM)

asm68k: $(BINDIR)/asm68k
sim68k: $(BINDIR)/sim68k
app: $(APP)

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

$(LIBSIM): $(SIM_OBJ)
	@mkdir -p $(LIBDIR)
	$(AR) $(ARFLAGS) $@ $^

# ---- command-line assembler -----------------------------------------
$(BINDIR)/asm68k: app/cli/asm68k.c $(LIBASM) $(LIBCOMMON)
	@mkdir -p $(BINDIR)
	$(CC) $(CFLAGS) $(CPPFLAGS) $< -o $@ $(LIBASM) $(LIBCOMMON)

# ---- command-line simulator -----------------------------------------
$(BINDIR)/sim68k: app/cli/sim68k.c $(LIBSIM) $(LIBCOMMON)
	@mkdir -p $(BINDIR)
	$(CC) $(CFLAGS) $(CPPFLAGS) $< -o $@ $(LIBSIM) $(LIBCOMMON)

# ---- macOS Cocoa app -------------------------------------------------
# The editor calls libasm68k; the integrated simulator window links the sim
# core directly (SIM_CORE_OBJ) and supplies a Cocoa host via SimBridge.c.
# The .c bridge is compiled as plain C (no Cocoa headers) so the sim core's
# def.h constants don't clash with system headers; the .m files are ObjC.
$(SIMCORE_COMBINED): $(SIM_CORE_OBJ) app/macos/sim_hidden.txt
	@mkdir -p $(dir $@)
	ld -r -unexported_symbols_list app/macos/sim_hidden.txt $(SIM_CORE_OBJ) -o $@

$(APP): $(MACOS_M) $(MACOS_C) app/macos/Info.plist $(LIBASM) $(LIBCOMMON) $(SIMCORE_COMBINED) $(BINDIR)/sim68k
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp app/macos/Info.plist $(APP)/Contents/Info.plist
	cp $(BINDIR)/sim68k $(APP)/Contents/MacOS/sim68k
	cp app/macos/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	cp app/macos/logo.png $(APP)/Contents/Resources/logo.png
	$(CC) -fobjc-arc -fmodules $(CPPFLAGS) -framework Cocoa -framework CoreVideo \
	    $(MACOS_M) $(MACOS_C) $(SIMCORE_COMBINED) $(LIBASM) $(LIBCOMMON) -o $(APP_EXE)
	@echo "built $(APP)"

run-app: $(APP)
	open $(APP)

# ---- tests -----------------------------------------------------------
test: asm68k sim68k
	@tests/run_tests.sh

# ---- housekeeping ----------------------------------------------------
clean:
	rm -rf $(BUILD) $(BINDIR)
