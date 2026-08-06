## `$float` — where JS and nimony disagree. Both print shortest-round-trip
## digits, but JS switches to exponent form at 1e21 / 1e-7 and nimony at
## 1e17 / 1e-8, so the notation boundary has to be re-laid-out, not delegated
## to String(x). -0.0, inf/nan and `$` (not just echo) are on the same path.
import std/syncio
echo 1.5
echo 3.0
echo -0.0
echo 0.0
echo 1.0 / 3.0
echo 1e5
echo 1e16                 # last fixed-notation exponent
echo 1e17                 # first exponent-notation exponent
echo 1e20
echo 1e21
echo 1e-5
echo 0.0000001            # k = -7, still fixed
echo -2.5e-8              # k = -8, exponent form
echo 123456789.125
echo 0.1
echo 1.0e100
echo 1234567890123456.0
var z = 0.0
var o = 1.0
echo o / z
echo -o / z
echo z / z
echo $(2.5)
echo "v=" & $(0.5)
