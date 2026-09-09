## The SIGNED counterpart of the `255u` width bug, which had no fixture.
##
## A bare `255` in C is typed `int`. The cast aowlc prints for a typed binary
## node wraps the RESULT — `((NI64)(a op b))` — so it is applied too late to
## widen an operand, and in `(shl (i 64) 1 k)` there is nothing else to widen
## the left side: shift is the one binary operator whose right operand does not
## promote the left. `((NI64)(1 << k))` with k = 40 is a shift past the width of
## `int` — undefined behaviour, and 1 << (40 & 31) = 256 on x86 where nimony
## says 1099511627776.
##
## Every other arithmetic node hides this, which is why the corpus was green:
## in `a + 255` the NI64 `a` already promotes the literal. So this fixture is
## deliberately built out of shifts with a LITERAL left operand.
import std/syncio

var k = 40
var one = 1

echo 1 shl k              # 1099511627776
echo 3 shl k              # 3298534883328
echo (1 shl k) - 1        # 1099511627775
echo one shl k            # control: a variable LHS was always right
echo 1 shl 62             # folded to a wide literal by the frontend
var small = 3
echo 1 shl small          # a shift that fits in `int` — must not change
echo 255 + k
