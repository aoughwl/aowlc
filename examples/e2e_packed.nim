## `{.packed.}` and `{.union.}` — layout pragmas that BOTH printers dropped.
## A packed object was 24 bytes against nimony's 10, with every field after the
## first at a different offset: it compiles, it runs, and it disagrees with the
## compiler about layout. `sizeof` is the observable, so this fixture asserts it.
import std/syncio
type
  Packed {.packed.} = object
    a: char
    b: int64
    c: char
  Plain = object
    a: char
    b: int64
    c: char
  United {.union.} = object
    i: int64
    f: float64
    c: char
echo sizeof(Packed)
echo sizeof(Plain)
echo sizeof(United)
var p = Packed(a: 'a', b: 7'i64, c: 'c')
echo p.b
echo (p.a == 'a')
echo (p.c == 'c')
# ⚠️ `u.i` reads back 0, NOT 5. nimony's lowering puts a kv for EVERY union
# member in the oconstr, so the emitted C is
#   United u = { .i_0 = 5, .f_0 = 0.0, .c_0 = 0 };
# and in a C union each designator overwrites the last. gcc says so
# (-Woverride-init, twice). Both aowlc printers and nimony's own binary agree on
# the 0, so this asserts that they AGREE — not that 0 is right. Filed to aowlsem.
var u = United(i: 5'i64)
echo u.i
