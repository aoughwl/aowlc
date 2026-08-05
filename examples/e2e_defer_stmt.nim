import std/syncio
proc f(x: int): int =
  defer: echo "cleanup"
  if x > 0:
    return x * 2
  echo "zero path"
  return 0
echo f(5)
echo f(0)
