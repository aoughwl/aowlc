## e2e fixture: float arithmetic and a case-RANGE arm, with results OBSERVABLE.
## mathf.nim stays import-free as a single-module fixture (see e2e_compute.nim).
## Float multiplication, float negation and the `of 10..20` arm were all compared
## empty-to-empty before this file existed.
import std/syncio

proc power(base: float, n: int): float =
  var r = 1.0
  var i = 0
  while i < n:
    r = r * base
    i = i + 1
  return r

proc classify(n: int): int =
  case n
  of 0: return 100
  of 1, 2, 3: return 200
  of 10..20: return 300
  else: return 999

proc absf(x: float): float =
  if x < 0.0: return -x
  return x

echo power(2.0, 10)
echo classify(15)
echo absf(-3.5)
