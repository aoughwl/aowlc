## Structural equality. nimony compares objects, tuples, arrays and seqs by
## VALUE; JS `===` on those compares references. Two separately-built equal
## values must compare equal.
import std/syncio
type
  P = object
    x: int
    y: int
  Kind = enum kA, kB
  V = object
    case k: Kind
    of kA: a: int
    of kB: b: string

var p1 = P(x: 1, y: 2)
var p2 = P(x: 1, y: 2)
var p3 = P(x: 9, y: 2)
echo (p1 == p2)          # true — separately built, equal fields
echo (p1 == p3)
echo (p1 != p3)

var t1 = (1, "a")
var t2 = (1, "a")
var t3 = (2, "a")
echo (t1 == t2)
echo (t1 == t3)

var a1 = [1, 2, 3]
var a2 = [1, 2, 3]
var a3 = [1, 2, 4]
echo (a1 == a2)
echo (a1 == a3)

var s1 = @[1, 2]
var s2 = @[1, 2]
var s3 = @[1, 3]
echo (s1 == s2)
echo (s1 == s3)

var st1 = "abc"
var st2 = "ab" & "c"
echo (st1 == st2)

# nested: an object holding a seq
type Holder = object
  items: seq[int]
  tag: string
var h1 = Holder(items: @[1, 2], tag: "t")
var h2 = Holder(items: @[1, 2], tag: "t")
var h3 = Holder(items: @[1, 3], tag: "t")
echo (h1 == h2)
echo (h1 == h3)

# variants compare by discriminator and the active branch
var v1 = V(k: kA, a: 5)
var v2 = V(k: kA, a: 5)
var v3 = V(k: kA, a: 6)
var v4 = V(k: kB, b: "s")
echo (v1 == v2)
echo (v1 == v3)
echo (v1 == v4)

# equality inside a container search
var ps = @[P(x: 1, y: 1), P(x: 2, y: 2)]
var found = -1
for i in 0 ..< ps.len:
  if ps[i] == P(x: 2, y: 2): found = i
echo found
