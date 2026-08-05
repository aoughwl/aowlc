import std/syncio
var a = "he"
var b = "llo"
var c = a & b
echo c
echo c.len
echo c[0]
echo c[1..3]
echo (c == "hello")
echo (a < b)
var d = ""
for ch in c:
  d.add ch
echo d
