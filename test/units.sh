#!/usr/bin/env bash
# test/units.sh — emitter state must not leak BETWEEN emitModuleBody calls.
#
#   bash test/units.sh
#   AOWLC=/path/to/aowlc-native bash test/units.sh
#
# THE BUG THIS GATES
#
# `foreignModuleOf` keeps two caches: `siblingSuffixes` (this suffix IS a sibling
# module) and `checkedSuffixes` (we already probed this suffix on disk).
# `resetEmitter` cleared the first and not the second — the second was declared
# 800 lines lower, next to its only reader, so it was never in the list.
#
# The effect is not a slowdown, it is silence. On the SECOND emitModuleBody call
# in a process, every suffix is already in `checkedSuffixes`, so foreignModuleOf
# returns "" before it looks at the disk, and the module is emitted with NO
# cross-module type or prototype declarations at all:
#
#   unknown type name 'ErrorCode_0_sysvq0asl'
#
# It is invisible to a one-module-per-process CLI, which is why it survived. The
# only multi-call consumer is aowli's mid-run JIT, whose in-process emit route
# had therefore NEVER succeeded on a program with more than one module — it fell
# back to shelling out to `aowlc link` every single time, so the fast path looked
# like it was working.
#
# `aowlc --units -o DIR a.c.nif b.c.nif …` exists to make that reachable from a
# shell: it emits several modules in ONE process, exactly as the JIT does.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
AOWLC="${AOWLC:-$ROOT/bin/aowlc-native}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PLAN=5
pass=0; fail=0
ok()  { printf 'ok    %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; fail=$((fail+1)); }

echo "aowlc gate: multi-call emitter state"
echo "  scope   : emitModuleBody called MORE THAN ONCE per process (what aowli's"
echo "            JIT does; the CLI's single-module path cannot reach this)."
echo "  printer : $AOWLC"
echo "  asserts : $PLAN declared"
echo

[ -x "$AOWLC" ] || { echo "units.sh: no aowlc-native at $AOWLC (bash build.sh)" >&2; exit 2; }

# Two shipped modules, emitted in one process. localconst is import-free, so it
# has no cross-module references of its own — it is here purely to CONSUME the
# first emit, i.e. to make system.c.nif the SECOND call.
A="$ROOT/examples/localconst.c.nif"
B="$ROOT/examples/system.c.nif"
for f in "$A" "$B"; do
  [ -f "$f" ] || { echo "units.sh: missing fixture $f" >&2; exit 2; }
done

# 1. the CLI grows the multi-unit mode at all
if "$AOWLC" --units -o "$WORK" "$A" "$B" > "$WORK/list.txt" 2>"$WORK/err.txt"; then
  ok "--units emits every module in one process ($(wc -l < "$WORK/list.txt") units)"
else
  bad "--units emits every module in one process" "$(head -c 200 "$WORK/err.txt")"
fi

U0="$WORK/unit_0_localconst.c"
U1="$WORK/unit_1_system.c"

# 2. the FIRST unit is fine — it always was, which is what made this invisible
if [ -s "$U0" ] && gcc -c "$U0" -o /dev/null 2>"$WORK/g0.err"; then
  ok "unit 0 compiles (the call that always worked)"
else
  bad "unit 0 compiles" "$(grep -m1 error "$WORK/g0.err" | cut -c1-140)"
fi

# 3. THE ONE. The SECOND call must still resolve cross-module symbols.
if [ -s "$U1" ] && gcc -c "$U1" -o /dev/null 2>"$WORK/g1.err"; then
  ok "unit 1 compiles — the second call still resolves foreign symbols"
else
  bad "unit 1 compiles — the second call still resolves foreign symbols" \
      "$(grep -m1 error "$WORK/g1.err" | cut -c1-140)"
fi

# 4. NEGATIVE CONTROL, and the reason this file is not a tautology: emitted ALONE
#    in its own process, the second module compiles even with the bug present. So
#    "it compiles" only means something when it is the SECOND call — assert both,
#    or a green result proves nothing about ordering.
"$AOWLC" "$B" > "$WORK/alone.c" 2>/dev/null
if [ -s "$WORK/alone.c" ] && gcc -c "$WORK/alone.c" -o /dev/null 2>/dev/null; then
  ok "the same module ALSO compiles emitted alone (so assertion 3 is about ORDER)"
else
  bad "the same module also compiles emitted alone" \
      "it does not, so assertion 3 cannot isolate the multi-call bug"
fi

# 5. The symptom named directly: cross-module TYPE declarations are present in the
#    second unit. gcc catches this today, but a future emitter could satisfy gcc
#    with a stub and still have dropped the declarations, so say what we mean.
nforeign=$(grep -cE '^\s*typedef .*_0_[a-z0-9]+;' "$U1" 2>/dev/null || echo 0)
if [ "$nforeign" -gt 0 ]; then
  ok "unit 1 carries $nforeign type declaration(s), not zero"
else
  bad "unit 1 carries type declarations" "none — the cross-module resolution produced nothing"
fi

echo
ran=$((pass + fail))
echo "======================================================"
echo "units: $pass passed, $fail failed"
echo "  scope  : multi-call emitter state only (emitc.nim resetEmitter /"
echo "           foreignModuleOf); fixtures examples/localconst.c.nif + system.c.nif"
echo "  asserts: $ran of $PLAN declared"
[ "$ran" -ne "$PLAN" ] && echo "  *** PLAN MISMATCH: a case stopped running; that is RED, not smaller."
echo "======================================================"
[ "$fail" -eq 0 ] && [ "$ran" -eq "$PLAN" ]
