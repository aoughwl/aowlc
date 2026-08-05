## Unwinding PATHS. `finally` has to run on the ordinary path, the `return` path
## and the exception path, and an exception has to travel through frames that do
## not catch it.
import std/syncio
type E = ref object of Exception
  code: int

var trace = ""

proc boom(n: int) {.raises: E.} =
  trace.add "b"
  if n > 0: raise E(msg: "n=" & $n, code: n)

proc middle(n: int) {.raises: E.} =      # does NOT catch: must let it through
  trace.add "m"
  try:
    boom(n)
  finally:
    trace.add "M"

proc outer(n: int): string =
  trace = ""
  result = "?"
  try:
    middle(n)
    result = "ok"
  except E as e:
    result = "caught:" & e.msg & ":" & $e.code
  finally:
    trace.add "O"
  result = result & "|" & trace

echo outer(0)
echo outer(3)

# finally runs on the `return` path too
proc withReturn(n: int): string =
  trace = ""
  try:
    if n > 0:
      trace.add "r"
      return "early|" & trace & "?"
    trace.add "s"
  finally:
    trace.add "F"
  result = "late|" & trace
echo withReturn(1)
echo withReturn(0)

# finally runs when a loop BREAKS out of the try
proc withBreak(): string =
  trace = ""
  for i in 0 .. 3:
    try:
      trace.add "l"
      if i == 2: break
    finally:
      trace.add "f"
  result = trace
echo withBreak()

# an exception thrown inside a loop leaves the loop
proc inLoop(): string =
  trace = ""
  result = ""
  try:
    for i in 0 .. 3:
      trace.add "i"
      boom(if i == 2: 9 else: 0)
  except E as e:
    result = "stopped@" & e.msg
  result = result & "|" & trace
echo inLoop()
