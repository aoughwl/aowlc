import std/syncio

# Nimony exception surface (heap ref-exception form).
#  - a proc that can raise must carry a `.raises` pragma; `.raises: T` names the
#    raised type (bare `.raises` defaults to the ErrorCode enum).
#  - `raise T(msg: ..., field: ...)` constructs and raises a `ref object of Exception`.
#  - `try / except T as e / except:` catches; `e` is bound to the caught object.
#  There is no `newException`: the exception object is constructed directly.

type
  MyError = ref object of Exception
    code: int

proc mayFail(x: int): int {.raises: MyError.} =
  if x < 0:
    raise MyError(msg: "negative", code: 7)
  result = x * 2

proc run(x: int) =
  try:
    let v = mayFail(x)
    echo "ok: ", v
  except MyError as e:
    echo "caught: ", e.msg, " code=", e.code

run(5)
run(-1)
run(3)
run(-42)
