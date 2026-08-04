## Fixture for test/staticinit.sh — a proc-local `const` of AGGREGATE type, which
## nimony emits as a BLOCK-SCOPE `static const`. C requires such an initializer to
## be a constant expression, and a compound literal is not one. This is the exact
## shape of the pow10 table in system's `computePow10`, i.e. of every program that
## formats a float.
##
## Deliberately IMPORT-FREE: with `std/syncio` the translation unit references
## `stdout` from a sibling module and cannot be compiled alone, which made the
## gate fail for the single-TU reason instead of the one under test. `pick` must
## also be REACHED from main or dce drops it and the fixture emits nothing.

type Pair = object
  hi: uint64
  lo: uint64

var sink*: uint64 = 0

proc pick(i: int): uint64 =
  const table: array[3, Pair] = [
    Pair(hi: 1'u64, lo: 2'u64),
    Pair(hi: 3'u64, lo: 4'u64),
    Pair(hi: 5'u64, lo: 6'u64)]
  result = table[i].hi + table[i].lo

proc main =
  sink = pick(1)

main()
