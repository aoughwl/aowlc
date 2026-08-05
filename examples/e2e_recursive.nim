## Recursive `ref` structures — a linked list and a binary tree — plus multi-arg
## `echo` and nested (non-capturing) procs.
## A nil-able `ref` field needs this: without it nimony rejects `next: Node` set
## to nil with "expected non-nil value".
when defined(nimony):
  {.feature: "lenientnils".}
import std/syncio

type
  Node = ref object
    val: int
    next: Node
  Tree = ref object
    key: int
    left: Tree
    right: Tree

# build a list by prepending, then walk it
var head: Node = nil
for i in countdown(4, 0):
  head = Node(val: i, next: head)

var walk = head
var acc = ""
while walk != nil:
  acc = acc & $walk.val & "-"
  walk = walk.next
echo acc

proc listLen(n: Node): int =
  result = 0
  var cur = n
  while cur != nil:
    result = result + 1
    cur = cur.next
echo listLen(head)
echo listLen(nil)

# mutation through the reference is visible from the head
head.next.val = 99
echo head.next.val

proc insert(t: Tree; k: int): Tree =
  if t == nil:
    result = Tree(key: k, left: nil, right: nil)
  else:
    result = t
    if k < t.key: result.left = insert(t.left, k)
    elif k > t.key: result.right = insert(t.right, k)

proc inorder(t: Tree; out2: var string) =
  if t != nil:
    inorder(t.left, out2)
    out2 = out2 & $t.key & ","
    inorder(t.right, out2)

var root: Tree = nil
for k in [5, 3, 8, 1, 4, 7, 9]:
  root = insert(root, k)
var sorted = ""
inorder(root, sorted)
echo sorted

proc depth(t: Tree): int =
  if t == nil:
    result = 0
  else:
    let l = depth(t.left)
    let r = depth(t.right)
    result = 1 + (if l > r: l else: r)
echo depth(root)

# echo with several arguments of mixed type
var name = "x"
echo "n=", 5, " s=", name, " f=", 1.5, " b=", (1 < 2)

# a nested proc that does not capture
proc outerProc(n: int): int =
  proc square(k: int): int = k * k
  result = square(n) + square(n + 1)
echo outerProc(3)
