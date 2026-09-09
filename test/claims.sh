#!/usr/bin/env bash
# test/claims.sh — do the numbers in README.md still agree with the gates?
#
# The other scripts in this directory check the compiler. This one checks the
# PROSE, which is the only part of the repo that had a defect nothing could see:
# the README said twoprinters was 73/73 while the script printed 66/67, and said
# 77/77 beside single-all.sh, which prints 78/78. Both stood for commits.
#
# Cheap by default — it checks the DENOMINATORS (the corpus size, the prelude
# line count), which is what actually drifted both times. `--all` runs the real
# gates and takes as long as they do.
#
#   bash test/claims.sh            # seconds
#   bash test/claims.sh --all      # single-all + twoprinters + e2e-all
#   bash test/claims.sh --sweep    # numbers in README.md with no declared source
#
# Exit 0 clean, 1 a claim disagrees or CLAIMS.tsv drifted, 2 something could not
# be checked. It never edits a document: a number you did not measure is not
# yours to rewrite.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
exec python3 tools/claimcheck.py --label aowlc "$@"
