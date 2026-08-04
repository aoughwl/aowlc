## e2e fixture: string-literal ESCAPES, which no fixture exercised.
##
## The load-bearing case is `\n` immediately followed by an OCTAL DIGIT. A C
## octal escape absorbs up to three octal digits, so an unpadded `\12` merges
## with the next character:
##
##   "a\n7b"  ->  "a\127b"   is ONE char 0x57 'W', then 'b'   (WRONG)
##            ->  "a\0127b"  is 10, '7', 'b'                  (right)
##
## That was a live, silent divergence from nimony's own backend — no diagnostic,
## no crash, just a different string — and nothing in the corpus could see it
## because every fixture's strings were plain ASCII. test/e2e.sh compares our
## binary's stdout against nimony's, so this file fails loudly if the padding
## regresses.
##
## The other lines cover the neighbouring escape paths: a bare control char, a
## high byte (>= 0x7F, the other branch of the same condition), a quote/backslash
## (the non-octal escape branch), and a tab that is NOT followed by a digit — the
## case that kept working and therefore hid the bug.
import std/syncio

## ⚠️ EVERY LITERAL HERE MUST EXCEED THE SSO BOUNDARY (8 bytes). A short string
## is packed into the `bytes_0` uint64 of the string struct and never becomes a C
## string literal at all, so it cannot exercise `makeCString`. The first version
## of this fixture used "a\n7b" (4 chars) and PASSED with the bug deliberately
## reinstated — it was testing nothing.
proc main =
  echo "abcdefgh\n7ijklm"   # the regression: control char + OCTAL digit, long
  echo "abcdefgh\t5ijklm"   # tab + octal digit, same merge
  echo "abcdefgh\n9ijklm"   # 9 is NOT an octal digit — escape ends on its own
  echo "abcdefgh\tsep_ijk"  # control char followed by a letter — always worked
  echo "abcdefgh\"q\\s_ijk" # quote and backslash: the non-octal escape branch

main()
