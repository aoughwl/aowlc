## `in` / `contains` over containers uses `==` underneath, so it inherits the
## reference-vs-value hazard. A JS Set is reference-keyed too.
import std/syncio
import std/sets
type P = object
  x: int
  y: int

var ps = @[P(x: 1, y: 1), P(x: 2, y: 2)]
echo (P(x: 2, y: 2) in ps)      # a separately-built equal value
echo (P(x: 3, y: 3) in ps)

var ints = @[10, 20, 30]
echo (20 in ints)
echo (25 in ints)

var strs = @["a", "b"]
echo ("b" in strs)
echo ("z" in strs)

var tups = @[(1, "a"), (2, "b")]
echo ((2, "b") in tups)
echo ((3, "c") in tups)

# find over the same shapes
echo ints.find(20)
echo ints.find(25)
echo strs.find("b")

# a HashSet of strings and ints
var hs = initHashSet[string]()
hs.incl "one"
hs.incl "two"
echo hs.len
echo ("one" in hs)
echo ("three" in hs)
hs.excl "one"
echo ("one" in hs)
echo hs.len

var hi = initHashSet[int]()
hi.incl 5
hi.incl 5
echo hi.len
echo (5 in hi)
