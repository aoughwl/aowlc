import std/syncio
type P = object
  a: int32
  b: int64
echo sizeof(int32)
echo sizeof(int64)
echo sizeof(char)
# (sizeof of an OBJECT needs a real layout model — aowlabi — so aowljs reports
# it and throws by name rather than answering `undefined`)
var x = 5
var p = addr x
p[] = 7
echo x
echo p[]
