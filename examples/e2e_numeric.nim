import std/syncio
# float arithmetic, comparison and the math shims
var a = 7.5
var b = 2.0
echo a + b
echo a - b
echo a * b
echo a / b
echo (a > b)
echo (a >= 7.5)
echo (b < a)
echo (a == 7.5)
echo (a != b)
echo -a
echo abs(-a)
echo abs(a)
echo min(a, b)
echo max(a, b)
echo min(3, 9)
echo max(3, 9)

# int/float conversion both ways
echo float(7)
echo float(-7)
echo int(7.9)
echo int(-7.9)
echo int(7.0)

# operator precedence in a compound expression
echo (2 + 3 * 4)
echo ((2 + 3) * 4)
echo (10 - 4 - 3)
echo (2 * 3 + 4 * 5)
echo (1 + 2 < 4 and 3 * 2 > 5)
echo (not (1 > 2) or false)

# integer division and modulo, both signs
echo (17 div 5)
echo (17 mod 5)
echo (-17 div 5)
echo (-17 mod 5)
echo (17 div -5)
echo (17 mod -5)

# a float accumulation loop
var acc = 0.0
for i in 1 .. 10:
  acc = acc + float(i) / 2.0
echo acc

# mixed-width integer arithmetic
var i8v: int8 = 100
var i16v: int16 = 1000
var i32v: int32 = 100000
echo int(i8v) + int(i16v) + int(i32v)
var u16v: uint16 = 65535'u16
echo u16v
echo u16v div 2'u16
