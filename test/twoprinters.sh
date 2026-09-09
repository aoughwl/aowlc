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
# WHAT IT COSTS, AND WHY THAT MATTERS. This is the load-bearing gate for the
# backend, and it used to take ~15 minutes, so every session ran it ONCE, at
# the end, and shipped. Measured per fixture: two `nimony c` compiles at ~9-18s
# each, then ~3s for both printers together. Nimony's answer is the ORACLE --
# it does not change when aowlc changes -- and it was 85% of the run. Three
# things bring that down without checking any less:
#
#   1. The oracle is CACHED across runs, under nimcache/twoprinters/, keyed on
#      the fixture's sources AND the toolchain (every ~/nimony/bin/*.exe by
#      size+mtime, and every file under ~/nimony/lib by path+size+mtime). A
#      nimony rebuild or a lib edit misses the cache; an aowlc edit hits it.
#      Both printers ALWAYS run. NOCACHE=1 bypasses it; the summary says how
#      many oracle results came from the cache, so a run can be read.
#   2. ONE nimony compile per fixture, not two: `c -r --nimcache:` both runs
#      the program and leaves the .c.nif behind. A program's output does not
#      depend on the name of the file it was compiled from -- the one fixture
#      that looks at its own name, e2e_osparams, prints a boolean.
#   3. Fixtures run in PARALLEL (J=, default nproc capped at 8). Nimony compiles
#      still serialise on the machine-wide lock; the printer half -- node, two
#      gcc links, two runs -- is what overlaps.
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
CACHE="${TWOPRINTERS_CACHE:-$root/nimcache/twoprinters}"
J="${J:-$(nproc 2>/dev/null || echo 4)}"; [ "$J" -gt 8 ] && J=8

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
mkdir -p "$out/res" "$CACHE"
# Single-module fixtures AND the multi-module directories (examples/<d>/main.nim).
# The multi-module case is not decoration: `aowlc.js` mangled an own-module type
# to `Derived_0_` where every cross-module use said `Derived_0_cty4i727z`, and no
# single-module gate could see it — there every use was unsuffixed too.
mapfile -t SRCS < <({ ls examples/*.nim; ls -d examples/*/ 2>/dev/null | while read -r d; do
  [ -f "$d/main.nim" ] && echo "$d/main.nim"; done; } | sort)
PLAN=${#SRCS[@]}
[ "$PLAN" -gt 0 ] || { echo "twoprinters: no examples/*.nim found"; exit 1; }

# ONLY=<substring> narrows the run while ITERATING on one fixture. A narrowed
# run is NOT the gate and says so twice -- once here, once in the summary --
# because a green "3/3 agree" is otherwise indistinguishable from a green full
# run, and this file exists to stop exactly that kind of mistake.
PARTIAL=""
if [ -n "${ONLY:-}" ]; then
  mapfile -t SRCS < <(printf '%s\n' "${SRCS[@]}" | grep -- "$ONLY")
  PLAN=${#SRCS[@]}
  [ "$PLAN" -gt 0 ] || { echo "twoprinters: ONLY=$ONLY matched no example"; exit 1; }
  PARTIAL="ONLY=$ONLY"
  echo "twoprinters: PARTIAL RUN -- ONLY=$ONLY selected $PLAN of the corpus. NOT the gate."
fi

# The toolchain half of the oracle cache key. Computed once: the compiler
# binaries and the library they compile against, by identity rather than by
# content -- hashing 12MB of executables per run would cost more than it saves,
# and a rebuilt nimony changes its mtime.
TOOLKEY=$( { ls -l --time-style=+%s "$NIM"/bin/*.exe "$NIM"/bin/nimony 2>/dev/null;
             find "$NIM/lib" -type f -printf '%p %s %T@\n' 2>/dev/null | sort; } | sha256sum | cut -c1-16)
export LOCK NIM AOWLC CACHE out root TOOLKEY

one() {
  local src=$1 name entry pfx res
  # A multi-module fixture is named for its DIRECTORY and keeps its own entry
  # file name; a single-module one is copied to `src.nim` (see below).
  if [ "$(basename "$src")" = main.nim ]; then
    name=$(basename "$(dirname "$src")"); entry=main.nim; pfx=main
  else
    name=$(basename "$src" .nim); entry=src.nim; pfx=src
  fi
  res="$out/res/$name"; mkdir -p "$res"

  # --- the oracle: nimony's own output, and the .c.nif it lowered to ---------
  local key cdir nc ref refrc from=fresh
  if [ "$entry" = main.nim ]; then
    key=$(cat "$(dirname "$src")"/*.nim | sha256sum | cut -c1-16)
  else
    key=$(sha256sum < "$src" | cut -c1-16)
  fi
  key="$key-$TOOLKEY"
  cdir="$CACHE/$name"
  if [ "${NOCACHE:-0}" != 1 ] && [ -f "$cdir/key" ] && [ "$(cat "$cdir/key")" = "$key" ]; then
    nc="$cdir/nc"; ref=$(cat "$cdir/ref"); refrc=$(cat "$cdir/refrc"); from=cached
  else
    nc="$out/nc/$name"; rm -rf "$nc"; mkdir -p "$nc"
    # Compile a copy named `src.nim`, so the program's OWN artifact is the one
    # whose basename starts with "src". Every fixture here is `e2e_*`, and nimony
    # derives the artifact prefix from the file name, so the obvious heuristic
    # (first three letters) matches most of the corpus at once.
    local sdir="$out/src/$name"; rm -rf "$sdir"; mkdir -p "$sdir"
    if [ "$entry" = main.nim ]; then cp "$(dirname "$src")"/*.nim "$sdir/"
    else cp "$src" "$sdir/src.nim"; fi
    ref=$($LOCK "$NIM/bin/nimony" c -r --nimcache:"$nc" "$sdir/$entry" 2>/dev/null); refrc=$?
    ref=$(printf '%s' "$ref" | tr -d '\r\000')
    # Keep ONLY the .c.nif: the oracle is the IR plus the answer, not nimony's
    # own objects and binary. Written whole, then renamed, so a run killed
    # half-way cannot leave a key beside a partial artifact.
    local tmp="$CACHE/.$name.$$" d cn
    rm -rf "$tmp"; mkdir -p "$tmp/nc"
    for d in "$nc"/*/; do
      [ -d "$d" ] || continue
      mkdir -p "$tmp/nc/$(basename "$d")"
      for cn in "$d"*.c.nif; do [ -f "$cn" ] && cp "$cn" "$tmp/nc/$(basename "$d")/"; done
    done
    printf '%s' "$ref" > "$tmp/ref"; echo "$refrc" > "$tmp/refrc"; echo "$key" > "$tmp/key"
    rm -rf "$cdir"; mv "$tmp" "$cdir"
  fi
  echo "$from" > "$res/from"
  # An empty or failed reference asserts nothing — the VACUOUS case e2e.sh
  # already documents. Skip rather than score "" against "".
  if [ "$refrc" -ne 0 ] || [ -z "$ref" ]; then
    [ "${DBG:-0}" = 1 ] && echo "  skip(ref) $name rc=$refrc"
    echo "ref rc=$refrc" > "$res/skip"; return
  fi

  local own="" d cn
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
  if [ -z "$own" ]; then
    [ "${DBG:-0}" = 1 ] && echo "  skip(own) $name"
    echo "no own artifact" > "$res/skip"; return
  fi
  printf '%s' "$ref" > "$res/ref"

  # the JS printer, through the driver that ships it. AOWLC_TMP keeps its
  # scratch under ours, so parallel jobs cannot share a temp directory.
  local jtmp="$out/js/$name"; mkdir -p "$jtmp"
  AOWLC_TMP="$jtmp" timeout 200 node bin/aowlc run "$own" 2>/dev/null | grep -av '^aowlc: ' | tr -d '\r\000' > "$res/js"

  # the nimony printer: emit every module, link, run
  local cdir2="$out/c/$name" b; rm -rf "$cdir2"; mkdir -p "$cdir2"
  for d in "$nc"/*/; do for cn in "$d"*.c.nif; do
    [ -f "$cn" ] || continue; b=$(basename "$cn" .c.nif)
    "$AOWLC" "$cn" > "$cdir2/$b.c" 2>/dev/null
  done; done
  : > "$res/nat"
  if gcc "$cdir2"/*.c -o "$cdir2/prog" -lm 2>/dev/null; then
    "$cdir2/prog" 2>/dev/null | tr -d '\r\000' > "$res/nat"
  fi
  [ "${DBG:-0}" = 1 ] && echo "  done  $name ($from)"
  return 0
}
export -f one

t0=$(date +%s)
printf '%s\n' "${SRCS[@]}" | xargs -P "$J" -I{} bash -c 'one "$1"' _ {}
elapsed=$(( $(date +%s) - t0 ))

ran=0; both=0; cached=0; jsbad=(); natbad=(); skipped=(); knownjs=(); stale=()
for src in "${SRCS[@]}"; do
  if [ "$(basename "$src")" = main.nim ]; then name=$(basename "$(dirname "$src")")
  else name=$(basename "$src" .nim); fi
  res="$out/res/$name"; ran=$((ran+1))
  [ "$(cat "$res/from" 2>/dev/null)" = cached ] && cached=$((cached+1))
  if [ -f "$res/skip" ] || [ ! -f "$res/ref" ]; then skipped+=("$name"); continue; fi
  ref=$(cat "$res/ref"); jsgot=$(cat "$res/js"); natgot=$(cat "$res/nat")

  jsok=1
  if [ "$jsgot" != "$ref" ]; then
    jsok=0
    if isKnownJs "$name"; then knownjs+=("$name")
    else jsbad+=("$name"); fi
  elif isKnownJs "$name"; then
    stale+=("$name")
  fi
  [ "$natgot" != "$ref" ] && natbad+=("$name")
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
echo "  ${elapsed}s wall, J=$J, $cached/$ran oracle results from the cache ($CACHE)"
[ -n "$PARTIAL" ] && echo "  PARTIAL RUN ($PARTIAL) -- this is NOT the gate; run without ONLY= to gate."
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
