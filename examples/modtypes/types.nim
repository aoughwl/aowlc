## Everything a module can export that another module has to agree with: an enum
## with explicit ordinals, an object type, an exception type, a mutable global, a
## const, and procs over all of them.
import std/syncio
type
  Level* = enum lLow = 1, lMid = 5, lHigh = 9
  Cfg* = object
    name*: string
    lvl*: Level
  Failure* = ref object of Exception
    code*: int
var registry*: seq[Cfg] = @[]
const Version* = "1.4"
proc register*(c: Cfg) = registry.add c
proc mayFail*(n: int) {.raises: Failure.} =
  if n > 0: raise Failure(msg: "bad", code: n)
proc levelOf*(c: Cfg): int = ord(c.lvl)
