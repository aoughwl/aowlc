import std/syncio
import std/strutils

var s = "  Hello World  "
echo "[" & s.strip() & "]"
echo s.strip().toLowerAscii()
echo s.strip().toUpperAscii()
echo "abc".repeat(3)
echo ("hello".contains("ell"))
echo ("hello".contains("xyz"))
echo ("hello".startsWith("he"))
echo ("hello".endsWith("lo"))
var parts = "a,b,c".split(',')
echo parts.len
echo parts[0]
echo parts[2]
echo ("x" & $1 & "y")
echo "hello".find("l")
echo "hello".find("z")
# (nimony's std/strutils has no `align`/`alignLeft`)
echo "a-b-c".split('-').len
echo "one two".split(' ')[1]
echo "aaa".replace("a", "b")
echo "Hello".toLowerAscii().capitalizeAscii()
