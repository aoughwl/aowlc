#!/usr/bin/env bash
# Honest correctness gate: emit EVERY module of a program with OUR emitc, gcc-link,
# run, and compare stdout to nimony's own binary. No subset oracle — real behavior.
#   test/e2e.sh <prog.nim>
set -uo pipefail
# $2 is an optional DISPLAY name. A multi-module case is a directory whose entry
# point is main.nim, so every one of them would otherwise report as "main".
src="$1"; name="${2:-$(basename "$src" .nim)}"
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
# -Wall -Wextra, on purpose: this is the check that would have caught `return;`
# from a non-void function the day it was written, instead of years later via a
# fixture that looked like a compile failure. The corpus is clean under both,
# minus two classes that are noise for GENERATED code and not defects:
#   -Wunused-parameter          a `{.base.}` method legitimately ignores its
#                               receiver, and an emitter cannot omit the param
#   -Wmissing-field-initializers  brace elision plus a designator override
#                               (`{ (&vt), .Q.w_0 = 3, .h_0 = 5 }`) is correct C99
# Everything else stays on, and a nonzero count is reported on its own line.
gccall=$(gcc -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers \
             "$out"/*.c -o "$out/$name" -lm 2>&1)
if [ ! -f "$out/$name" ]; then
  echo "COMPILE-FAIL $name  ($n modules): $(printf '%s' "$gccall" | head -1)"
  rm -rf "$nc" "$out"; exit 1
fi
# Warnings are not free: `return;` from a non-void function, an implicit
# declaration or an incompatible pointer is our emitter being wrong in a way that
# happens to survive this gcc, this ABI and this optimisation level. Report them.
warn=$(printf '%s' "$gccall" | grep -c 'warning:')
[ "$warn" -gt 0 ] && echo "WARNINGS $name: gcc emitted $warn warning(s) on our C"
# ...and that count was very nearly a fiction. Our own PRELUDE opens with
# sixteen `#pragma GCC diagnostic ignored` lines, and an in-file pragma BEATS
# the command line — so `-Wall -Wextra` above was switched off, inside the very
# files it was measuring, for precisely the categories the comment says it
# exists to catch (`-Wimplicit-function-declaration`, `-Wreturn-type`,
# `-Wincompatible-pointer-types`, `-Wint-conversion`, …). "The corpus is clean
# under both" was true the way an unrun test is green.
#
# So measure again on a STRIPPED copy — the pragma lines removed, nothing else
# touched. The link above still uses the real C, so what aowlc ships is
# unchanged; this is a second, syntax-only pass whose only job is to see what
# the pragmas were hiding.
#
# PERMITTED, and declared: six categories fire across the corpus and are noise
# for generated code — an emitter cannot know a label or temp goes unused, and
# brace elision is correct C. Everything else must not fire at all. Measured
# before it was enforced: those six are the complete set that fires, so the
# other ten pragmas suppress nothing and would only ever hide a new defect.
strict="$out/strict"; mkdir -p "$strict"
for c in "$out"/*.c; do
  grep -v '^#  pragma GCC diagnostic ignored' "$c" > "$strict/$(basename "$c")"
done
strictout=$(gcc -fsyntax-only -Wall -Wextra \
  -Wno-unused-parameter -Wno-missing-field-initializers \
  -Wno-unused-variable -Wno-unused-label -Wno-unused-function \
  -Wno-unused-but-set-variable -Wno-discarded-qualifiers -Wno-pointer-sign \
  -Wno-missing-braces -Wno-format -Wno-override-init \
  "$strict"/*.c 2>&1)
# -Wno-format is the one permitted category that is NOT cosmetic, so it is
# declared rather than folded in with the rest: nimony's own `system` prints an
# integer with `fprintf(stderr, "%lld", x)` where `x` is `NI64` — `long` on
# LP64, not `long long`. Same width, so it is right on every target we build
# for, and wrong by the standard. aowlc reproduces it faithfully; the format
# string is nimony's, not this emitter's, so fixing it here is not possible and
# patching nimony is not ours to do. Filed against aowlsem.
#
# -Wno-override-init is the second declared one, and it is not cosmetic either:
# it fires exactly twice in the corpus, on examples/e2e_packed.nim's `{.union.}`
# constructor. nimony's lowering puts a kv for EVERY union member in the
# oconstr, so `United(i: 5)` emits
#   United u = { .i_0 = 5, .f_0 = 0.0, .c_0 = 0 };
# and in a C union each designator overwrites the last, which is why `u.i` reads
# back 0. gcc is reporting a real semantic overwrite, not a redundancy. Both
# aowlc printers AND nimony's own binary produce the 0, so the fixture asserts
# that they agree rather than that 0 is right; it is nimony's lowering, already
# filed to aowlsem, and not something this emitter can fix. Permitted here so
# the other categories can be enforced today instead of waiting on it.
swarn=$(printf '%s' "$strictout" | grep -c 'warning:\|error:')
if [ "$swarn" -gt 0 ]; then
  echo "STRICT-WARN $name: $swarn diagnostic(s) the prelude's pragmas were hiding"
  printf '%s\n' "$strictout" | grep 'warning:\|error:' | head -5 | sed 's/^/  | /'
fi
got=$("$out/$name" 2>/dev/null | tr -d '\r')
# A mismatch must be RED. This used to fall through to the implicit exit 0 of the
# last command, so the one outcome the gate exists to catch — our binary printing
# something different from nimony's — reported failure on stdout and success to
# every caller (a loop over a corpus, CI, `&&`). COMPILE-FAIL above already
# exits 1; this is the same class of result.
rc=0
# A diagnostic the prelude was hiding is a FAILURE, not a note. Reporting it on
# stdout and exiting 0 is how the -Wall -Wextra above came to mean nothing for
# years: the line was printed and the caller saw success.
[ "$swarn" -gt 0 ] && rc=1
if [ "$got" = "$ref" ]; then echo "PASS $name"; else echo "RUN-MISMATCH $name  ref=[$ref] got=[$got]"; rc=1; fi
rm -rf "$nc" "$out"
exit "$rc"
