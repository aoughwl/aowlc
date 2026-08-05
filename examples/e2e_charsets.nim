import std/syncio
# char ordering, ord/chr round trip, ranges
var c = 'm'
echo (c >= 'a')
echo (c <= 'z')
echo ord(c)
echo chr(ord(c) + 1)
echo (c == 'm')
echo (c != 'n')
var lo = 'a'
var hi = 'e'
var built = ""
var i = ord(lo)
while i <= ord(hi):
  built.add chr(i)
  i = i + 1
echo built

# char sets
var vowels = {'a', 'e', 'i', 'o', 'u'}
echo ('e' in vowels)
echo ('z' in vowels)
var letters = {'a'..'z'}
echo ('q' in letters)
echo ('Q' in letters)
var digits = {'0'..'9'}
echo ('7' in digits)

# counting with a set membership test
var text = "hello world"
var n = 0
for ch in text:
  if ch in vowels: n = n + 1
echo n

# enum sets: union, difference, membership
type Flag = enum fA, fB, fC, fD
var s1 = {fA, fB}
var s2 = {fB, fC}
var u = s1 + s2
var d = s1 - s2
var x = s1 * s2
echo (fA in u)
echo (fC in u)
echo (fA in d)
echo (fB in d)
echo (fB in x)
echo (fA in x)
s1.incl fD
echo (fD in s1)
s1.excl fA
echo (fA in s1)
echo (fB in s1)
