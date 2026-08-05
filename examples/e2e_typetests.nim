import std/syncio
type
  Base = ref object of RootObj
    id: int
  Mid = ref object of Base
    m: int
  Leaf = ref object of Mid
    l: int
  Other = ref object of Base
    o: int

## ⚠️ Every `of` below is ECHOED, never used as a condition. nimony miscompiles
## `of` on any other consumption path: `echo (one of Mid)` prints true while
## `if one of Mid` takes the else branch and `let t = one of Mid` binds false —
## the same expression, different answers depending on how it is read. Writing
## this fixture the natural way (an if/elif chain over the subtypes) would
## therefore be comparing aowljs against a wrong oracle: aowljs answers correctly
## in all of those forms and nimony does not. Filed to aowlsem. What is below is
## the form the two agree on, so it tests the backend and not the defect.
var xs: seq[Base] = @[]
xs.add Base(id: 0)
xs.add Mid(id: 1, m: 1)
xs.add Leaf(id: 2, m: 2, l: 2)
xs.add Other(id: 3, o: 3)
for b in xs:
  echo $b.id & ":" & $(b of Leaf) & $(b of Mid) & $(b of Other)

# `of` against an ancestor must be true for a descendant
var lf = Leaf(id: 9, m: 9, l: 9)
echo (lf of Leaf)
echo (lf of Mid)
echo (lf of Base)
echo (lf of Other)

# base fields are reachable from a derived value
echo lf.id
echo lf.m
echo lf.l
lf.id = 42
echo lf.id

# a template
template twice(x: int): int = x * 2
echo twice(5)
echo twice(twice(2))

template clampLow(x, lo: int): int = (if x < lo: lo else: x)
echo clampLow(3, 5)
echo clampLow(9, 5)

# (nimony does not have: an `untyped` template param called as a routine, or a
# converter to a builtin int — `cannot attach converter to type int64`)

# when / defined
when defined(nimony):
  echo "nimony"
else:
  echo "other"
const Flag = true
when Flag:
  echo "flag on"
