import std/syncio
type
  Colour = enum cRed, cGreen, cBlue
  Pt = object
    x: int
    y: int
proc `$`(p: Pt): string = "(" & $p.x & "," & $p.y & ")"
echo $cGreen
echo $(ord(cBlue))
echo $3
echo $(-3)
echo $2.5
echo $"str"
echo $Pt(x: 1, y: 2)
var xs = @[1, 2, 3]
var s = ""
for i, v in xs:
  s = s & $i & "=" & $v & ";"
echo s
echo (cRed < cBlue)
echo (cBlue > cGreen)
var e = cGreen
case e
of cRed: echo "r"
of cGreen: echo "g"
of cBlue: echo "b"
