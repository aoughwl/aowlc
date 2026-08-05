import std/syncio
type Pair = tuple[a: int, b: string]
proc mk(x: int): Pair = (a: x, b: "v")
var p = mk(7)
echo p.a
echo p.b
var q: (int, int) = (1, 2)
echo q[0]
echo q[1]
let (m, n) = q
echo m + n
