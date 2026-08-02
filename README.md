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

Not yet lowered here: the full system runtime (strings/seqs/`echo`, GC objects),
which lives in the 54 KB `system` `.c.nif` module. Anything aowlc can't print
raises `aowlc: unsupported …` so gaps are visible, never silently wrong.

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
bash test/e2e.sh examples/hello.nim     # emit EVERY module, gcc-link, diff vs nimony
bash test/driver.sh examples/hello.nim  # the DRIVER (build + exec), not the raw printer
bash test/single.sh examples/hello.nim  # one TU alone vs all modules — separates a
                                        # codegen bug from a whole-module-emission one
```

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

## Test

```sh
npm test    # emits C from real hexer .c.nif, gcc-compiles, runs, asserts results
```

## License

MIT.
