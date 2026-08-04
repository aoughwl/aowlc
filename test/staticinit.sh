#!/usr/bin/env bash
# test/staticinit.sh — a C INITIALIZER is not a C expression, and aowlc must not
# print one where the other is required.
#
#   bash test/staticinit.sh
#   AOWLC=/path/to/aowlc-native bash test/staticinit.sh
#
# THE BUG THIS GATES
#
# A constructor was printed as a compound literal everywhere, including as the
# initializer of a declaration:
#
#   static const T pow10_3 = (T){ .a = { (P){ .hi_0 = …, .lo_0 = … }, … } };
#
# A compound literal is not a constant expression (C11 6.6), and the initializer
# of an object with static storage duration must be one, so gcc rejects that
# outright — `error: initializer element is not constant`. The right form is the
# initializer list, which is also exactly what nimony's own C backend (lengc)
# prints for the same table:
#
#   static const T pow10_3 = { .a = { { .hi_0 = …, .lo_0 = … }, … } };
#
# WHY IT MATTERED MORE THAN A WARNING. `computePow10` lives in nimony's system
# module and holds a proc-local `const` table of 128-bit mantissas, so it is
# reached by ANY program that formats a float. One rejected declaration fails the
# whole translation unit, and in aowli's mid-run JIT — which links this printer
# in-process — the only visible symptom was the JIT silently declining to compile
# every proc, i.e. it looked like a capability gap rather than a C syntax bug.
#
# Fixtures are the SHIPPED examples/*.c.nif, so this gate needs no nimony run and
# finishes in about a second.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
AOWLC="${AOWLC:-$ROOT/bin/aowlc-native}"
SYS="$ROOT/examples/system.c.nif"
# The BLOCK-SCOPE fixture. system.c.nif's static aggregates are all file scope,
# where gcc accepts a compound literal as an extension — so with that fixture
# alone the "gcc compiles it" assertion passes even against the unpatched
# printer, and the gate would not cover the shape that actually broke.
# localconst.c.nif is a 3KB module with a proc-local `const` array of objects:
# the pow10 shape, self-contained, and it fails to compile for exactly the right
# reason when the fix is absent.
LOCAL="$ROOT/examples/localconst.c.nif"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PLAN=10
pass=0; fail=0
ok()  { printf 'ok    %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; fail=$((fail+1)); }

echo "aowlc gate: static-initializer form"
echo "  scope   : the C PRINTER (src/emitc.nim) only — constructor emission in"
echo "            initializer vs expression position, plus which non-standard C"
echo "            constructs remain. Not the driver, not linking."
echo "  printer : $AOWLC"
echo "  fixture : $(basename "$SYS") + $(basename "$LOCAL") (shipped; no nimony run needed)"
echo "  asserts : $PLAN declared"
echo

if [ ! -x "$AOWLC" ]; then
  echo "staticinit.sh: no aowlc-native at $AOWLC (build it: bash build.sh)" >&2
  exit 2
fi
for f in "$SYS" "$LOCAL"; do
  if [ ! -f "$f" ]; then
    echo "staticinit.sh: missing fixture $f" >&2
    exit 2
  fi
done

"$AOWLC" "$SYS" > "$WORK/system.c" 2>"$WORK/system.err"
if [ ! -s "$WORK/system.c" ]; then
  echo "staticinit.sh: the printer emitted nothing: $(head -c 200 "$WORK/system.err")" >&2
  exit 2
fi

# 1. THE FIXTURE IS ACTUALLY EXERCISED. Without this every assertion below is
#    vacuously true the day the fixture stops containing a const aggregate.
#
#    ⚠️ `static` IS OPTIONAL HERE, AND DELIBERATELY SO. This used to require the
#    literal `static const`, which made it an assertion about LINKAGE — something
#    this gate is not about (its scope line says: constructor emission in
#    initializer vs expression position). genGlobal now gives a module-level const
#    EXTERNAL linkage, and it has to: nimony emits each strlit/vtable const once in
#    its owning module and references it cross-module by `extern`, so `static`
#    hides the definition. Measured on aowli's JIT units, the same four .c files
#    either way:
#
#      const        -> nm -u: no undefined strlit;  dlopen ok
#      static const -> nm -u: strlit_0_I14694606176902936784_shanfvkib1 undefined
#                             dlopen FAILED: undefined symbol
#
#    and `gcc -shared` LINKS BOTH SILENTLY — the static build only fails when the
#    JIT actually dlopens it. So the linkage is load-bearing and untestable from
#    here; what belongs here is only "is there a const aggregate initializer to
#    reason about at all", which is what this now asks.
nstatic=$(grep -cE '^\s*(static )?const .* = \{' "$WORK/system.c")
if [ "$nstatic" -gt 0 ]; then
  ok "the fixture emits $nstatic const aggregate initializer(s) (static or not — linkage is not this gate's subject)"
else
  bad "the fixture emits a const aggregate" "none found — this gate would prove nothing"
fi

# 2. NO compound literal in initializer position, at any nesting depth.
badinit=$(grep -n '= *([A-Za-z_][A-Za-z0-9_]*) *{' "$WORK/system.c" \
          | grep -E '(static const|^[0-9]+:const |^[0-9]+:[A-Za-z_].* = \()' | head -3)
if [ -z "$badinit" ]; then
  ok "no declaration initializer uses a compound literal"
else
  bad "no declaration initializer uses a compound literal" "$(echo "$badinit" | head -1 | cut -c1-160)"
fi

# 3. THE REAL PROPERTY: gcc accepts it. Assertion 2 is a proxy for this one, and a
#    proxy is not the thing — compile it.
if gcc -c "$WORK/system.c" -o "$WORK/system.o" 2>"$WORK/gcc.err"; then
  ok "gcc compiles the emitted C"
else
  bad "gcc compiles the emitted C" "$(grep -m1 error "$WORK/gcc.err" | cut -c1-160)"
fi

# 4. NOT OVER-APPLIED. An ASSIGNMENT still needs the compound literal — `x = { … }`
#    is not an expression in C — so the fix must not have flattened everything.
if grep -qE '^\s+[A-Za-z_][A-Za-z0-9_]* = \([A-Za-z_][A-Za-z0-9_]*\) *\{' "$WORK/system.c"; then
  ok "assignments still use a compound literal (the fix is scoped to initializers)"
else
  bad "assignments still use a compound literal" "none found — the printer may have flattened expression position too"
fi

# 5. NEGATIVE CONTROL. Put the defect back, in C, and require gcc to reject it.
#    Without this, assertions 2-3 could both pass against a compiler that does not
#    care, and the gate would be asserting nothing.
cat > "$WORK/defect.c" <<'EOF'
typedef struct { unsigned long long hi, lo; } P;
typedef struct { P a[2]; } T;
int f(void) {
  static const T t = (T){ .a = { (P){ .hi = 1, .lo = 2 }, (P){ .hi = 3, .lo = 4 } } };
  return (int)t.a[0].hi;
}
EOF
if gcc -c "$WORK/defect.c" -o "$WORK/defect.o" 2>"$WORK/defect.err"; then
  bad "the old form is rejected by gcc (negative control)" "gcc ACCEPTED a compound literal as a static initializer — assertions 2-3 prove nothing on this toolchain"
else
  ok "the old form is rejected by gcc: $(grep -m1 -o 'error: [^\\n]*' "$WORK/defect.err" | cut -c1-60)"
fi

# 6. NESTED constructors are brace-form too — asserted on OUR OUTPUT, and with the
#    standard, not gcc's default, as the control.
#
#    This assertion was first written the other way round ("gcc rejects a nested
#    compound literal for the same reason as an outer one") and FAILED: gcc
#    ACCEPTS one, as an extension, exactly as it accepts a compound literal in a
#    file-scope initializer. So the outer form is a hard error and the inner form
#    is merely non-standard — `-std=c11 -pedantic-errors` rejects it, which is the
#    honest control here. The pow10 elements are themselves constructors, so the
#    printer recursing is what keeps this output standard C rather than
#    gcc-specific, and that is worth holding even though gcc would let it pass.
if grep -qE 'static const .* = \{.*\([A-Za-z_][A-Za-z0-9_]*\) *\{' "$WORK/system.c"; then
  bad "nested constructors are brace-form inside a static initializer" \
      "a compound literal is nested inside one — gcc allows it as an extension, but -pedantic-errors does not"
else
  cat > "$WORK/nested.c" <<'EOF'
typedef struct { unsigned long long hi, lo; } P;
typedef struct { P a[2]; } T;
int g(void) {
  static const T t = { .a = { (P){ .hi = 1, .lo = 2 }, { .hi = 3, .lo = 4 } } };
  return (int)t.a[0].hi;
}
EOF
  if gcc -std=c11 -pedantic-errors -c "$WORK/nested.c" -o "$WORK/nested.o" 2>/dev/null; then
    bad "nested constructors are brace-form inside a static initializer" \
        "the control did not hold: this gcc accepts a nested compound literal even under -pedantic-errors, so the assertion proves nothing here"
  else
    ok "nested constructors are brace-form too (a nested compound literal is non-standard: -pedantic-errors rejects it)"
  fi
fi

# 7 + 8. THE SHAPE THAT ACTUALLY BROKE: a BLOCK-SCOPE static const aggregate.
#    gcc accepts a compound literal in a FILE-scope initializer as an extension,
#    so assertions 1-3 above pass against the unpatched printer too. Only this
#    fixture makes the gate fail when the fix is removed — which is the whole
#    test of whether a gate is worth having.
"$AOWLC" "$LOCAL" > "$WORK/localconst.c" 2>"$WORK/localconst.err"
if grep -qE '^\s+static const .* = \{' "$WORK/localconst.c"; then
  ok "the block-scope fixture emits a proc-local static const aggregate"
else
  bad "the block-scope fixture emits a proc-local static const aggregate" \
      "not found — this is the only fixture covering the shape that broke: $(head -c 120 "$WORK/localconst.err")"
fi

if gcc -c "$WORK/localconst.c" -o "$WORK/localconst.o" 2>"$WORK/localconst.gcc"; then
  ok "gcc compiles a translation unit with a proc-local const aggregate"
else
  bad "gcc compiles a translation unit with a proc-local const aggregate" \
      "$(grep -m1 error "$WORK/localconst.gcc" | cut -c1-160)"
fi

# 9 + 10. WHAT NON-STANDARD C IS LEFT, AND IS IT OURS.
#
#    The compound-literal bug was non-standard C that worked by GNU extension
#    until it did not. The honest follow-up is not "is the output standard" — it
#    is not — but "does aowlc introduce any non-standard construct that nimony's
#    OWN backend does not". Measured on nimony's C for the same program: it emits
#    the identical flexible-array-member initializer for string literals and
#    fails -pedantic-errors identically (7 diagnostics, same construct). The
#    LongString payload is a flexible array member by the compiler's own layout,
#    so a printer cannot initialize it any other way without DIVERGING from the
#    reference backend, which is the property e2e.sh exists to protect.
#
#    So: the FAM initializations are accepted by decision and pinned here, and any
#    OTHER class of non-standard C is a regression.
gcc -std=c11 -pedantic-errors -c "$WORK/system.c" -o /dev/null 2>"$WORK/ped.err"
kinds=$(grep -o 'error: [a-z ]*' "$WORK/ped.err" | sort -u)
nkinds=$(printf '%s' "$kinds" | grep -c . || true)
if [ "$nkinds" -le 1 ] && printf '%s' "$kinds" | grep -q 'flexible array member'; then
  ok "the only non-standard construct left is the FAM initializer (nimony's own backend emits it too)"
elif [ "$nkinds" -eq 0 ]; then
  bad "the FAM initializer is still present and pinned" \
      "-pedantic-errors is now CLEAN, so this assertion no longer measures anything — retire it or tighten the gate to -pedantic-errors"
else
  bad "no NEW class of non-standard C" "$(printf '%s' "$kinds" | tr '\n' '|')"
fi

nfam=$(grep -c 'flexible array member' "$WORK/ped.err" || true)
ndata=$(grep -c 'data_0' "$WORK/ped.err" || true)
if [ "$nfam" -gt 0 ] && [ "$ndata" -ge "$nfam" ]; then
  ok "every FAM diagnostic names the LongString payload ($nfam of them), not some new struct"
else
  bad "every FAM diagnostic names the LongString payload" \
      "$nfam FAM diagnostic(s), $ndata mentioning data_0 — a different type grew a flexible array member"
fi

echo
ran=$((pass + fail))
echo "======================================================"
echo "staticinit: $pass passed, $fail failed"
echo "  scope  : src/emitc.nim constructor emission; fixtures examples/system.c.nif"
echo "           (file scope) and examples/localconst.c.nif (block scope)"
echo "  asserts: $ran of $PLAN declared"
if [ "$ran" -ne "$PLAN" ]; then
  echo "  *** PLAN MISMATCH: a case stopped running. That is RED, not a smaller gate."
fi
echo "======================================================"
[ "$fail" -eq 0 ] && [ "$ran" -eq "$PLAN" ]
