#!/usr/bin/env bash
# Honest correctness gate: emit EVERY module of a program with OUR emitc, gcc-link,
# run, and compare stdout to nimony's own binary. No subset oracle — real behavior.
#   test/e2e.sh <prog.nim>
set -uo pipefail
src="$1"; name=$(basename "$src" .nim)
# Overridable, like driver.sh and single.sh already are: with the path hardcoded
# to $HOME/aowlc a git WORKTREE cannot gate its own build — it silently measured
# the main checkout's binary, which on this machine was stale enough to be missing
# a change already in master's source.
AOWLC="${AOWLC:-$HOME/aowlc/bin/aowlc-native}"
# Reference output. The status must come from NIMONY, so it is captured on its
# own line and the \r strip happens afterwards: `ref=$(nimony … | tr …)` followed
# by ${PIPESTATUS[0]} reads the status of `tr` (the substitution is not a pipeline
# in this shell), and tr essentially never fails — so NO-REFERENCE below could
# never fire and every failed oracle would have been labelled VACUOUS instead.
ref=$(~/nimony/bin/nimony c -r "$src" 2>/dev/null); refrc=$?
ref=$(printf '%s' "$ref" | tr -d '\r')
# AN EMPTY REFERENCE IS NOT A PASS. The comparison at the bottom is `got = ref`,
# so when nimony's own run prints nothing, ANY binary of ours that also prints
# nothing "matches" and this gate printed `PASS` having compared "" to "".
# Measured on the shipped corpus: 4 of the 6 examples/*.nim (compute, fib,
# localconst, mathf) are silent — they define procs and print nothing — so four
# sixths of a clean sweep were vacuous. Only hello and stdouts ever compared
# text.
#
# That is a THIRD outcome, not a failure: nothing is broken, the case simply
# carries no information. It gets its own exit code (2) so a corpus loop can
# count it apart from a real RUN-MISMATCH (1) instead of either hiding it in the
# PASS column or reading it as a defect.
# ORDER MATTERS: status before emptiness. nimony prints its diagnostics on
# STDOUT, so a failed `c -r` does NOT leave $ref empty — it leaves $ref holding
# the ERROR TEXT, and that text then becomes the oracle this gate compares
# against. Our binary would have to reproduce nimony's error message verbatim to
# be called a PASS. Caught with a deliberate control (a file of non-Nim text):
# it reached COMPILE-FAIL instead of NO-REFERENCE, i.e. it sailed straight past
# an emptiness test that was never going to fire.
if [ "$refrc" -ne 0 ] || [ -z "$ref" ]; then
  if [ "$refrc" -ne 0 ]; then
    echo "NO-REFERENCE $name: nimony's own \`c -r\` failed (exit $refrc), so there is no oracle to compare against"
    printf '%s\n' "$ref" | sed 's/^/  | /' | head -5
  else
    echo "VACUOUS $name: nimony's own run prints nothing, so an empty-vs-empty comparison would report PASS while asserting nothing — this case needs a program that produces output"
  fi
  exit 2
fi
nc=$(mktemp -d); ~/nimony/bin/nimony c --nimcache:"$nc" "$src" >/dev/null 2>&1
out=$(mktemp -d); n=0
for d in "$nc"/*/; do for cn in "$d"*.c.nif; do
  [ -f "$cn" ] || continue; b=$(basename "$cn" .c.nif)
  "$AOWLC" "$cn" > "$out/$b.c" 2>/dev/null; n=$((n+1))
done; done
# DO NOT pipe gcc into `head` here. `gcc … 2>&1 | head -1` makes head exit after
# one line, and gcc then dies of SIGPIPE writing its second diagnostic — so a
# program that merely produced two lines of WARNINGS was reported COMPILE-FAIL
# with no binary, indistinguishable from a real error. Caught on an exceptions
# fixture that compiles, links and matches nimony perfectly when gcc is left
# alone. Capture in full; truncate only for display.
gccall=$(gcc "$out"/*.c -o "$out/$name" -lm 2>&1)
if [ ! -f "$out/$name" ]; then
  echo "COMPILE-FAIL $name  ($n modules): $(printf '%s' "$gccall" | head -1)"
  rm -rf "$nc" "$out"; exit 1
fi
# Warnings are not free: `return;` from a non-void function, an implicit
# declaration or an incompatible pointer is our emitter being wrong in a way that
# happens to survive this gcc, this ABI and this optimisation level. Report them.
warn=$(printf '%s' "$gccall" | grep -c 'warning:')
[ "$warn" -gt 0 ] && echo "WARNINGS $name: gcc emitted $warn warning(s) on our C"
got=$("$out/$name" 2>/dev/null | tr -d '\r')
# A mismatch must be RED. This used to fall through to the implicit exit 0 of the
# last command, so the one outcome the gate exists to catch — our binary printing
# something different from nimony's — reported failure on stdout and success to
# every caller (a loop over a corpus, CI, `&&`). COMPILE-FAIL above already
# exits 1; this is the same class of result.
rc=0
if [ "$got" = "$ref" ]; then echo "PASS $name"; else echo "RUN-MISMATCH $name  ref=[$ref] got=[$got]"; rc=1; fi
rm -rf "$nc" "$out"
exit "$rc"
