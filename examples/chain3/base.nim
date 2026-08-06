import std/syncio
var baseCounter* = 0
proc bump*(): int =
  baseCounter = baseCounter + 1
  result = baseCounter
echo "init base"
