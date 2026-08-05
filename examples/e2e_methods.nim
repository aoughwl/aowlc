import std/syncio
type
  Shape = ref object of RootObj
    id: int
  Circle = ref object of Shape
    r: int
  Unit = ref object of Circle          # three deep, no override of its own
    tag: string
  Square = ref object of Shape
    side: int

method area(s: Shape): int {.base.} = 0
method area(c: Circle): int = 3 * c.r * c.r
method area(q: Square): int = q.side * q.side

method describe(s: Shape; prefix: string): string {.base.} =
  prefix & "shape#" & $s.id
method describe(q: Square; prefix: string): string =
  prefix & "square#" & $q.id & " side=" & $q.side

var shapes: seq[Shape] = @[]
shapes.add Shape(id: 1)
shapes.add Circle(id: 2, r: 3)
shapes.add Square(id: 3, side: 4)
shapes.add Unit(id: 4, r: 2, tag: "u")   # inherits Circle's area
for s in shapes:
  echo area(s)
  echo describe(s, "> ")

# dispatch through a base-typed binding, not just a seq element
var one: Shape = Square(id: 9, side: 5)
echo area(one)
echo describe(one, "! ")

# a method on a plain (non-ref) object
type
  Box = object of RootObj
    w: int
  Tall = object of Box
    h: int
method vol(b: Box): int {.base.} = b.w
method vol(t: Tall): int = t.w * t.h
var bx = Box(w: 3)
var tl = Tall(w: 3, h: 5)
echo vol(bx)
echo vol(tl)
