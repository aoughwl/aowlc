## String building and comparison in a loop — the other hot shape, and the one
## where a byte-string representation could cost.
import std/syncio
proc build(n: int): string =
  result = ""
  var i = 0
  while i < n:
    result.add 'x'
    i = i + 1
proc countChar(s: string; c: char): int =
  result = 0
  for ch in s:
    if ch == c: result = result + 1
var s = build(200000)
echo s.len
echo countChar(s, 'x')
var joined = ""
for i in 0 ..< 2000:
  joined = joined & "ab"
echo joined.len
