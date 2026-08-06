import std/syncio
type
  Colour = enum cRed, cGreen, cBlue

# an array indexed by an enum
var counts: array[Colour, int]
counts[cRed] = 10
counts[cGreen] = 20
counts[cBlue] = 30
echo counts[cRed]
echo counts[cBlue]
echo counts.len
var total = 0
for v in counts: total = total + v
echo total

# iterating the enum and indexing with it
var s = ""
for c in cRed .. cBlue:
  s = s & $counts[c] & ","
echo s

# (an enum WITH HOLES cannot index an array — nimony rejects it with
# "invalid array index type: Level", as Nim does)

# a proc-typed field, called through
type Handler = object
  name: string
  run: proc (x: int): int {.nimcall.}
proc double(x: int): int = x * 2
proc negate(x: int): int = 0 - x
var hs = @[Handler(name: "d", run: double), Handler(name: "n", run: negate)]
for h in hs:
  echo h.name & "=" & $h.run(21)

# a proc value in a local, reassigned
var f: proc (x: int): int {.nimcall.} = double
echo f(5)
f = negate
echo f(5)

# a generic object with a method-like proc
type Pair[T] = object
  a: T
  b: T
proc swapped[T](p: Pair[T]): Pair[T] = Pair[T](a: p.b, b: p.a)
var pi = Pair[int](a: 1, b: 2)
var ps = Pair[string](a: "x", b: "y")
echo swapped(pi).a
echo swapped(ps).a
