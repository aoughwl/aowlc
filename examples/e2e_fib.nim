## e2e fixture: recursion and an accumulating loop, with results OBSERVABLE.
## fib.nim stays import-free as a single-module fixture (see e2e_compute.nim for
## why the two are separate files). Without this, test/e2e.sh asserted only that
## recursion COMPILED — never that it computed.
import std/syncio

proc fib(n: int): int =
  if n < 2: return n
  return fib(n - 1) + fib(n - 2)

proc sumTo(n: int): int =
  var s = 0
  var i = 0
  while i <= n:
    s = s + i
    i = i + 1
  return s

echo fib(10)
echo sumTo(100)
