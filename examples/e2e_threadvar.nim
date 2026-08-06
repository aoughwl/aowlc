import std/syncio
var counter {.threadvar.}: int
proc bump(): int =
  counter = counter + 1
  result = counter
echo bump()
echo bump()
echo counter
