#!/usr/bin/env bash
# test/driver.sh — exercise the `aowlc` DRIVER (bin/aowlc: emit/build/run/exec)
# on a real program, rather than the raw `aowlc-native` printer that e2e.sh uses.
#
#   bash test/driver.sh <prog.nim> [entryProc]
#
# The distinction matters: `exec --entry` builds a harness around ONE proc, while
# `build`/`run` emit the WHOLE module. A program that touches stdout exercises
# imported globals (`stdout`) and imported types (`LongString`), which only the
# whole-module path has to declare.
set -uo pipefail
src="$1"; entry="${2:-}"; name=$(basename "$src" .nim)
AOWLC="${AOWLC:-$HOME/aowlc/bin/aowlc}"
nc=$(mktemp -d); out=$(mktemp -d)
~/nimony/bin/nimony c --nimcache:"$nc" "$src" >/dev/null 2>&1

own=""
for d in "$nc"/*/ "$nc"/; do
  for cn in "$d"*.c.nif; do
    [ -f "$cn" ] || continue
    case "$(basename "$cn")" in "${name:0:3}"*) own="$cn";; esac
  done
done
[ -n "$own" ] || { echo "could not locate $name's own .c.nif"; exit 1; }
echo "own module: $own"
echo "modules in the cache:"; find "$nc" -name '*.c.nif' | sed 's/^/   /'

echo "--- aowlc build (WHOLE module) ---"
if "$AOWLC" build "$own" -o "$out/$name" >"$out/build.log" 2>&1; then
  echo "BUILD OK -> $("$out/$name" 2>&1 | head -3)"
else
  echo "BUILD FAIL:"; head -12 "$out/build.log" | sed 's/^/   /'
fi

if [ -n "$entry" ]; then
  echo "--- aowlc exec --entry $entry ---"
  if "$AOWLC" exec "$own" --entry "$entry" >"$out/exec.log" 2>&1; then
    echo "EXEC OK -> $(head -3 "$out/exec.log")"
  else
    echo "EXEC FAIL:"; head -12 "$out/exec.log" | sed 's/^/   /'
  fi
fi
echo "artifacts: $out"
