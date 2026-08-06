import std/syncio
type
  MyError = ref object of Exception
    code: int
  Deeper = ref object of MyError
    depth: int

proc risky(n: int) {.raises: MyError.} =
  if n > 2:
    raise Deeper(msg: "deep " & $n, code: n, depth: n * 2)
  elif n > 0:
    raise MyError(msg: "shallow " & $n, code: n)

proc guarded(n: int): string =
  result = "ok"
  try:
    risky(n)
  except Deeper as e:
    result = "deeper:" & e.msg & ":" & $e.depth
  except MyError as e:
    result = "my:" & e.msg & ":" & $e.code
  finally:
    result = result & "|fin"

for i in 0 .. 3:
  echo guarded(i)

proc boom() {.raises: MyError.} =
  raise MyError(msg: "inner", code: 1)

proc nested(): string =
  result = ""
  try:
    try:
      boom()
    finally:
      result = result & "A"
  except MyError as e:
    result = result & "B" & e.msg
  result = result & "C"
echo nested()

proc deferred(n: int): int =
  result = 0
  defer: result = result * 10
  for i in 1 .. n:
    result = result + i
echo deferred(4)
