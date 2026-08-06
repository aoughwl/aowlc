## An imported module that declares a method hierarchy AND an iterator, so the
## dispatcher/generator tables have to survive being built in one module and used
## in another.
type
  Shape* = ref object of RootObj
    id*: int
  Circle* = ref object of Shape
    r*: int
  Square* = ref object of Shape
    side*: int

method area*(s: Shape): int {.base.} = 0
method area*(c: Circle): int = 3 * c.r * c.r
method area*(q: Square): int = q.side * q.side

iterator steps*(n: int): int =
  var i = 0
  while i < n:
    yield i * i
    i = i + 1

iterator labelled*(n: int): (int, string) =
  var i = 0
  while i < n:
    yield (i, "s" & $i)
    i = i + 1

proc describe*(s: Shape): string = "#" & $s.id & ":" & $area(s)
