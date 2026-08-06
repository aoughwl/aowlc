## A three-module chain with top-level side effects, so module INITIALISATION
## ORDER is observable: base must run before mid before main, and mid's global is
## computed from base's proc at init time. It also pins the thing that made this
## fixture necessary — a nimony LOCAL is spelled `result.0` with no module
## segment and the counter restarts per module, so two modules' locals are the
## same string.
import std/syncio
import mid
import base
var mainValue = bump() * 100
echo "init main"
echo midInfo()
echo baseCounter
echo mainValue
