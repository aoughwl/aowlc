## Shadowing and scoping. The emitter renames every symbol through one global
## table, so two different symbols that share a source name must NOT collide, and
## the inner one must win where the source says it does.
import std/syncio

var x = "global"
let n = 100

proc usesGlobal(): string = x & "/" & $n

proc shadows(): string =
  var x = "local"          # shadows the global
  let n = 1                # shadows the global
  result = x & "/" & $n

proc paramShadows(x: string; n: int): string =
  result = x & "/" & $n

echo usesGlobal()
echo shadows()
echo paramShadows("param", 7)
echo usesGlobal()          # the global must be untouched

proc blockShadows(): string =
  var v = "outer"
  result = v
  block:
    var v = "inner"
    result = result & "/" & v
  result = result & "/" & v

echo blockShadows()

proc loopShadows(): string =
  result = ""
  var i = 99
  for i in 0 .. 2:         # the loop variable shadows the local
    result = result & $i
  result = result & "/" & $i
echo loopShadows()

# a proc and a variable with the same source name
proc value(): int = 42
var valueVar = value()
echo valueVar

# nested procs each with their own `result`
proc outerR(a: int): string =
  proc innerR(b: int): string =
    result = "i" & $b
  result = "o" & $a & innerR(a + 1)
echo outerR(1)

# a field with the same name as a local
type Holder = object
  count: int
proc useField(): int =
  var count = 5
  var h = Holder(count: 9)
  result = count + h.count
echo useField()

# two different types with the same field name
type A = object
  v: int
type B = object
  v: string
var av = A(v: 3)
var bv = B(v: "three")
echo av.v
echo bv.v
