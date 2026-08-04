## e2e fixture: a distinct conversion at GLOBAL scope.
##
## `type Name = distinct string` plus a top-level `var n = Name("…")` lowers to
## `(conv string (oconstr string …))`, and the emitter wrapped the constructor in
## a redundant cast to the type it already had:
##
##   (T){…}        a COMPOUND LITERAL — legal as a file-scope initializer
##   (T)(T){…}     a CAST EXPRESSION  — not a constant expression, so gcc says
##                 `error: initializer element is not constant`
##
## SCOPE IS THE WHOLE TRIGGER. The identical conversion inside a proc compiles
## either way, because a block-scope initializer need not be constant — which is
## why every existing fixture missed it: they all converted locally. So the
## declarations below must stay at module level to mean anything.
##
## Found while extending aowllib's corpus, where it took out the whole
## translation unit.
import std/syncio

type
  Name = distinct string
  Count = distinct int

# MODULE LEVEL, deliberately — moving these into `main` disarms the fixture.
var who = Name("bob_the_builder")
var howMany = Count(41)
let greeting = Name("hello_there_world")

proc `$`(n: Name): string = string(n)
proc `$`(c: Count): string = $int(c)

proc main =
  echo $who
  echo $greeting
  echo $howMany
  # convert back out, and construct a fresh one locally for contrast
  echo string(who) & "/" & $(int(howMany) + 1)
  let local = Name("locally_constructed")
  echo $local

main()
