## The multi-module case. Everything the emitter accumulates in module-global
## tables — the method dispatchers and their inheritance chain, which symbols are
## generators — is built while emitting ONE module and consumed while emitting
## another. In particular `Tri` below is a new subtype of a base whose methods
## live in the other module, so the dispatcher emitted last has to be the one
## that binds.
import std/syncio
import shapes

type Tri* = ref object of Shape     # a NEW subtype, declared in the OTHER module
  b*: int
  h*: int
method area*(t: Tri): int = t.b * t.h div 2

var xs: seq[Shape] = @[]
xs.add Shape(id: 0)
xs.add Circle(id: 1, r: 2)
xs.add Square(id: 2, side: 3)
xs.add Tri(id: 3, b: 4, h: 5)
for s in xs:
  echo describe(s)

for v in steps(4):
  echo v
for i, name in labelled(3):
  echo $i & name
