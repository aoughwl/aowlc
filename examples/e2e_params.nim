import std/syncio
# default parameter values
proc greet(name: string; greeting = "hi"; times = 1): string =
  result = ""
  for i in 1 .. times:
    result = result & greeting & "," & name & ";"
echo greet("a")
echo greet("b", "yo")
echo greet("c", "hey", 3)

# (nimony has no NAMED arguments — `greet(name: "d")` is parsed as an object
# constructor: "expected type symbol for object constructor")

# overloads resolved by argument type
proc show(x: int): string = "int:" & $x
proc show(x: string): string = "str:" & x
proc show(x: float): string = "flt:" & $x
proc show(x: char): string = "chr:" & $ord(x)
echo show(1)
echo show("s")
echo show(2.5)
echo show('z')

# overloads by arity
proc combine(a: int): int = a
proc combine(a, b: int): int = a * 10 + b
proc combine(a, b, c: int): int = a * 100 + b * 10 + c
echo combine(1)
echo combine(1, 2)
echo combine(1, 2, 3)

# a proc with many parameters, to check argument order end to end
proc six(a, b, c, d, e, f: int): string =
  $a & $b & $c & $d & $e & $f
echo six(1, 2, 3, 4, 5, 6)

# re-raise from inside an except
type E = ref object of Exception
proc inner() {.raises: E.} = raise E(msg: "boom")
proc middle() {.raises: E.} =
  try:
    inner()
  except E as e:
    raise e                       # re-raise the caught exception
proc outerCatch(): string =
  result = "?"
  try:
    middle()
  except E as e:
    result = "caught:" & e.msg
echo outerCatch()

# a bare `except:` catch-all
proc anyCatch(): string =
  result = "?"
  try:
    inner()
  except:
    result = "any"
echo anyCatch()
