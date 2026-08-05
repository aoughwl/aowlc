import std/syncio
type
  Colour = enum
    cRed = 1, cGreen = 4, cBlue = 9      # holes in the ordinals
  Flags = set[Colour]

proc name(c: Colour): string =
  case c
  of cRed: "red"
  of cGreen: "green"
  of cBlue: "blue"

for c in [cRed, cGreen, cBlue]:
  echo name(c) & "=" & $ord(c)

var f: Flags = {cRed, cBlue}
echo (cRed in f)
echo (cGreen in f)
f.incl cGreen
f.excl cRed
echo (cRed in f)
echo (cGreen in f)

# case over strings
proc kindOf(s: string): int =
  case s
  of "one": 1
  of "two", "three": 23
  else: -1
echo kindOf("one")
echo kindOf("three")
echo kindOf("nope")

# recursion + mutual recursion
proc isOdd(n: int): bool
proc isEven(n: int): bool =
  if n == 0: true else: isOdd(n - 1)
proc isOdd(n: int): bool =
  if n == 0: false else: isEven(n - 1)
echo isEven(10)
echo isOdd(7)

proc fib(n: int): int =
  if n < 2: n else: fib(n - 1) + fib(n - 2)
echo fib(20)

# openArray parameter, over both an array and a seq
proc total(xs: openArray[int]): int =
  result = 0
  for x in xs: result = result + x
var arr = [1, 2, 3, 4]
echo total(arr)
echo total(@[10, 20])

# varargs
proc joinAll(parts: varargs[string]): string =
  result = ""
  for p in parts: result = result & p & ";"
echo joinAll("a", "b", "c")

# a proc value called indirectly
proc double(x: int): int = x * 2
proc triple(x: int): int = x * 3
var fns: array[2, proc (x: int): int {.nimcall.}] = [double, triple]
echo fns[0](5)
echo fns[1](5)
