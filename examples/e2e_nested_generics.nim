import std/syncio
proc wrap[T](x: T): seq[T] = @[x]
proc firstOf[T](xs: seq[T]): T = xs[0]
echo firstOf(wrap(42))
echo firstOf(wrap("hi"))
echo wrap(7).len
