import std/syncio
type
  Item = object
    name: string
    qty: int

proc `$`(it: Item): string = it.name & "x" & $it.qty

var items: seq[Item] = @[]
for i in 0 ..< 6:
  items.add Item(name: "i" & $i, qty: i * i)
echo items.len
for it in items:
  echo $it

# mutate through the seq
items[2].qty = 99
echo items[2].qty

# a seq of seqs that grows past its initial capacity
var grid: seq[seq[int]] = @[]
for r in 0 ..< 4:
  var row: seq[int] = @[]
  for c in 0 ..< 4:
    row.add r * 4 + c
  grid.add row
var total = 0
for row in grid:
  for v in row:
    total = total + v
echo total
echo grid[3][3]

# string growth well past any small-string buffer
var s = ""
for i in 0 ..< 40:
  s.add "ab"
echo s.len
echo s[0]
echo s[79]

# generic proc over both
proc firstOf[T](xs: seq[T]; fallback: T): T =
  result = fallback
  if xs.len > 0: result = xs[0]
echo firstOf(@[7, 8], 0)
echo firstOf(@["p", "q"], "z")
var empty: seq[int] = @[]
echo firstOf(empty, -1)
