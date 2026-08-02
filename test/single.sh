#!/usr/bin/env bash
# test/single.sh — emit ONE module with aowlc and compile that translation unit
# ALONE, to separate two very different failures:
#
#   * a codegen bug              (bad C for the module's own code)
#   * a whole-module-emission bug (C that references imported symbols/types
#     without declaring them — 'stdout_0_…' undeclared, unknown type
#     'LongString_0_…' — which only shows up when the TU is compiled by itself)
#
#   bash test/single.sh <prog.nim>
set -uo pipefail
src="$1"; name=$(basename "$src" .nim)
AOWLC="${AOWLC:-$HOME/aowlc/bin/aowlc-native}"
nc=$(mktemp -d); out=$(mktemp -d)
~/nimony/bin/nimony c --nimcache:"$nc" "$src" >/dev/null 2>&1

# the program's OWN module: the .c.nif whose sibling .final.build.nif exists
own=""
for d in "$nc"/*/; do
  for f in "$d"*.final.build.nif; do
    [ -f "$f" ] || continue
    cand="${f%.final.build.nif}.c.nif"
    [ -f "$cand" ] && own="$cand"
  done
done
if [ -z "$own" ]; then
  # fall back: nimony derives a module's suffix hash from its NAME, so the
  # program's own artifact starts with the first letters of the basename.
  for d in "$nc"/*/ "$nc"/; do
    for cn in "$d"*.c.nif; do
      [ -f "$cn" ] || continue
      case "$(basename "$cn")" in "${name:0:3}"*) own="$cn";; esac
    done
  done
fi
if [ -z "$own" ]; then
  echo "could not locate $name's own .c.nif; nimcache holds:"
  find "$nc" -name '*.c.nif' | sed 's/^/   /' | head -20
  exit 1
fi
echo "own module: $(basename "$own")"

mkdir -p "$out/solo"        # keep own.c OUT of the all-modules dir, else the
                            # link sees the same module twice (bogus
                            # "multiple definition of main")
"$AOWLC" "$own" > "$out/solo/own.c" 2>"$out/emit.err"
if [ ! -s "$out/solo/own.c" ]; then
  echo "EMIT-FAIL: $(head -3 "$out/emit.err")"; exit 1
fi
echo "emitted $(wc -l < "$out/solo/own.c") lines of C"

echo "--- compiling that ONE translation unit alone ---"
if gcc -c "$out/solo/own.c" -o "$out/solo/own.o" 2>"$out/gcc.err"; then
  echo "SOLO-COMPILE OK  (whole-module emission is self-contained)"
else
  echo "SOLO-COMPILE FAIL:"
  head -12 "$out/gcc.err" | sed 's/^/   /'
fi

echo "--- compiling ALL modules together (what e2e.sh does) ---"
n=0
for d in "$nc"/*/; do for cn in "$d"*.c.nif; do
  [ -f "$cn" ] || continue; b=$(basename "$cn" .c.nif)
  "$AOWLC" "$cn" > "$out/$b.c" 2>/dev/null; n=$((n+1))
done; done
if gcc "$out"/*.c -o "$out/$name" -lm 2>"$out/gccall.err"; then
  echo "ALL-COMPILE OK ($n modules) -> $("$out/$name" 2>&1 | head -3)"
else
  echo "ALL-COMPILE FAIL ($n modules):"
  head -12 "$out/gccall.err" | sed 's/^/   /'
fi
echo "artifacts: $out"
