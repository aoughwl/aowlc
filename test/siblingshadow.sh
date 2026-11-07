#!/usr/bin/env bash
# test/siblingshadow.sh — a sibling module's GLOBAL must not stand in for another module's TYPE.
#
#   bash test/siblingshadow.sh
#   AOWLC=/path/to/aowlc-native bash test/siblingshadow.sh
#
# THE BUG THIS GATES
#
# Cross-module resolution loads each referenced sibling `.c.nif` and keeps every
# proc, global and type it defines in ONE table per kind, across all siblings. A
# sibling records its own definitions with an empty module slot (`Rule.0.`), and
# the lookup forgave that by also matching the atom with its module dropped, and
# then (second fallback) by comparing stems only. The lookup never asked WHICH
# sibling the key came from, and it asked procs, then globals, then types.
#
# So when one module defines a global named `Rule` (`var Rule* = 3`, a colour
# constant in a real mod) and another module defines the TYPE `Rule`, a unit
# that loaded both resolved the type atom `Rule.0.<typeModule>` to the other
# module's global. The type was never declared in that unit, and gcc said
#
#   unknown type name 'Rule_0_<typeModule>'
#
# although the type was reached through an ordinary generic (seq[Rule]) over a
# type the module never names. The fix records the sibling each key came from and
# lets the loose spellings match only keys from the atom's own module.
#
# Fixtures: examples/siblingshadow/*.c.nif are the post-hexer output of prog.aowl
# (ma.aowl defines the private type Rule; entry.aowl a global Rule). No toolchain
# run is needed: aowlc prints the program module and gcc must accept it.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
AOWLC="${AOWLC:-$ROOT/bin/aowlc-native}"
FX="$ROOT/examples/siblingshadow"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export PATH="/c/msys64/ucrt64/bin:$PATH"

pass=0; fail=0
ok()  { printf 'ok    %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; fail=$((fail+1)); }

echo "aowlc gate: a sibling's global does not shadow another sibling's type"
echo "  printer : $AOWLC"
[ -x "$AOWLC" ] || [ -x "$AOWLC.exe" ] || { echo "siblingshadow.sh: no printer at $AOWLC" >&2; exit 2; }
command -v gcc >/dev/null || { echo "siblingshadow.sh: no gcc" >&2; exit 2; }

MAIN="$(ls "$FX"/mai*.c.nif | head -1)"
cp "$FX"/*.c.nif "$WORK"/
M="$WORK/$(basename "$MAIN")"
"$AOWLC" "$M" > "$WORK/main.c" 2> "$WORK/main.err" \
  && ok "1. aowlc prints the program module" || bad "1. aowlc prints the program module" "$(head -3 "$WORK/main.err")"

if grep -q "typedef struct Rule_0_" "$WORK/main.c"; then ok "2. the type Rule is declared in the program's unit"
else bad "2. the type Rule is declared in the program's unit" "no 'typedef struct Rule_0_' in the output"; fi

gcc -c -fsyntax-only -Wno-attributes "$WORK/main.c" > "$WORK/gcc.log" 2>&1 \
  && ok "3. gcc accepts the unit" || bad "3. gcc accepts the unit" "$(grep -m2 error "$WORK/gcc.log")"

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
