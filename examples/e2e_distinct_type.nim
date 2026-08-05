import std/syncio
type Meters = distinct int
proc `+`(a, b: Meters): Meters = Meters(int(a) + int(b))
var d = Meters(5) + Meters(3)
echo int(d)
