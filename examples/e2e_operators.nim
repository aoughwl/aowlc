## User-defined operators must not be hijacked by the magic that handles the
## builtin of the same name — the `$` bug was exactly that.
import std/syncio
type
  Vec = object
    x: int
    y: int
  Grid = object
    cells: seq[int]

proc `+`(a, b: Vec): Vec = Vec(x: a.x + b.x, y: a.y + b.y)
proc `-`(a, b: Vec): Vec = Vec(x: a.x - b.x, y: a.y - b.y)
proc `*`(a: Vec; k: int): Vec = Vec(x: a.x * k, y: a.y * k)
proc `==`(a, b: Vec): bool = a.x == b.x and a.y == b.y
proc `<`(a, b: Vec): bool = (a.x * a.x + a.y * a.y) < (b.x * b.x + b.y * b.y)
proc `$`(v: Vec): string = "<" & $v.x & "," & $v.y & ">"
proc `[]`(g: Grid; i: int): int = g.cells[i] * 10
proc `[]=`(g: var Grid; i: int; v: int) = g.cells[i] = v + 1
proc len(g: Grid): int = g.cells.len

var a = Vec(x: 1, y: 2)
var b = Vec(x: 3, y: 4)
echo $(a + b)
echo $(b - a)
echo $(a * 3)
echo (a == Vec(x: 1, y: 2))
echo (a == b)
echo (a < b)
echo (b < a)

var g = Grid(cells: @[1, 2, 3])
echo g[0]          # the overload multiplies by 10
echo g[2]
g[1] = 5           # the overload adds 1
echo g[1]
echo g.len

# the builtins must still work on builtin types alongside the overloads
echo (1 + 2)
echo (3 == 3)
echo (1 < 2)
echo $(4)
var plain = @[9, 8]
echo plain[0]
plain[1] = 7
echo plain[1]
echo plain.len
