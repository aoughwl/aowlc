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
# The machine-wide compile lock. Two `nimony c` runs at once corrupt each other's
# link through the shared `nimcache_static` — a CROSS-PROCESS hazard a private
# `--nimcache:` does not cover, because the static object is shared across
# caches. Unlocked, this gate's result depended on nobody else compiling at the
# same moment, and the damage surfaced as a failure attributed to aowlc.
LOCK="$HOME/.aowl/bin/nimlock"
[ -x "$LOCK" ] || LOCK=""
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
NIM="${NIM:-$HOME/nimony}"
AOWLC="${AOWLC:-$root/bin/aowlc-native}"

[ -x "$AOWLC" ] || { echo "twoprinters: no $AOWLC — run build.sh first" >&2; exit 1; }
command -v node >/dev/null || { echo "twoprinters: node not on PATH" >&2; exit 1; }

# Fixtures where aowlc.js is KNOWN to be behind src/emitc.nim.
#
# EMPTY, and that is the point. It held three entries when this gate was written
# and all three were places a fix had landed in the nimony printer and not the
# JavaScript one:
#
#   e2e_escapes          an UNPADDED octal escape, so "\n7" emitted `\12` + `7`
#                        and C read `\127` as one escape — the string printed `W`
#   e2e_strprint         strings walked by CODE POINT where a nimony string is
#                        BYTES, so `é` emitted one escape instead of its two UTF-8
#                        bytes and non-ASCII printed as replacement characters
#   e2e_distinctglobal   a conversion wrapping a constructor emitted `((T)(T){…})`,
#                        and the cast is what stops an initializer being constant
#
# Each was reported as a STALE EXEMPTION the moment it started agreeing, which is
# the only reason a list like this is safe to keep: it cannot outlive the
# divergence it records.
KNOWN_JS_BEHIND=""
isKnownJs() { for k in $KNOWN_JS_BEHIND; do [ "$k" = "$1" ] && return 0; done; return 1; }

out=$(mktemp -d); trap 'rm -rf "$out"' EXIT
# Single-module fixtures AND the multi-module directories (examples/<d>/main.nim).
# The multi-module case is not decoration: `aowlc.js` mangled an own-module type
# to `Derived_0_` where every cross-module use said `Derived_0_cty4i727z`, and no
# single-module gate could see it — there every use was unsuffixed too.
mapfile -t SRCS < <({ ls examples/*.nim; ls -d examples/*/ 2>/dev/null | while read -r d; do
  [ -f "$d/main.nim" ] && echo "$d/main.nim"; done; } | sort)
PLAN=${#SRCS[@]}
[ "$PLAN" -gt 0 ] || { echo "twoprinters: no examples/*.nim found"; exit 1; }

ran=0; both=0; jsbad=(); natbad=(); skipped=(); knownjs=(); stale=()
for src in "${SRCS[@]}"; do
  # A multi-module fixture is named for its DIRECTORY and keeps its own entry
  # file name; a single-module one is copied to `src.nim` (see below).
  if [ "$(basename "$src")" = main.nim ]; then
    name=$(basename "$(dirname "$src")"); entry=main.nim; pfx=main
  else
    name=$(basename "$src" .nim); entry=src.nim; pfx=src
  fi
  ran=$((ran+1))
  nc="$out/nc/$name"; rm -rf "$nc"; mkdir -p "$nc"
  # Reference and artifacts are SEPARATE runs, as in e2e.sh: `c -r` prints the
  # program's output, and a second `c --nimcache:` leaves the .c.nif behind.
  ref=$($LOCK "$NIM/bin/nimony" c -r "$src" 2>/dev/null); refrc=$?
  # Compile a copy named `src.nim`, so the program's OWN artifact is the one
  # whose basename starts with "src". Every fixture here is `e2e_*`, and nimony
  # derives the artifact prefix from the file name, so the obvious heuristic
  # (first three letters) matches most of the corpus at once.
  sdir="$out/src/$name"; rm -rf "$sdir"; mkdir -p "$sdir"
  if [ "$entry" = main.nim ]; then cp "$(dirname "$src")"/*.nim "$sdir/"
  else cp "$src" "$sdir/src.nim"; fi
  $LOCK "$NIM/bin/nimony" c --nimcache:"$nc" "$sdir/$entry" >/dev/null 2>&1
  # An empty or failed reference asserts nothing — the VACUOUS case e2e.sh
  # already documents. Skip rather than score "" against "".
  if [ "$refrc" -ne 0 ] || [ -z "$ref" ]; then [ "${DBG:-0}" = 1 ] && echo "  skip(ref) $name rc=$refrc"; skipped+=("$name"); continue; fi
  ref=$(printf '%s' "$ref" | tr -d '\r\000')

  own=""
  for d in "$nc"/*/ "$nc"/; do for cn in "$d$pfx"*.c.nif; do
    [ -f "$cn" ] && own="$cn"
  done; done
  # Fallback for a multi-module fixture whose entry artifact nimony did not name
  # after the entry FILE: nimony puts every module of a program in one nimcache
  # directory named after the entry module, so the .c.nif whose basename matches
  # its parent directory is the one carrying `main`.
  if [ -z "$own" ]; then
    for d in "$nc"/*/; do for cn in "$d"*.c.nif; do
      [ -f "$cn" ] || continue
      [ "$(basename "$cn" .c.nif)" = "$(basename "${d%/}")" ] && own="$cn"
    done; done
  fi
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
