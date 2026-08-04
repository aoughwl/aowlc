## e2e fixture: the integer paths of compute.nim, with their results OBSERVABLE.
##
## compute.nim itself must stay import-free — it is a SINGLE-MODULE fixture for
## test/test.js and test/single.sh, and pulling in std/syncio makes its emission
## span 4 modules, which is a different property than the one those lanes assert
## (verified: adding the import turns test.js from 24/24 to 21/24, gcc failing in
## the module-init function on a build that deliberately compiles one .c.nif).
##
## So the two lanes get two files. This one exists purely so test/e2e.sh has
## something to compare: with only silent fixtures it compared "" to "" and
## called it PASS — gcd, `mod`, the primality loop, collatz and the uint32
## shift/mask path had never had a single result checked against nimony.
import std/syncio

proc gcd(a, b: int): int =
  var x = a
  var y = b
  while y != 0:
    let t = y
    y = x mod y
    x = t
  return x

proc isPrime(n: int): bool =
  if n < 2: return false
  var i = 2
  while i * i <= n:
    if n mod i == 0: return false
    i = i + 1
  return true

proc collatz(n: int): int =
  var x = n
  var steps = 0
  while x != 1:
    if x mod 2 == 0:
      x = x div 2
    else:
      x = 3 * x + 1
    steps = steps + 1
  return steps

proc popcount(x: uint32): int =
  var v = x
  var c = 0
  while v != 0'u32:
    c = c + int(v and 1'u32)
    v = v shr 1'u32
  return c

echo gcd(48, 36)
echo isPrime(97)
echo collatz(27)
echo popcount(0xFFu32)
