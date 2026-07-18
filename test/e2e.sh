#!/usr/bin/env bash
# Honest correctness gate: emit EVERY module of a program with OUR emitc, gcc-link,
# run, and compare stdout to nimony's own binary. No subset oracle — real behavior.
#   test/e2e.sh <prog.nim>
set -uo pipefail
src="$1"; name=$(basename "$src" .nim)
AOWLC="$HOME/aowlc/bin/aowlc-native"
ref=$(~/nimony/bin/nimony c -r "$src" 2>/dev/null | tr -d '\r')      # reference output
nc=$(mktemp -d); ~/nimony/bin/nimony c --nimcache:"$nc" "$src" >/dev/null 2>&1
out=$(mktemp -d); n=0
for d in "$nc"/*/; do for cn in "$d"*.c.nif; do
  [ -f "$cn" ] || continue; b=$(basename "$cn" .c.nif)
  "$AOWLC" "$cn" > "$out/$b.c" 2>/dev/null; n=$((n+1))
done; done
gccerr=$(gcc "$out"/*.c -o "$out/$name" -lm 2>&1 | head -1)
if [ ! -f "$out/$name" ]; then echo "COMPILE-FAIL $name  ($n modules): $gccerr"; rm -rf "$nc" "$out"; exit 1; fi
got=$("$out/$name" 2>/dev/null | tr -d '\r')
if [ "$got" = "$ref" ]; then echo "PASS $name"; else echo "RUN-MISMATCH $name  ref=[$ref] got=[$got]"; fi
rm -rf "$nc" "$out"
