import std/syncio
proc bump(x: var int) = x = x + 1
var v = 1
bump v
bump v
echo v
proc fill(s: var seq[int]; n: int) =
  for i in 0..<n: s.add i * i
var s: seq[int] = @[]
fill(s, 4)
for x in s: echo x
type P = object
  a: int
proc setA(p: var P; n: int) = p.a = n
var p = P(a: 0)
setA(p, 9)
echo p.a
var grid: array[2, array[3, int]]
grid[1][2] = 5
echo grid[1][2]
echo grid[0][0]
