## e2e fixture: the C-emission shapes that were EMITTED but never EXECUTED.
##
## Everything here already appeared in `examples/system.c.nif`, which the corpus
## only ever COMPILE-CHECKS — nothing ran it, so a printer that emitted plausible
## C with the wrong meaning would have stayed green. test/e2e.sh compares our
## binary's stdout against nimony's own `c -r`, so each line below is an assertion
## with a real oracle.
##
## Covered, in the order the emitter reaches them:
##
##   goto/labels   emitc.nim `lab`/`jmp` — the lowering target for a break out of
##                 NESTED loops. Zero fixtures reached it. The nested loop below
##                 stops on the FIRST hit; a mislowered label would either run the
##                 outer loop to completion or skip it entirely, and both change
##                 the printed text.
##   unions        emitc.nim genObjectFields' `union` branch. An object variant is
##                 where a printer silently disagrees with the compiler's LAYOUT:
##                 every branch is written and read back here, including the
##                 `else` branch, so a field landing in the wrong union arm shows
##                 up as a wrong number rather than as a compile error.
##   enums         genEnumDecl was entirely unexercised. It emits a `#define` per
##                 field with an explicit cast to the base type; a wrong ordinal
##                 is invisible until one is printed.
##   64-bit edges  genUIntLit/parseU64 had no caller in the corpus. high(int64) is
##                 the value whose negation overflows, low(int64) is the literal
##                 that cannot be written as a positive constant, and a large
##                 unsigned literal is the one that does not fit in int64 at all.
##   floats        isFloatLit is a RECOGNIZER — a matching literal passes through
##                 VERBATIM, so a full-precision double round-trips only if every
##                 digit survives. inf/nan have no digits, cannot match it, and
##                 take the separate `INF`/`NAN` prelude-macro path that nothing
##                 tested.
##
## ⚠️ Every string literal here is longer than 8 bytes on purpose. A shorter one
## is packed into the SSO `bytes_0` uint64 of the string struct and never becomes
## a C string literal at all — see e2e_escapes.nim, where a 4-char literal made
## the fixture pass with the bug reinstated.
import std/syncio

# --- enums: genEnumDecl -----------------------------------------------------
type
  Shape = enum
    Circle, Square, Triangle

  # --- object variant: the `union` branch of genObjectFields ----------------
  Figure = object
    tag: string
    case kind: Shape
    of Circle:
      radius: int
    of Square:
      side: int
    else:
      base: int
      height: int

proc area(f: Figure): int =
  case f.kind
  of Circle: result = 3 * f.radius * f.radius
  of Square: result = f.side * f.side
  else: result = f.base * f.height div 2

proc describe(f: Figure): string =
  result = f.tag & ": " & $ord(f.kind) & " area=" & $area(f)

# --- goto/labels: a break out of NESTED loops -------------------------------
proc firstPairSummingTo(target: int): int =
  ## Two loops, one exit. `break outer` from the INNER loop is what lowers to a
  ## label plus a jump; without it the outer loop would keep running and the
  ## printed sum would be the LAST pair, not the first.
  result = -1
  block outer:
    var i = 1
    while i <= 9:
      var j = 1
      while j <= 9:
        if i * j == target:
          result = i * 100 + j
          break outer
        j = j + 1
      i = i + 1

proc countUntilSkip(): int =
  ## `continue` inside a nested loop is the other jump shape: it must land on the
  ## INNER loop's increment, not the outer one's.
  result = 0
  var i = 0
  while i < 4:
    var j = 0
    while j < 4:
      j = j + 1
      if j == 2: continue
      result = result + 1
    i = i + 1

proc main =
  # enums, read back as ordinals so a wrong #define value is visible
  echo "enum ordinals: " & $ord(Circle) & " " & $ord(Square) & " " & $ord(Triangle)

  # every variant branch constructed AND read back
  let c = Figure(tag: "circle_shape", kind: Circle, radius: 5)
  let s = Figure(tag: "square_shape", kind: Square, side: 7)
  let t = Figure(tag: "triangle_shp", kind: Triangle, base: 6, height: 9)
  echo describe(c)
  echo describe(s)
  echo describe(t)

  # goto / labels
  echo "first pair: " & $firstPairSummingTo(12)
  echo "no pair:    " & $firstPairSummingTo(97)
  echo "continue:   " & $countUntilSkip()

  # 64-bit constant edges: genUIntLit / parseU64 / the low(int64) literal
  let hi: int64 = high(int64)
  let lo: int64 = low(int64)
  let bigu: uint64 = 18446744073709551615'u64
  let midu: uint64 = 12345678901234567890'u64
  echo "high int64: " & $hi
  echo "low int64:  " & $lo
  echo "max uint64: " & $bigu
  echo "mid uint64: " & $midu
  echo "wrap:       " & $(hi + 1'i64)

  # float formatting fidelity: a full-precision double must round-trip verbatim
  let pi = 3.141592653589793
  let tiny = 2.2250738585072014e-308
  let huge = 1.7976931348623157e+308
  echo "pi:   " & $pi
  echo "tiny: " & $tiny
  echo "huge: " & $huge

  # inf/nan have NO digits, so isFloatLit cannot match them and they take the
  # INF/NAN prelude-macro path instead.
  let posInf = Inf
  let negInf = -Inf
  let nn = NaN
  echo "inf:  " & $posInf
  echo "ninf: " & $negInf
  echo "nan:  " & $nn

main()
