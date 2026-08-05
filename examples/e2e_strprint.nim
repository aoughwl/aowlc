## The other half of byte semantics: a non-ASCII string still has to PRINT as
## text, not as the bytes of its UTF-8 encoding.
import std/syncio
echo "héllo wörld"
echo "euro: €"
echo "mixed: aé€b"
var s = "café"
echo s
echo s.len            # 5 bytes, not 4 characters
var t = s & " au lait"
echo t
echo t.len
echo "plain ascii"
