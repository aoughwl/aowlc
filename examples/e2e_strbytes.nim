## nimony strings are BYTES; JS strings are UTF-16 code units. Any non-ASCII
## content makes `len`, indexing and slicing disagree unless the backend does
## something about it.
import std/syncio
var s = "h\xC3\xA9llo"          # "héllo" as UTF-8 bytes: 6 bytes, 5 characters
echo s.len
echo ord(s[0])
echo ord(s[1])
echo ord(s[2])
echo ord(s[3])
var t = "aXb"
echo t.len
echo ord(t[1])
var u = "\xE2\x82\xAC"          # the euro sign: 3 UTF-8 bytes
echo u.len
echo ord(u[0])
echo ord(u[2])
var joined = s & u
echo joined.len
var count = 0
for c in joined:
  count = count + 1
echo count
