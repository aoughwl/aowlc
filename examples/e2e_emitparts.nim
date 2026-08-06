import std/syncio
proc addTwo(x: int): int =
  result = x
  {.emit: ["result_0 = result_0 + ", 2, ";"].}
echo addTwo(40)
