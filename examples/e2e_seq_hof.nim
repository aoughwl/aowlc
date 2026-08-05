import std/syncio
import std/sequtils
var xs = @[1, 2, 3, 4]
var evens = xs.filter(proc(x: int): bool = x mod 2 == 0)
echo evens.len
var doubled = xs.map(proc(x: int): int = x * 2)
echo doubled[3]
