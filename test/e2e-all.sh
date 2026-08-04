#!/usr/bin/env bash
# e2e-all.sh — sweep test/e2e.sh over the whole examples/ corpus, with a declared
# denominator.
#
#   bash test/e2e-all.sh
#
# WHY THIS EXISTS. e2e.sh takes ONE .nim and nothing swept it, so "e2e passes"
# meant whatever a human happened to type that day — there was no total, no plan,
# and no way for a missing fixture to be noticed. staticinit.sh and units.sh both
# declare a PLAN and go red when `ran != PLAN`; this brings the end-to-end lane up
# to the same standard.
#
# THREE OUTCOMES, because two would lie. e2e.sh compares our binary's stdout
# against nimony's own `c -r`, so a fixture that prints nothing compares "" to ""
# and reports PASS while asserting nothing. That is not a failure and not a pass:
#   exit 0  PASS          output compared, and matched
#   exit 1  MISMATCH      output compared, and differed (or the build failed)
#   exit 2  VACUOUS       no output to compare, or nimony gave no oracle
# VACUOUS is reported on its own line and does NOT count toward passed. It is
# legitimate for localconst.nim, which is a staticinit.sh fixture and is
# deliberately import-free (with std/syncio it cannot be compiled as a single TU),
# so it is named here as an EXPECTED vacuum rather than being silently tolerated.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Fixtures that carry no output BY DESIGN. Anything else going vacuous is a
# corpus defect — a fixture that stopped asserting — and turns the run red.
#
# All four are SINGLE-MODULE fixtures for test.js / staticinit.sh / single.sh,
# which compile ONE .c.nif and assert properties of that emission. `echo` needs
# std/syncio, which makes the emission span four modules and is a different
# property — measured: importing it in these four takes test.js from 24/24 to
# 21/24, gcc failing inside the module-init function. So the output-producing
# versions live beside them as e2e_*.nim rather than replacing them, and these
# stay deliberately silent.
EXPECT_VACUOUS=(localconst compute fib mathf)

mapfile -t SRCS < <(ls examples/*.nim | sort)
PLAN=${#SRCS[@]}
[ "$PLAN" -gt 0 ] || { echo "e2e-all: no examples/*.nim found — refusing to report a green run"; exit 1; }

ran=0; passed=0; failed=(); vacuous=(); unexpected=()
for src in "${SRCS[@]}"; do
  name=$(basename "$src" .nim)
  out=$(bash test/e2e.sh "$src" 2>&1); rc=$?
  ran=$((ran+1))
  case $rc in
    0) passed=$((passed+1)); printf '  ok       %-12s %s\n' "$name" "$(printf '%s' "$out" | head -1)" ;;
    2) vacuous+=("$name")
       printf '  vacuous  %-12s (asserts nothing)\n' "$name"
       for e in "${EXPECT_VACUOUS[@]}"; do [ "$e" = "$name" ] && continue 2; done
       unexpected+=("$name") ;;
    *) failed+=("$name"); printf '  FAIL     %-12s\n' "$name"
       printf '%s\n' "$out" | sed 's/^/           /' | head -4 ;;
  esac
done

echo
echo "aowlc e2e: $passed/$PLAN compared against nimony's own output; ${#vacuous[@]} vacuous"
rc=0
if [ "$ran" -ne "$PLAN" ]; then
  echo "PLAN MISMATCH: declared $PLAN, executed $ran"; rc=1
fi
if [ ${#failed[@]} -gt 0 ]; then
  echo "FAILED: ${failed[*]}"; rc=1
fi
if [ ${#unexpected[@]} -gt 0 ]; then
  echo "NEWLY VACUOUS: ${unexpected[*]} — these compare empty to empty, so they"
  echo "  report a pass while asserting nothing. Give them output, or add them to"
  echo "  EXPECT_VACUOUS with the reason."; rc=1
fi
exit "$rc"
