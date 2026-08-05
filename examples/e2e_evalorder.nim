## Properties that are wrong SILENTLY when they are wrong: short-circuit
## evaluation, argument evaluation order, and what `result` holds on each path.
import std/syncio

var log = ""
proc note(c: char; v: bool): bool =
  log.add c
  result = v
proc noteI(c: char; v: int): int =
  log.add c
  result = v

# `and` must not evaluate its right side when the left is false
log = ""
discard (note('a', false) and note('b', true))
echo log                      # "a"

# `or` must not evaluate its right side when the left is true
log = ""
discard (note('c', true) or note('d', false))
echo log                      # "c"

# ...and must when it has to
log = ""
discard (note('e', true) and note('f', false))
echo log                      # "ef"

# short-circuit inside a loop condition
log = ""
var i = 0
while i < 2 and note('g', true):
  i = i + 1
echo log                      # "gg"
echo i

# arguments evaluate left to right
log = ""
proc two(a, b: int): int = a * 10 + b
echo two(noteI('1', 1), noteI('2', 2))
echo log                      # "12"

# an explicit early `return` wins over a later assignment to `result`
# (nimony will not let `result` be read before it is provably initialised, so
# every path here sets it first — that requirement is itself worth pinning)
proc early(n: int): int =
  result = 0
  if n > 0:
    return 5
  result = result + 1
echo early(1)
echo early(0)

proc implicitResult(n: int): string =
  result = ""
  if n > 0:
    result = "pos"
  elif n < 0:
    result = "neg"
  # falls through with result left at "" for 0
echo implicitResult(1)
echo implicitResult(-1)
echo "[" & implicitResult(0) & "]"

# result accumulated across a loop, with an early exit
proc firstOver(xs: seq[int]; lim: int): int =
  result = -1
  for x in xs:
    if x > lim:
      return x
    result = result - 1
echo firstOver(@[1, 2, 9, 3], 5)
echo firstOver(@[1, 2, 3], 5)

# nested if/else as an expression
proc sign(n: int): int =
  result = (if n > 0: 1 elif n < 0: -1 else: 0)
echo sign(7)
echo sign(-7)
echo sign(0)
