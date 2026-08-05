import std/syncio
proc classify(x: int): string =
  case x
  of 0: result = "zero"
  of 1, 2, 3: result = "small"
  of 4..9: result = "medium"
  else: result = "big"
for i in [0, 2, 5, 99]:
  echo classify(i)
var s = 0
var i = 0
while true:
  i = i + 1
  if i mod 2 == 0: continue
  if i > 9: break
  s = s + i
echo s
block outer:
  for a in 0..3:
    for b in 0..3:
      if a * b == 4: break outer
  echo "nope"
echo "done"
