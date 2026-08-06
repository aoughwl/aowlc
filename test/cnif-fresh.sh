#!/usr/bin/env bash
# aowlc COMMITTED-ARTIFACT FRESHNESS gate.
#
# `npm test` (test/test.js) runs its exec cases against `.c.nif` files COMMITTED
# under examples/. Nobody regenerates them. So the `.nim` beside each one can
# drift arbitrarily — a fixture can be edited, or nimony's lowering can change —
# and test.js goes on measuring the old artifact with every gate green.
#
# Demonstrated, not hypothesised: editing examples/compute.nim, fib.nim and
# mathf.nim to print their results left `npm test` at 24/24, because it never
# looked at the sources at all.
#
# WHY NOT A BYTE DIFF. A fresh `.c.nif` legitimately differs from the committed
# one for reasons that are not source drift: the recorded source PATH differs by
# working directory, and the current nimony adds declarations the older one did
# not (`nimEnviron`). Diffing bytes would be red today for nothing. What matters
# is whether the artifact still COMPUTES what the expectations say, so this
# regenerates each `.c.nif` from its `.nim` and runs test.js's own case table
# against the fresh directory via $AOWLC_CNIF_DIR. Same expectations, new
# artifact: a source that drifted away from them fails here, and a harmless
# toolchain difference does not.
#
# Not part of `npm test`: it costs a nimony compile per fixture. Run it when a
# fixture or the toolchain changes.
#
# Requires: NIM (default ~/nimony), node, gcc.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
NIM="${NIM:-$HOME/nimony}"
LOCK="$HOME/.aowl/bin/nimlock"
[ -x "$LOCK" ] || LOCK=""

out=$(mktemp -d)
if [ "${KEEP:-0}" = 1 ]; then echo "cnif-fresh: keeping $out"; else trap 'rm -rf "$out"' EXIT; fi
# Start from a COPY of examples/ rather than an empty directory, then overlay
# each regenerated artifact. An empty one silently shrank the run: test.js's
# whole-program cases look for the prog_echo/ and prog_seqsum/ fixture
# DIRECTORIES, found neither, and skipped both — 22/22 instead of 24/24, with
# the smaller denominator reading exactly like a pass.
fresh="$out/cnif"; cp -r "$ROOT/examples" "$fresh"

# A DECLARED denominator: every committed .c.nif that has a .nim beside it. One
# with no source cannot be regenerated and is named, not skipped silently.
plan=0; regen=0; nosrc=()
for cn in "$ROOT"/examples/*.c.nif; do
  [ -f "$cn" ] || continue
  base=$(basename "$cn" .c.nif)
  plan=$((plan+1))
  src="$ROOT/examples/$base.nim"
  if [ ! -f "$src" ]; then nosrc+=("$base"); continue; fi
  nc="$out/nc/$base"; mkdir -p "$nc"
  # shellcheck disable=SC2086
  $LOCK "$NIM/bin/nimony" c --nimcache:"$nc" "$src" >"$out/$base.log" 2>&1
  # The ENTRY module's artifact is the one whose basename matches its parent
  # directory; the others are the stdlib modules it pulled in.
  got=""
  for d in "$nc"/*/; do
    b=$(basename "$d")
    [ -f "$d$b.c.nif" ] && got="$d$b.c.nif"
  done
  if [ -z "$got" ]; then
    echo "aowlc cnif-fresh: FAILED — $base.nim produced no .c.nif" >&2
    tail -5 "$out/$base.log" >&2
    exit 1
  fi
  cp "$got" "$fresh/$base.c.nif"
  regen=$((regen+1))
done

if [ "$plan" -eq 0 ]; then
  echo "aowlc cnif-fresh: FAILED — no examples/*.c.nif to check" >&2; exit 1
fi
if [ "${#nosrc[@]}" -gt 0 ]; then
  echo "aowlc cnif-fresh: ${#nosrc[@]} committed artifact(s) have no .nim beside them"
  echo "  and so cannot be regenerated or checked: ${nosrc[*]}"
fi

# Run test.js's own case table against the FRESH artifacts. Anything not
# regenerated above is still the COMMITTED copy, carried over by the cp -r: the
# two source-less artifacts named above, and the multi-module prog_* fixture
# directories, which have no .nim either. Those cases therefore still measure
# the committed bytes, and this line is the only thing that says so.

if AOWLC_CNIF_DIR="$fresh" node "$HERE/test.js" > "$out/run.log" 2>&1; then
  echo "aowlc cnif-fresh: $regen/$plan artifacts regenerated; test.js's expectations still hold"
  tail -1 "$out/run.log" | sed 's/^/  /'
  exit 0
fi

echo "aowlc cnif-fresh: FAILED — test.js's expectations do not hold against freshly"
echo "  regenerated .c.nif. Either a fixture's .nim drifted from the committed"
echo "  artifact, or nimony's lowering changed. The committed artifact is what"
echo "  npm test measures, so it is now measuring something the source no longer says."
grep -v '^  ok' "$out/run.log" | head -20 | sed 's/^/  /'
exit 1
