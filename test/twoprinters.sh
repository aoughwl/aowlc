#!/usr/bin/env bash
# twoprinters.sh — run the corpus through BOTH printers and require the same answer.
#
# WHY THIS EXISTS. This repo has two C printers:
#
#   aowlc.js          the hand-written JavaScript one. `bin/aowlc` — the driver
#                     the README's usage examples invoke — uses it, and `npm test`
#                     is the only gate that does.
#   src/emitc.nim     the nimony one, built to bin/aowlc-native. e2e.sh,
#                     single.sh, units.sh and staticinit.sh all measure it.
#
# Every gate measured exactly one of them and NOTHING compared them. So a defect
# present in both was fixed in one and stayed in the other: `{.emit.}` was
# grouped with `pragmas`/`comment` in both printers and dropped silently — a
# program using it answered 41 where nimony says 42 — and fixing emitc.nim left
# aowlc.js still wrong, with every gate still green.
#
# Both are compared against NIMONY's own output, not against each other, so this
# says which one is wrong rather than only that they disagree.
#
# Requires: NIM (default ~/nimony), node, gcc.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
NIM="${NIM:-$HOME/nimony}"
AOWLC="${AOWLC:-$root/bin/aowlc-native}"

[ -x "$AOWLC" ] || { echo "twoprinters: no $AOWLC — run build.sh first" >&2; exit 1; }
command -v node >/dev/null || { echo "twoprinters: node not on PATH" >&2; exit 1; }

# Fixtures where aowlc.js is KNOWN to be behind src/emitc.nim. Listing them is
# not ignoring them: a name here that starts AGREEING fails the gate, so the
# exemption cannot outlive the divergence — the same contract run32.sh uses for
# its const-folder rows.
#
#   e2e_distinctglobal   a distinct conversion at global scope
#
# e2e_strprint used to be here too: aowlc.js walked a string by CODE POINT where
# a nimony string is BYTES, so `é` emitted one octal escape instead of its two
# UTF-8 bytes and every non-ASCII string printed as replacement characters.
#
# e2e_escapes used to be here and is not any more: aowlc.js emitted an UNPADDED
# octal escape, so "\n7" became `\12` + `7` and C read `\127` as one escape (the
# string printed `W`). emitc.nim had been fixed with toOctal3; the JavaScript
# printer had not. The gate reported it as a STALE EXEMPTION the moment it
# agreed, which is the contract working.
#
# Each was fixed in the nimony printer and not in the JavaScript one, which is
# exactly what this gate exists to surface. Whether aowlc.js should be brought
# level or retired is a product decision, not this script's.
KNOWN_JS_BEHIND="e2e_distinctglobal"
isKnownJs() { for k in $KNOWN_JS_BEHIND; do [ "$k" = "$1" ] && return 0; done; return 1; }

out=$(mktemp -d); trap 'rm -rf "$out"' EXIT
mapfile -t SRCS < <(ls examples/*.nim | sort)
PLAN=${#SRCS[@]}
[ "$PLAN" -gt 0 ] || { echo "twoprinters: no examples/*.nim found"; exit 1; }

ran=0; both=0; jsbad=(); natbad=(); skipped=(); knownjs=(); stale=()
for src in "${SRCS[@]}"; do
  name=$(basename "$src" .nim)
  ran=$((ran+1))
  nc="$out/nc/$name"; rm -rf "$nc"; mkdir -p "$nc"
  # Reference and artifacts are SEPARATE runs, as in e2e.sh: `c -r` prints the
  # program's output, and a second `c --nimcache:` leaves the .c.nif behind.
  ref=$("$NIM/bin/nimony" c -r "$src" 2>/dev/null); refrc=$?
  # Compile a copy named `src.nim`, so the program's OWN artifact is the one
  # whose basename starts with "src". Every fixture here is `e2e_*`, and nimony
  # derives the artifact prefix from the file name, so the obvious heuristic
  # (first three letters) matches most of the corpus at once.
  sdir="$out/src/$name"; rm -rf "$sdir"; mkdir -p "$sdir"
  cp "$src" "$sdir/src.nim"
  "$NIM/bin/nimony" c --nimcache:"$nc" "$sdir/src.nim" >/dev/null 2>&1
  # An empty or failed reference asserts nothing — the VACUOUS case e2e.sh
  # already documents. Skip rather than score "" against "".
  if [ "$refrc" -ne 0 ] || [ -z "$ref" ]; then [ "${DBG:-0}" = 1 ] && echo "  skip(ref) $name rc=$refrc"; skipped+=("$name"); continue; fi
  ref=$(printf '%s' "$ref" | tr -d '\r\000')

  own=""
  for d in "$nc"/*/ "$nc"/; do for cn in "$d"src*.c.nif; do
    [ -f "$cn" ] && own="$cn"
  done; done
  [ -n "$own" ] || { [ "${DBG:-0}" = 1 ] && echo "  skip(own) $name"; skipped+=("$name"); continue; }

  # the JS printer, through the driver that ships it
  jsgot=$(timeout 200 node bin/aowlc run "$own" 2>/dev/null | grep -av '^aowlc: ' | tr -d '\r\000')

  # the nimony printer: emit every module, link, run
  cdir="$out/c/$name"; rm -rf "$cdir"; mkdir -p "$cdir"
  for d in "$nc"/*/; do for cn in "$d"*.c.nif; do
    [ -f "$cn" ] || continue; b=$(basename "$cn" .c.nif)
    "$AOWLC" "$cn" > "$cdir/$b.c" 2>/dev/null
  done; done
  natgot=""
  if gcc "$cdir"/*.c -o "$cdir/prog" -lm 2>/dev/null; then
    natgot=$("$cdir/prog" 2>/dev/null | tr -d '\r\000')
  fi

  bad=0
  jsok=1
  if [ "$jsgot" != "$ref" ]; then
    jsok=0
    if isKnownJs "$name"; then knownjs+=("$name")
    else jsbad+=("$name"); bad=1; fi
  elif isKnownJs "$name"; then
    stale+=("$name")
  fi
  [ "$natgot" != "$ref" ] && { natbad+=("$name"); bad=1; }
  if [ "$jsok" -eq 1 ] && [ "$natgot" = "$ref" ]; then
    both=$((both+1))
  else
    isKnownJs "$name" && [ "$natgot" = "$ref" ] && continue   # listed already
    printf '  DIFFER   %-16s\n' "$name"
    [ "$jsgot" != "$ref" ]  && printf '    aowlc.js   [%.60s]\n' "$jsgot"
    [ "$natgot" != "$ref" ] && printf '    native     [%.60s]\n' "$natgot"
    printf '    nimony     [%.60s]\n' "$ref"
  fi
done

echo
echo "aowlc two-printer: $both/$((ran - ${#skipped[@]})) agree with nimony in BOTH printers"
echo "  ($ran examples, ${#skipped[@]} skipped for having no output to compare)"
rc=0
if [ ${#knownjs[@]} -gt 0 ]; then
  echo "aowlc.js behind (known, listed in KNOWN_JS_BEHIND): ${knownjs[*]}"
fi
if [ ${#stale[@]} -gt 0 ]; then
  echo "STALE EXEMPTION: ${stale[*]} — aowlc.js agrees now; drop it from"
  echo "  KNOWN_JS_BEHIND in test/twoprinters.sh"
  rc=1
fi
if [ ${#jsbad[@]} -gt 0 ];  then echo "aowlc.js WRONG: ${jsbad[*]}"; rc=1; fi
if [ ${#natbad[@]} -gt 0 ]; then echo "native WRONG: ${natbad[*]}"; rc=1; fi
exit "$rc"
