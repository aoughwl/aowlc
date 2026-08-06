## An integration case: tokenizer + shunting-yard + RPN evaluator. Combines
## enums, object variants, seqs as stacks, string building, exceptions with a
## custom type, `case` over both an enum and a char, and recursion — the way a
## real program does, rather than one feature at a time.
import std/syncio

type
  TokKind = enum tkNum, tkOp, tkOpen, tkClose
  Tok = object
    case kind: TokKind
    of tkNum: value: int
    of tkOp: op: char
    else: discard
  CalcError = ref object of Exception
    at: int

proc tokenize(s: string): seq[Tok] {.raises: CalcError.} =
  result = @[]
  var i = 0
  while i < s.len:
    let c = s[i]
    case c
    of ' ':
      i = i + 1
    of '0' .. '9':
      var n = 0
      while i < s.len and s[i] >= '0' and s[i] <= '9':
        n = n * 10 + (ord(s[i]) - ord('0'))
        i = i + 1
      result.add Tok(kind: tkNum, value: n)
    of '+', '-', '*', '/':
      result.add Tok(kind: tkOp, op: c)
      i = i + 1
    of '(':
      result.add Tok(kind: tkOpen)
      i = i + 1
    of ')':
      result.add Tok(kind: tkClose)
      i = i + 1
    else:
      raise CalcError(msg: "bad char", at: i)

proc prec(op: char): int =
  case op
  of '+', '-': 1
  of '*', '/': 2
  else: 0

proc toRpn(toks: seq[Tok]): seq[Tok] =
  result = @[]
  var ops: seq[Tok] = @[]
  for t in toks:
    case t.kind
    of tkNum:
      result.add t
    of tkOp:
      while ops.len > 0 and ops[ops.len - 1].kind == tkOp and
            prec(ops[ops.len - 1].op) >= prec(t.op):
        result.add ops.pop()
      ops.add t
    of tkOpen:
      ops.add t
    of tkClose:
      while ops.len > 0 and ops[ops.len - 1].kind != tkOpen:
        result.add ops.pop()
      if ops.len > 0: discard ops.pop()
  while ops.len > 0:
    result.add ops.pop()

proc evalRpn(rpn: seq[Tok]): int {.raises: CalcError.} =
  var st: seq[int] = @[]
  for t in rpn:
    case t.kind
    of tkNum:
      st.add t.value
    of tkOp:
      if st.len < 2: raise CalcError(msg: "stack underflow", at: 0)
      let b = st.pop()
      let a = st.pop()
      case t.op
      of '+': st.add a + b
      of '-': st.add a - b
      of '*': st.add a * b
      of '/':
        if b == 0: raise CalcError(msg: "divide by zero", at: 0)
        st.add a div b
      else: discard
    else: discard
  if st.len != 1: raise CalcError(msg: "bad expression", at: 0)
  result = st[0]

proc render(rpn: seq[Tok]): string =
  result = ""
  for t in rpn:
    case t.kind
    of tkNum: result = result & $t.value & " "
    of tkOp: result = result & t.op & " "
    else: discard

proc calc(src: string): string =
  result = ""
  try:
    let rpn = toRpn(tokenize(src))
    result = render(rpn) & "=> " & $evalRpn(rpn)
  except CalcError as e:
    result = "error: " & e.msg & "@" & $e.at

for src in ["1 + 2 * 3",
            "(1 + 2) * 3",
            "10 / 3",
            "2 * (3 + 4) - 5",
            "8 / 0",
            "1 + $",
            "100"]:
  echo calc(src)
