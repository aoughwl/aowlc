import std/syncio

# explicit toOpenArray slices
proc total(xs: openArray[int]): int =
  result = 0
  for x in xs: result = result + x
var arr = [1, 2, 3, 4, 5]
echo total(arr)
echo total(toOpenArray(arr, 1, 3))
var sq = @[10, 20, 30, 40]
echo total(sq)
echo total(toOpenArray(sq, 0, 1))
echo total(toOpenArray(sq, 2, 3))

# openArray of strings, and its len/indexing inside the callee
proc joinAll(parts: openArray[string]): string =
  result = ""
  for i in 0 ..< parts.len:
    result = result & parts[i] & "|"
echo joinAll(["a", "b"])
echo joinAll(@["c", "d", "e"])

# varargs with zero, one and many
proc tally(xs: varargs[int]): int =
  result = 0
  for x in xs: result = result + x
echo tally()
echo tally(1)
echo tally(1, 2, 3)

# sink and lent parameters
proc consume(s: sink string): string =
  result = s & "!"
echo consume("gone")
proc borrow(s: lent string): int = s.len
var held = "held"
echo borrow(held)
echo held

# a cursor local
proc firstOf(xs: seq[string]): string =
  result = ""
  if xs.len > 0:
    let c {.cursor.} = xs[0]
    result = c & "?"
echo firstOf(@["p", "q"])

# casts between integer widths
var big = 300
echo cast[uint8](big)
echo cast[int8](big)
var neg = -1
echo cast[uint8](neg)
echo cast[uint16](neg)
