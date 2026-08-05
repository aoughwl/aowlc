import std/syncio
type
  Kind = enum kInt, kStr
  Node = object
    case kind: Kind
    of kInt: ival: int
    of kStr: sval: string
var a = Node(kind: kInt, ival: 42)
var b = Node(kind: kStr, sval: "hi")
echo a.ival
echo b.sval
echo (a.kind == kInt)
