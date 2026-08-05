import std/syncio
type Item = object
  name: string
  qty: int

# an iterator over a seq of objects, yielding objects
iterator each(xs: seq[Item]): Item =
  for x in xs:
    yield x

# an iterator with several yields in different branches
iterator classify(n: int): string =
  if n < 0:
    yield "neg"
    yield "small"
  elif n == 0:
    yield "zero"
  else:
    yield "pos"
    if n > 10:
      yield "big"

# an iterator that yields inside a while with an early break
iterator upTo(limit: int): int =
  var i = 0
  while true:
    if i >= limit: break
    yield i
    i = i + 1

# an iterator consuming another iterator
iterator doubled(limit: int): int =
  for v in upTo(limit):
    yield v * 2

var items = @[Item(name: "a", qty: 1), Item(name: "b", qty: 2)]
for it in each(items):
  echo it.name & "=" & $it.qty

for s in classify(-1): echo s
for s in classify(0): echo s
for s in classify(5): echo s
for s in classify(50): echo s

var acc = ""
for v in upTo(4): acc = acc & $v
echo acc

acc = ""
for v in doubled(4): acc = acc & $v & ","
echo acc

# a yielded object must be a COPY: mutating it must not reach the seq
for it in each(items):
  var local = it
  local.qty = 99
echo items[0].qty

# (an iterator is `.noSideEffect` in nimony, so it cannot write a global — a
# `finally` inside one has nothing observable to do, and the attempt is rejected
# with "use of global/thread-local variable in .noSideEffect context")

# an iterator used twice in one proc
proc twiceUsed(): string =
  result = ""
  for v in upTo(2): result = result & $v
  for v in upTo(3): result = result & $v
echo twiceUsed()
