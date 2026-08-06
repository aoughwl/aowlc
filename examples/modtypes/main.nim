## Enum ordinals, object fields, structural equality, an exception type and a
## mutable global all cross the module boundary here. The emitter's enum and
## rename tables are global and accumulate across modules, so a value declared in
## one and read in another is the case that catches a mis-keyed table.
import std/syncio
import types
register(Cfg(name: "a", lvl: lMid))
register(Cfg(name: "b", lvl: lHigh))
echo registry.len
echo registry[0].name
echo levelOf(registry[0])
echo levelOf(registry[1])
echo ord(lLow)
echo (registry[1].lvl == lHigh)
echo Version
var caught = "?"
try:
  mayFail(7)
except:
  # ⚠️ Two nimony limits meet here, both filed to aowlsem. `except Failure as e`
  # then reading e.code or e.msg does NOT compile when Failure is declared in
  # ANOTHER module ("undeclared field: 'code' for type Failure" — its own field
  # as well as the inherited one), and a bare `except Failure:` on an imported
  # type is "ambiguous identifier". The same code with the type declared locally
  # works; see exceptions.nim. So the catch-all is all that is left.
  caught = "caught"
echo caught
echo (Cfg(name: "a", lvl: lMid) == registry[0])
