import std/syncio
# high/low over ordinal types
type Suit = enum sClub, sDiamond, sHeart, sSpade
echo ord(high(Suit))
echo ord(low(Suit))
echo high(int8)
echo low(int8)
echo high(uint8)

# for over an enum range
var names = ""
for s in low(Suit) .. high(Suit):
  names = names & $s & " "
echo names

# swap
var a = 1
var b = 2
swap(a, b)
echo a
echo b
var s1 = "one"
var s2 = "two"
swap(s1, s2)
echo s1
echo s2

# inc/dec with and without a step
var n = 10
inc n
echo n
inc n, 5
echo n
dec n
echo n
dec n, 3
echo n

# nested tuples
var t = (1, (2, 3))
echo t[0]
echo t[1][0]
echo t[1][1]
type Named = tuple[k: string, v: tuple[lo: int, hi: int]]
var nt: Named = (k: "range", v: (lo: 5, hi: 9))
echo nt.k
echo nt.v.lo
echo nt.v.hi

# an object with an array field, copied
type Board = object
  cells: array[3, int]
  turn: int
var b1 = Board(cells: [1, 2, 3], turn: 0)
var b2 = b1
b2.cells[1] = 99
b2.turn = 1
echo b1.cells[1]
echo b2.cells[1]
echo b1.turn
echo b2.turn

# case over a char with ranges and else
proc classify(c: char): string =
  case c
  of 'a'..'z': result = "lower"
  of 'A'..'Z': result = "upper"
  of '0'..'9': result = "digit"
  else: result = "other"
for c in "aQ7!":
  echo classify(c)

# deeper recursion than a toy
proc sumTo(k: int): int =
  if k <= 0: result = 0
  else: result = k + sumTo(k - 1)
echo sumTo(500)
