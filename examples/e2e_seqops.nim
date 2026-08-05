import std/syncio
var xs = @[1, 2, 3, 4, 5]
echo xs.len
echo xs[0]
echo xs[xs.len - 1]
echo xs[1 .. 3].len
var ys = xs[1 .. 3]
echo ys[0]
echo ys[2]
xs[2] = 30
echo xs[2]

# high/low and reverse iteration
var total = 0
for i in countdown(xs.len - 1, 0):
  total = total * 10 + xs[i]
echo total

# a seq of strings built up
var names: seq[string] = @[]
for i in 0 ..< 4:
  names.add "n" & $i
var joined = ""
for n in names:
  joined = joined & n & ","
echo joined
echo names.len

# nested seq mutation through the index
var grid: seq[seq[int]] = @[]
for r in 0 ..< 3:
  var row: seq[int] = @[]
  for c in 0 ..< 3:
    row.add 0
  grid.add row
grid[1][1] = 5
echo grid[1][1]
echo grid[0][0]
echo grid[2][2]

# string indexing and slicing
var str = "abcdefgh"
echo str[0]
echo str[7]
echo str[2 .. 4]
echo str.len
var built = ""
for i in countdown(str.len - 1, 0):
  built.add str[i]
echo built
