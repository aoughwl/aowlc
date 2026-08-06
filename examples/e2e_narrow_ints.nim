## Narrow machine ints — the widths JS does not have. Every bitwise op in JS
## yields a *signed 32-bit* number, so `4000000000'u32 shr 8` came out as
## -1152216 (a sign-extending `>>`) instead of 15625000, and an unsigned or
## sub-32-bit result had nothing renormalising it.
import std/syncio
var a = 0b1011
var b = 6
echo a and b
echo a or b
echo a xor b
echo not a
echo a shl 3
echo a shr 1
echo (-7) div 2
echo (-7) mod 2
echo 7 div -2
var u: uint32 = 4000000000'u32
echo u
echo u shr 8
echo u shl 1
echo u and 0xFF'u32
var c: int8 = -128
echo c
var s16: int16 = 30000'i16
echo s16 + 30000'i16
var u8: uint8 = 200'u8
echo u8 + 100'u8
