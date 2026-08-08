#!/usr/bin/env node
// aowlc PRELUDE-PARITY gate.
//
// aowlc has two printers, and each carries its own copy of the C prelude:
// `PRELUDE` in aowlc.js and `CPrelude` in src/emitc.nim. Every gate we have
// compares the two printers on PROGRAM BEHAVIOUR — twoprinters.sh runs both
// against nimony's own output — which is exactly the comparison a prelude
// divergence can survive: a macro one printer defines and the other does not
// only matters for programs that reach it, and the corpus is finite.
//
// So compare the text. They are meant to be the same prelude, and the moment
// they are not, the difference is a fact about aowlc that nobody decided.
//
// A THIRD copy lives in aowlrt.h ("mirror aowlc's PRELUDE") — that one is
// deliberately a subset and is gated separately, by compiling it together with
// this prelude in both include orders (aowlabi/tests/aowlrt.sh).
"use strict";
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const jsPrelude = require(path.join(root, "aowlc.js")).PRELUDE;

// emitc.nim spells it as a triple-quoted string constant. Anchor on the whole
// `const CPrelude* = """..."""` form rather than on any line inside it, so a
// rename or a reflow fails loudly here instead of silently matching less.
const nim = fs.readFileSync(path.join(root, "src", "emitc.nim"), "utf8");
const m = nim.match(/const CPrelude\* = """([\s\S]*?)"""/);
if (!m) {
  console.error("aowlc prelude gate: FAILED — no `const CPrelude* = \"\"\"...\"\"\"` in src/emitc.nim");
  console.error("  (renamed or reshaped: this gate cannot find what to compare, which is a");
  console.error("   failure, not a pass)");
  process.exit(1);
}
const nimPrelude = m[1];

// Compare with trailing whitespace per line normalised away, and nothing else:
// the two literals sit in different languages, so a stray trailing space is not
// a divergence anyone should have to look at, while a missing #define is.
const norm = s => s.replace(/[ \t]+$/gm, "").replace(/\s+$/, "");
const a = norm(jsPrelude), b = norm(nimPrelude);

if (a === b) {
  const lines = a.split("\n").length;
  console.log(`aowlc prelude gate: aowlc.js and src/emitc.nim agree, ${lines} lines`);
  process.exit(0);
}

console.error("aowlc prelude gate: FAILED — the two printers' preludes differ");
console.error("  (-) aowlc.js PRELUDE   (+) src/emitc.nim CPrelude");
const al = a.split("\n"), bl = b.split("\n");
const seen = new Set(al);
const seenB = new Set(bl);
for (const l of al) if (!seenB.has(l)) console.error("  - " + l);
for (const l of bl) if (!seen.has(l)) console.error("  + " + l);
process.exit(1);
