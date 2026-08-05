import std/syncio
var s: string
var b: bool
var f: float
var i: int
var c: char
var xs: seq[int]
var a1: array[3, int]
var a2: array[2, array[3, int]]
echo "[" & s & "]"
echo b
echo f
echo i
echo (c == '\0')
echo xs.len
echo a1.len
a1[1] = 7
echo a1[1]
a2[0][1] = 3
echo a2[0][1]
echo a2[1][1]
xs.add 5
echo xs.len
s.add 'q'
echo s

# var-param forwarding: a boxed param passed on as another var param
proc inner(x: var int) = x = x + 10
proc outer(y: var int) = inner(y)
var v = 1
outer(v)
echo v

proc grow(t: var seq[int]) = t.add t.len
proc grow2(t: var seq[int]) =
  grow(t)
  grow(t)
var g: seq[int]
grow2(g)
echo g.len
echo g[1]
