#!/usr/bin/env bash
# test/driver.sh — exercise the `aowlc` DRIVER (bin/aowlc: emit/build/run/exec)
# on a real program, rather than the raw `aowlc-native` printer that e2e.sh uses.
#
#   bash test/driver.sh <prog.nim> [entryProc] [--arg V]...
#
# The distinction matters: `exec --entry` builds a harness around ONE proc, while
# `build`/`run` emit the WHOLE module. A program that touches stdout exercises
# imported globals (`stdout`) and imported types (`LongString`), which only the
# whole-module path has to declare.
#
# --arg is repeatable and positional-by-declaration-order: the Nth --arg is the
# Nth parameter of `entryProc`. It is passed straight through to the driver's own
# `--arg`, which is the convention test/test.js's CASES already use
# (`exec <file> --entry gcd --arg 48 --arg 36`) — same flag, same order, so there
# is only one way to invoke an entry across the whole test lane. Without this an
# entry with parameters could not be driven at all: the harness called it with no
# arguments and the C compiler rejected the harness itself
# ("too few arguments to function 'gcd_0_'").
#
# EXIT STATUS. Diagnostic output is unchanged and still PRINTS every failure
# rather than aborting at the first one, but the script now exits non-zero if any
# stage failed (BUILD FAIL / EXEC FAIL), so it can be used in a `&&` chain or a
# loop. Exit 1 = a stage failed; exit 2 = the script could not even set up (no
# .c.nif located).
set -uo pipefail
# The machine-wide compile lock. Two `nimony c` runs at once corrupt each other's
# link through the shared `nimcache_static` — a CROSS-PROCESS hazard a private
# `--nimcache:` does not cover, because the static object is shared across
# caches. Unlocked, this gate's result depended on nobody else compiling at the
# same moment, and the damage surfaced as a failure attributed to aowlc.
LOCK="$HOME/.aowl/bin/nimlock"
[ -x "$LOCK" ] || LOCK=""
src="${1:-}"; shift || true
[ -n "$src" ] || { echo "usage: driver.sh <prog.nim> [entryProc] [--arg V]..." >&2; exit 2; }
entry=""
case "${1:-}" in
  ""|--*) ;;
  *) entry="$1"; shift ;;
esac
eargs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --arg) [ $# -ge 2 ] || { echo "driver.sh: --arg needs a value" >&2; exit 2; }
           eargs+=(--arg "$2"); shift 2 ;;
    *) echo "driver.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
name=$(basename "$src" .nim)
AOWLC="${AOWLC:-$HOME/aowlc/bin/aowlc}"
nc=$(mktemp -d); out=$(mktemp -d)
$LOCK ~/nimony/bin/nimony c --nimcache:"$nc" "$src" >/dev/null 2>&1

own=""
for d in "$nc"/*/ "$nc"/; do
  for cn in "$d"*.c.nif; do
    [ -f "$cn" ] || continue
    case "$(basename "$cn")" in "${name:0:3}"*) own="$cn";; esac
  done
done
[ -n "$own" ] || { echo "could not locate $name's own .c.nif"; exit 2; }
rc=0
echo "own module: $own"
echo "modules in the cache:"; find "$nc" -name '*.c.nif' | sed 's/^/   /'

echo "--- aowlc build (WHOLE module) ---"
if "$AOWLC" build "$own" -o "$out/$name" >"$out/build.log" 2>&1; then
  echo "BUILD OK -> $("$out/$name" 2>&1 | head -3)"
else
  echo "BUILD FAIL:"; head -12 "$out/build.log" | sed 's/^/   /'; rc=1
fi

if [ -n "$entry" ]; then
  echo "--- aowlc exec --entry $entry${eargs[0]+ ${eargs[*]}} ---"
  if "$AOWLC" exec "$own" --entry "$entry" ${eargs[@]+"${eargs[@]}"} >"$out/exec.log" 2>&1; then
    echo "EXEC OK -> $(head -3 "$out/exec.log")"
  else
    echo "EXEC FAIL:"; head -12 "$out/exec.log" | sed 's/^/   /'; rc=1
  fi
fi
echo "artifacts: $out"
exit "$rc"
