## Shapes that only appear when features are COMBINED.
import std/syncio
type
  E = ref object of Exception
    code: int
  Kind = enum kNums, kText
  Payload = object
    case k: Kind
    of kNums: nums: seq[int]      # a seq INSIDE a variant branch
    of kText: text: string
  Base = ref object of RootObj
    id: int
  Impl = ref object of Base
    extra: seq[string]

# a variant holding a seq, copied
var p1 = Payload(k: kNums, nums: @[1, 2])
var p2 = p1
p2.nums.add 3
echo p1.nums.len
echo p2.nums.len
var p3 = Payload(k: kText, text: "hi")
echo p3.text
echo (p1 == Payload(k: kNums, nums: @[1, 2]))
echo (p1 == p2)

# (a `method` with a `{.raises.}` pragma SEGFAULTS nimony's binary — see
# methods_raises_blocked.nim)

# an exception crossing an iterator's consumer, with finally at both levels
var trace = ""
iterator upTo(n: int): int =
  var i = 0
  while i < n:
    yield i
    i = i + 1
proc boom(n: int) {.raises: E.} =
  if n == 2: raise E(msg: "at2", code: n)
proc consume(n: int): string =
  result = ""
  try:
    for v in upTo(n):
      try:
        boom(v)
        result = result & $v
      finally:
        trace = trace & "i"
  except E as e:
    result = result & "|" & e.msg
  finally:
    trace = trace & "O"
echo consume(4)
echo trace
