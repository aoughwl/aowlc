## The mirror of value_semantics: a `ref object` must SHARE. Copying one would
## break identity — the same bug in the other direction, and just as silent.
import std/syncio
type
  R = ref object
    x: int
  Holder = object
    r: R
    tag: int

var a = R(x: 1)
var b = a
b.x = 99
echo a.x              # 99 — same object

proc bump(r: R) = r.x = r.x + 1
bump(a)
echo a.x              # 100 — the callee wrote through the reference
echo b.x

var rs: seq[R] = @[]
rs.add a
rs[0].x = 7
echo a.x              # 7 — adding to a seq must not have cloned it

# a value object HOLDING a ref: copying the object shares the ref
var h1 = Holder(r: a, tag: 1)
var h2 = h1
h2.tag = 2
h2.r.x = 55
echo h1.tag           # 1 — the value part was copied
echo h1.r.x           # 55 — the ref part was shared
echo (h1.r == h2.r)   # true — same reference

# a second, distinct ref is NOT confused with the first
var c = R(x: 1)
echo (c == a)
c.x = 5
echo a.x
