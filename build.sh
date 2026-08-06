#!/usr/bin/env bash
# Build the nimony aowlc — post-hexer `.c.nif` → C. NIM = a nimony checkout.
# (The hand-written aowlc.js remains as the differential oracle / browser seed.)
set -e
# The machine-wide compile lock. Two `nimony c` runs at once corrupt each other's
# link through the shared `nimcache_static` — a CROSS-PROCESS hazard a private
# `--nimcache:` does not cover, because the static object is shared across
# caches. Unlocked, this gate's result depended on nobody else compiling at the
# same moment, and the damage surfaced as a failure attributed to aowlc.
LOCK="$HOME/.aowl/bin/nimlock"
[ -x "$LOCK" ] || LOCK=""
NIM="${NIM:-$HOME/nimony}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$ROOT/bin"
$LOCK "$NIM/bin/nimony" c -o:"$ROOT/bin/aowlc-native" \
  -p:"$NIM/src/lib" -p:"$NIM/src/nimony" -p:"$NIM/src/models" -p:"$NIM/src/gear2" \
  -p:"$ROOT/src" "$ROOT/src/aowlc_cli.nim"
echo "built $ROOT/bin/aowlc-native"
