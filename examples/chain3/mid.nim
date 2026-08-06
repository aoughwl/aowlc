import std/syncio
import base
var midValue* = bump() * 10
echo "init mid"
proc midInfo*(): string = "mid=" & $midValue
