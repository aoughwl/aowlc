## Stress for the `defer` + `result` path: a routine with both needs its `result`
## at function scope AND its returns deferred past the finally.
import std/syncio
type E = ref object of Exception

# several returns, all of which must see the defer
proc pick(n: int): int =
  result = 0
  defer: result = result * 2
  if n == 1: return 10
  if n == 2: return 20
  result = 30
echo pick(1)
echo pick(2)
echo pick(3)

# a return from INSIDE a loop, with a defer
proc firstEven(xs: seq[int]): int =
  result = -1
  defer: result = result + 1000
  for x in xs:
    if x mod 2 == 0:
      return x
echo firstEven(@[1, 3, 4, 5])
echo firstEven(@[1, 3, 5])

# (TWO defers in one proc live in defer_two_blocked.nim — nimony emits C that
# does not compile for that shape, so it cannot be compared here.)

# defer plus an exception caught outside
proc raises(n: int): int {.raises: E.} =
  result = 0
  defer: result = result + 1
  if n > 0: raise E(msg: "x")
  result = 5
proc guard(n: int): string =
  result = "?"
  try:
    result = "v" & $raises(n)
  except E:
    result = "caught"
echo guard(0)
echo guard(1)

# a defer in a proc returning an object
type Box = object
  v: int
proc boxed(n: int): Box =
  result = Box(v: n)
  defer: result.v = result.v * 3
  if n == 0: return Box(v: 7)
echo boxed(2).v
echo boxed(0).v

# a defer in a void proc still runs
var log = ""
proc voidDefer(n: int) =
  defer: log = log & "D"
  if n > 0: return
  log = log & "B"
voidDefer(1)
voidDefer(0)
echo log

# ⚠️ A NESTED proc containing a `defer` CRASHES nimony — not a diagnostic, a
# compiler bug: "[Bug] expected ')', but got: (ret result.1)" out of
# derefs.nim trTry. The same program with the defer on the OUTER proc only
# compiles and runs, so it is specifically the defer in the inner routine.
# Filed to aowlsem; there is no way to assert that shape until it builds.
