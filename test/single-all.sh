#!/usr/bin/env bash
# single-all.sh — sweep test/single.sh over the whole examples/ corpus, with a
# declared denominator.
#
# WHY. single.sh asserts a property e2e.sh cannot see: each emitted translation
# unit must compile ALONE. e2e.sh always compiles every module together, so a TU
# that references an imported symbol or type without declaring it still links and
# still passes — the defect only appears when the unit is built by itself, which
# is what any real consumer of a single .c.nif does. single.sh took ONE program
# and nothing swept it, so that property held for whatever a human last typed.
#
# Same shape as e2e-all.sh: a declared PLAN, red when `ran != PLAN`.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

mapfile -t SRCS < <(ls examples/*.nim | sort)
mapfile -t MMS < <(ls -d examples/*/ 2>/dev/null | sort)
PLAN=${#SRCS[@]}
for d in "${MMS[@]}"; do [ -f "$d/main.nim" ] && PLAN=$((PLAN+1)); done
[ "$PLAN" -gt 0 ] || { echo "single-all: no examples found — refusing to report a green run"; exit 1; }

ran=0; ok=0; solo_fail=(); all_fail=(); setup=()
run_one() {
  local src="$1" name="$2" out rc
  out=$(bash test/single.sh "$src" 2>&1); rc=$?
  ran=$((ran+1))
  case $rc in
    0) ok=$((ok+1)); printf '  ok        %-14s\n' "$name" ;;
    2) setup+=("$name"); printf '  setup     %-14s (no .c.nif, or nothing emitted)\n' "$name" ;;
    *) if printf '%s' "$out" | grep -q 'SOLO-COMPILE FAIL'; then solo_fail+=("$name")
       else all_fail+=("$name"); fi
       printf '  FAIL      %-14s\n' "$name"
       printf '%s\n' "$out" | grep -A4 'FAIL' | sed 's/^/            /' | head -6 ;;
  esac
  return 0
}

for src in "${SRCS[@]}"; do run_one "$src" "$(basename "$src" .nim)"; done
for d in "${MMS[@]}"; do
  [ -f "$d/main.nim" ] || continue
  run_one "$d/main.nim" "$(basename "$d")"
done

echo
echo "aowlc single-TU: $ok/$PLAN emit a self-contained translation unit"
rc=0
if [ "$ran" -ne "$PLAN" ]; then echo "PLAN MISMATCH: declared $PLAN, executed $ran"; rc=1; fi
if [ ${#solo_fail[@]} -gt 0 ]; then
  echo "SOLO-COMPILE FAILED: ${solo_fail[*]}"
  echo "  the TU references something it does not declare — a whole-module-emission"
  echo "  bug, invisible to e2e.sh because that always links every module together."
  rc=1
fi
if [ ${#all_fail[@]} -gt 0 ]; then echo "ALL-COMPILE FAILED: ${all_fail[*]}"; rc=1; fi
if [ ${#setup[@]} -gt 0 ]; then echo "SETUP FAILED: ${setup[*]}"; rc=1; fi
exit "$rc"
