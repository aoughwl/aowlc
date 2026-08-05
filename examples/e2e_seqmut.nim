import std/syncio
var xs = @[1, 2, 3, 4, 5]
echo xs.high
echo xs.len

# pop
var last = xs.pop()
echo last
echo xs.len

# setLen both ways
xs.setLen(2)
echo xs.len
echo xs[1]
xs.setLen(4)
echo xs.len
echo xs[3]

# del (swap-remove) and delete (shift)
var ys = @[10, 20, 30, 40]
ys.del(1)
echo ys.len
echo ys[1]
var zs = @[10, 20, 30, 40]
zs.delete(1)
echo zs.len
echo zs[1]
echo zs[2]

# (nimony has no seq `insert`, and no `countup`)

# newSeqOfCap then fill
var cap = newSeqOfCap[int](8)
echo cap.len
for i in 0 ..< 3: cap.add i * 7
echo cap.len
echo cap[2]

# string index assignment
var s = "abcd"
s[0] = 'X'
echo s
echo s[0]

# a non-zero-based array
var arr: array[1 .. 3, int]
arr[1] = 10
arr[2] = 20
arr[3] = 30
echo arr[1]
echo arr[3]
echo arr.len
var total = 0
for v in arr: total = total + v
echo total

# a stepped loop, spelled with countdown (which nimony does have)
var acc = ""
for i in countdown(8, 0, 2):
  acc = acc & $i
echo acc
