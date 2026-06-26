#!/bin/bash
# ======================================================================
#  EASy68K port — regression test suite
#
#  Assembles each tests/asm/*.X68 source and compares the generated
#  .S68 S-record against a hand-verified golden file. Exits non-zero on
#  any mismatch or assembler failure.
# ======================================================================
set -u
cd "$(dirname "$0")/.."

ASM=bin/asm68k
[ -x "$ASM" ] || { echo "error: $ASM not built (run 'make asm68k')"; exit 2; }

pass=0
fail=0

run_case() {
    local src="$1"
    local base="${src%.X68}"
    local golden="$base.golden.S68"
    local got="$base.S68"

    if ! "$ASM" "$src" >/dev/null 2>&1; then
        echo "FAIL  $src  (assembler returned error)"
        fail=$((fail+1)); return
    fi
    if [ ! -f "$golden" ]; then
        echo "SKIP  $src  (no golden file)"; return
    fi
    if diff -q "$golden" "$got" >/dev/null; then
        echo "ok    $src"
        pass=$((pass+1))
    else
        echo "FAIL  $src  (S-record differs from golden)"
        diff "$golden" "$got" | head -10
        fail=$((fail+1))
    fi
    rm -f "$got" "$base.L68" "$src.easytmp"
}

echo "== assembler regression tests =="
for src in tests/asm/*.X68; do
    run_case "$src"
done

echo "------------------------------------"
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
