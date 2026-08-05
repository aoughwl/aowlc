import std/syncio
type Color = enum red, green, blue
var s = {red, blue}
echo (red in s)
echo (green in s)
var s2 = s + {green}
echo card(s2)
