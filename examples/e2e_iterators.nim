import std/syncio
iterator evens(n: int): int =
  var i = 0
  while i < n:
    yield i
    i = i + 2
for e in evens(7):
  echo e
iterator pairsOf(s: seq[string]): (int, string) =
  var i = 0
  for x in s:
    yield (i, x)
    i = i + 1
for i, v in pairsOf(@["a", "b"]):
  echo $i & v
