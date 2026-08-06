# aowlc

A **native (C) backend for [nimony](https://github.com/nim-lang/nimony)** that
compiles the post-`hexer` `.c.nif` IR to real C and links it with `gcc` — a
self-owned counterpart to [nifjs](https://github.com/aoughwl/nifjs) (the
JavaScript backend), retargeted from JS to C.

## The cheat

You don't write a code generator. You write a *printer*.

By the time nimony's `hexer` pipeline has lowered a program to a `.c.nif`, every
genuinely hard piece of compiler work is already done and baked into the IR:

| hexer pass | what it did |
|---|---|
| `destroyer` + `duplifier` + `mover` | **ARC** — destructor calls, `=copy`/`=destroy` hooks, ref-count ops injected |
| `lambdalifting` | closures → plain functions + env structs |
| `iterinliner` | iterators inlined |
| `eraiser` | exceptions → error-code plumbing |
| generic mono + `dce` + `inliner` | generics monomorphised, dead code stripped, inlined |

What's left in a `.c.nif` is a C-shaped tree with **sized types spelled out**
(`(i 32)`), an **explicit `result` var**, explicit everything. So:

> A native backend is a `.c.nif → C` printer. `hexer` already did ARC, closures,
> exceptions and monomorphisation, so the printer is mechanical and **GC is free**
> (ARC was injected upstream). C / JS / WASM are all just printers over hexer's
> output.

This is easier than nifjs was: nifjs worked from the high-level `.s.nif` and had
to invent value mappings (int→number, seq→Array) and worry about int-wrapping.
aowlc works from the post-hexer `.c.nif`, which is already sized, already ARC'd,
already monomorphised — you transliterate S-expr-C → C syntax.

## What works today

aowlc is faithful to Andreas Rumpf's own C generator (`nimony/src/lengc`) for the
**computational core**, verified end-to-end against `.c.nif` files produced by
nimony's real frontend + hexer:

- procs / funcs, parameters, recursion
- sized numeric / `char` / `bool` / pointer types (`NI64`, `NU32`, `NF64`, `NC8`, …)
- typed arithmetic & bit-ops with the wrap-preserving cast — `(add (i 64) a b)` → `((NI64)(a + b))`
- comparisons, `and`/`or`/`not`, `neg`, `bitnot`
- `if`/`elif`/`else`, `while`, `loop`, `scope`, `break`/`continue`
- `case` — single values, value lists, ranges (`case 10 ... 20`), `else`
- labels & `goto`, `var`/`let`/`cursor`/`const`/`gvar`, `asgn`/`store`, `ret`/`discard`
- casts / convs, suffixed literals, `sizeof`/`alignof`
- objects / unions / enums / arrays / proc-types (type declarations)
- the real `mangleToC` name mangling and the `importc`/`exportc` extern-name rule
- a self-contained C prelude (`NI`/`NU`/`NF`/`NC8`/`NB8`/`NIM_TRUE`/…) — no nimony runtime needed for the core

The system runtime is lowered too — strings, seqs, `echo`, exceptions, GC objects
and method dispatch all run end to end. The e2e corpus below compiles and runs
programs using them and diffs the output against nimony's own binary. Anything
aowlc can't print still raises `aowlc: unsupported …`, so a gap is visible rather
than silently wrong.

## Usage

```sh
# emit a C translation unit for the whole module
node bin/aowlc emit examples/fib.c.nif

# compile the whole module to a standalone native binary and run it
node bin/aowlc run examples/fib.c.nif

# build a native binary at a path
node bin/aowlc build examples/compute.c.nif -o /tmp/compute

# observe a single proc's result: build a harness that calls it and prints
node bin/aowlc exec examples/fib.c.nif --entry fib --arg 10        # -> 55
node bin/aowlc exec examples/compute.c.nif --entry gcd --arg 48 --arg 36   # -> 12
node bin/aowlc exec examples/mathf.c.nif --entry classify --arg 15         # -> 300

# just the linked C, no cc step (what aowli's mid-run JIT consumes)
node bin/aowlc link <nimcache>/<main>/*.c.nif --emit-only -o /tmp/program.c
```

### `build`/`run` are whole-PROGRAM

`build` and `run` link the module together with its siblings — nimony puts every
module of a program in one nimcache directory, so they are the `.c.nif` files
next to the one you named. `--single` opts back out to one translation unit.

This matters more than it sounds: a single TU cannot work for any module that
uses an imported **type**. An extern stub can stand in for a missing function,
but nothing can stand in for a missing type, so a lone module that merely called
`echo` died in gcc with `unknown type name 'LongString_0_<system>'`. `exec
--entry` was unaffected, which made it look like a whole-module *emission* bug
rather than a missing link step.

## Tests

```sh
bash test/e2e-all.sh                    # the sweep, with a DECLARED denominator
bash test/e2e.sh examples/hello.nim     # one case: emit EVERY module, gcc-link, diff vs nimony
bash test/units.sh                      # unit asserts, N of N declared
bash test/staticinit.sh                 # file-scope vs block-scope initialiser emission
npm test                                # exec-mode entry points + whole-program link/run
bash test/driver.sh examples/hello.nim  # the DRIVER (build + exec), not the raw printer
bash test/single.sh examples/hello.nim  # one TU alone vs all modules — separates a
                                        # codegen bug from a whole-module-emission one
```

`e2e.sh` compiles a program with nimony, emits C for **every** module with
aowlc, links with `gcc -Wall -Wextra`, runs it, and requires the stdout to match
nimony's own binary byte for byte. Three outcomes, because two would lie:

| exit | outcome | meaning |
|---|---|---|
| 0 | `PASS` | output compared, and matched |
| 1 | `MISMATCH` / `COMPILE-FAIL` | output compared and differed, or the build failed |
| 2 | `VACUOUS` | the program prints nothing, so an empty-vs-empty comparison would report a pass while asserting nothing |

A nonzero gcc **warning** count is reported on its own line. That is not
cosmetic: `return;` from a non-void function and an uninitialised local
(indeterminate in C, zero in nimony) were both found that way, and both were
invisible while the gate piped gcc into `head -1` — which kills gcc with SIGPIPE
on its second line of output, so a pile of warnings read as a failed build.

`e2e-all.sh` sweeps `examples/*.nim` plus every `examples/*/` directory whose
entry point is `main.nim` (multi-module cases: a type, enum, exception or global
declared in one module and used from another, and module-initialisation order).
It declares its total, so a missing fixture is a red run rather than a quieter
green one, and a fixture that stops asserting shows up as `NEWLY VACUOUS`.

`exec` mode emits only the procs (and globals) transitively reachable from the
entry, so the nimony bootstrap (`ini`/`main`/`cmdCount` and its cross-module
calls into the system runtime) is excluded and the program is fully standalone.
Whole-module `build`/`run` mode emits everything and generates weak no-op stubs
for any unresolved external call so the unit still links on its own.

### Getting a `.c.nif`

`.c.nif` is what nimony's `hexer` emits just before its own C backend
(`lengc`/`aowlc`) runs. Compile a `.nim` with nimony and look in the nimcache:

```sh
nimony c --nimcache:nc mymod.nim
node bin/aowlc exec nc/*/mymod*.c.nif --entry myproc --arg 42
```

## Pipeline

```
      nimony frontend            hexer (ARC, closures, exceptions,      aowlc
   .nim ───────────────► .s.nif ─── monomorphisation, sized types) ──► .c.nif ──► C ──► gcc ──► native binary
   (parse + sem)                                                        (this repo)
```

The cleanest self-owned native compiler reuses the one component that is
genuinely hard to rebuild — hexer's lowering — and owns everything else:
`nifparser` + `nifsem` → `hexer` → **aowlc** → `gcc`.

## Layout is cross-checked against aowlabi

[`aowlabi`](https://github.com/aoughwl/aowlabi) states the canonical ABI for the
stack, and its `tests/cbackend.sh` diffs that model against `sizeof`/`offsetof`
applied by **gcc to the C this repo emits** — padding, object variants (an
anonymous union), `{.packed.}`, `{.union.}`, a three-deep inheritance chain, sets,
refs, proc fields, ranges, distinct and empty fields, plus the runtime `string`,
`LongString` and `seq` headers. Run it from an aowlabi checkout; it skips itself,
with a line, when there is no aowlc to measure.

That tier found `{.packed.}` being dropped here entirely — a packed object was 24
bytes against nimony's 10, with every field after the first at a different
offset. It compiled, it ran, and it disagreed with the compiler about layout.

## License

MIT.
