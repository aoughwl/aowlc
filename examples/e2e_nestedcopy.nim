## Value semantics THROUGH nesting: an object holding a seq, a seq of objects
## holding seqs, an array of seqs. A shallow copy passes the simple cases in
## value_semantics.nim and fails every one of these.
import std/syncio
type
  Bag = object
    items: seq[int]
    name: string
  Pair = object
    left: Bag
    right: Bag

var b1 = Bag(items: @[1, 2], name: "b1")
var b2 = b1
b2.items.add 3
b2.name = "b2"
echo b1.items.len        # 2 — b2's append must not reach b1
echo b2.items.len        # 3
echo b1.name
echo b2.name

# mutate an element of the copied seq
b2.items[0] = 99
echo b1.items[0]         # 1
echo b2.items[0]         # 99

# two levels down
var p1 = Pair(left: b1, right: Bag(items: @[7], name: "r"))
var p2 = p1
p2.left.items.add 42
p2.right.items[0] = 70
echo p1.left.items.len   # 2
echo p2.left.items.len   # 3
echo p1.right.items[0]   # 7
echo p2.right.items[0]   # 70

# a seq of objects that themselves hold seqs
var bags: seq[Bag] = @[]
bags.add b1
bags.add Bag(items: @[5], name: "x")
var taken = bags[0]
taken.items.add 8
echo bags[0].items.len   # 2
echo taken.items.len     # 3

# writing through the index reaches the stored element
bags[1].items.add 6
echo bags[1].items.len   # 2

# an array of seqs
var rows: array[2, seq[int]]
rows[0].add 1
rows[1].add 2
rows[1].add 3
echo rows[0].len
echo rows[1].len
var rowsCopy = rows
rowsCopy[0].add 9
echo rows[0].len         # 1
echo rowsCopy[0].len     # 2
