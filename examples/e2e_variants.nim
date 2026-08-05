import std/syncio
type
  Kind = enum kNone, kInt, kPair, kText
  Node = object
    tag: int
    case kind: Kind
    of kNone: discard
    of kInt: i: int
    of kPair:
      a: int
      b: int
    of kText: s: string

proc show(n: Node): string =
  case n.kind
  of kNone: result = "none"
  of kInt: result = "int " & $n.i
  of kPair: result = "pair " & $n.a & "/" & $n.b
  of kText: result = "text " & n.s
  result = $n.tag & ":" & result

var ns: seq[Node] = @[]
ns.add Node(tag: 0, kind: kNone)
ns.add Node(tag: 1, kind: kInt, i: 42)
ns.add Node(tag: 2, kind: kPair, a: 3, b: 4)
ns.add Node(tag: 3, kind: kText, s: "hi")
for n in ns:
  echo show(n)

# distinct types
type Meters = distinct int
proc `+`(a, b: Meters): Meters {.borrow.}
proc `$`(m: Meters): string = $int(m) & "m"
var d1 = Meters(3)
var d2 = Meters(4)
echo $(d1 + d2)
echo int(d1) * 2

# const and compile-time values
const Limit = 10
const Name = "lim"
const Doubled = Limit * 2
echo Limit
echo Name
echo Doubled
var arr: array[Limit, int]
echo arr.len
