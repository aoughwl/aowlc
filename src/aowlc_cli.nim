## aowlc_cli — nimony port: transpile a post-hexer `.c.nif` to C on stdout.
## Mirrors aifjs_cli.nim (sibling aowljs port); reads `.c.nif`, emits C.
when defined(nimony): {.feature: "lenientnils".}
import std/[syncio, os]
import nifcursors, nifstreams, programs
import emitc

proc stripCNif(fname: string): string =
  result = fname
  let n = result.len
  if n > 6 and result[n-6 .. n-1] == ".c.nif":
    result = result[0 .. n-7]

proc emitFile(path: string): string =
  var buf = parseFromFile(path)
  var root = beginRead(buf)
  result = emitModuleBody(root)
  endRead buf

proc usage() =
  write stderr, "aowlc: usage: aowlc <module.c.nif>\n" &
                "       aowlc --units <mod1.c.nif> <mod2.c.nif> …  " &
                "(one process, one prelude + each body)\n"

proc main =
  # `for p in commandLineParams()` does not compile in nimony: the returned seq is
  # a temporary and a loop cannot borrow from it. Bind it once.
  let params = commandLineParams()
  var paths: seq[string] = @[]
  var units = false
  var outDir = ""
  var skipNext = false          # the VALUE of `-o` is not an input path
  for p in params:
    if skipNext:
      outDir = p; skipNext = false
    elif p == "--units": units = true
    elif p == "-o": skipNext = true
    elif p.len > 3 and p[0 .. 2] == "-o:": outDir = p[3 .. p.len - 1]
    elif p.len > 0 and p[0] != '-': paths.add p
  if paths.len == 0:
    usage(); quit 2
  for p in paths:
    if not fileExists(p):
      write stderr, "aowlc: cannot read file: " & p & "\n"; quit 1

  # `setupProgramForTesting` points the emitter's module lookup at this
  # directory, which is how a foreign symbol's defining `.c.nif` is found.
  let dir = parentDir(paths[0])
  setupProgramForTesting(dir, stripCNif(extractFilename(paths[0])), ".c.nif")

  if not units:
    var outp = CPrelude
    outp.add "\n"
    outp.add emitFile(paths[0])
    write stdout, outp
    return

  # --units: emit SEVERAL modules in ONE process, each as its own translation
  # unit, which is exactly what a whole-program consumer does — aowli's mid-run
  # JIT calls `emitModuleBody` in a loop rather than forking this binary per
  # module, then compiles one TU per module (concatenating them is illegal:
  # several modules declare `struct RootObj_0_…` and C rejects the redefinition).
  #
  # It exists because that is the only way to reach a whole class of bug from a
  # shell: emitter state that leaks BETWEEN calls is invisible to a
  # one-module-per-process CLI, and the first such leak (a probe cache that
  # `resetEmitter` did not clear) silently stripped every cross-module
  # declaration from the second module onward. See tests/units.sh.
  #
  # Units go to `-o DIR` as unit_<i>_<name>.c; the file NAMES carry the order, so
  # a gate can compile each one separately and say which call went wrong.
  if outDir.len == 0:
    write stderr, "aowlc: --units needs -o <dir>\n"; quit 2
  var i = 0
  for p in paths:
    let body = emitFile(p)
    let nm = outDir & "/unit_" & $i & "_" & stripCNif(extractFilename(p)) & ".c"
    # `writeFile` is `.raises`, so nimony requires the try/except.
    try:
      writeFile(nm, CPrelude & "\n" & body & "\n")
    except:
      write stderr, "aowlc: cannot write " & nm & "\n"; quit 1
    write stdout, nm & "\n"
    inc i

main()
