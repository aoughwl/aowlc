import std/syncio
proc bump(x: int): int =
  result = x
  {.emit: "result_0 = result_0 + 1;".}
echo bump(41)
