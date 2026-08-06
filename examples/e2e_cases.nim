import std/syncio
type
  Kind = enum kA, kB, kC
  Node = object
    case k: Kind
    of kA: a: int
    of kB: b: string
    of kC: discard

# case as an EXPRESSION, with ranges, lists and else
proc bucket(n: int): string =
  result = case n
           of 0: "zero"
           of 1, 2, 3: "few"
           of 4 .. 9: "several"
           of 10 .. 99: "many"
           else: "lots"
for n in [0, 2, 7, 42, 500]:
  echo bucket(n)

# case expression over an enum, exhaustive (no else)
proc label(k: Kind): string =
  result = case k
           of kA: "A"
           of kB: "B"
           of kC: "C"
for k in [kA, kB, kC]:
  echo label(k)

# case over a char with ranges, as an expression
proc kindOfChar(c: char): int =
  result = case c
           of '0' .. '9': 1
           of 'a' .. 'z', 'A' .. 'Z': 2
           else: 0
for c in "7x!":
  echo kindOfChar(c)

# case as a STATEMENT with a discard branch
proc describe(n: Node): string =
  result = ""
  case n.k
  of kA: result = "a" & $n.a
  of kB: result = "b" & n.b
  of kC: discard
  result = "[" & result & "]"
echo describe(Node(k: kA, a: 1))
echo describe(Node(k: kB, b: "x"))
echo describe(Node(k: kC))

# reassigning a whole variant switches the active branch
var v = Node(k: kA, a: 5)
echo v.a
v = Node(k: kB, b: "now")
echo v.b
echo (v.k == kB)

# nested case
proc grid(a, b: int): string =
  result = case a
           of 0:
             case b
             of 0: "origin"
             else: "yaxis"
           else:
             case b
             of 0: "xaxis"
             else: "plane"
echo grid(0, 0)
echo grid(0, 1)
echo grid(1, 0)
echo grid(1, 1)

# case over a string with a list and else
proc route(s: string): int =
  case s
  of "get", "head": 1
  of "post": 2
  else: 0
echo route("get")
echo route("head")
echo route("post")
echo route("trace")
