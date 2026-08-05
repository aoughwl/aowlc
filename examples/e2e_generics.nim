import std/syncio
type
  Box[T] = object
    v: T
  Duo[A, B] = object
    a: A
    b: B

proc get[T](b: Box[T]): T = b.v
proc mk[A, B](a: A; b: B): Duo[A, B] = Duo[A, B](a: a, b: b)
proc swapped[A, B](d: Duo[A, B]): Duo[B, A] = Duo[B, A](a: d.b, b: d.a)

var bi = Box[int](v: 5)
var bs = Box[string](v: "five")
echo get(bi)
echo get(bs)
var d = mk(1, "one")
echo d.a
echo d.b
var w = swapped(d)
echo w.a
echo w.b

proc countOf[T](xs: seq[T]): int =
  result = 0
  for x in xs: result = result + 1
echo countOf(@[3, 9, 4])
echo countOf(@["a", "zz", "m"])

# a generic over a generic
var nested = Box[Box[int]](v: Box[int](v: 7))
echo get(get(nested))
