## The speed claim rests on a tight scalar loop compiling to plain JS. This is
## here so the emitted shape can be inspected: no helper call should appear in
## the loop body.
import std/syncio
proc sumTo(n: int): int =
  result = 0
  var i = 0
  while i < n:
    result = result + i * 2 - 1
    i = i + 1
echo sumTo(1000)

proc fib(n: int): int =
  if n < 2: n else: fib(n - 1) + fib(n - 2)
echo fib(24)

proc dot(a, b: seq[int]): int =
  result = 0
  for i in 0 ..< a.len:
    result = result + a[i] * b[i]
var xs: seq[int] = @[]
var ys: seq[int] = @[]
for i in 0 ..< 100:
  xs.add i
  ys.add i * 2
echo dot(xs, ys)
