# Compressing huge values

**Status: DESIGN.** Nothing here is built. It follows a finding of the Phase 2 dual-mode stress run
(2026-11-05), and is meant to come *after* the current four-phase speed-up round, as its own piece of
work.

It extends **Compressing looped provenance** (which compresses *cruxes*) to *values*, using the same move
**The first-class iterator** made for loops. It leans on **Provenance and the crux** and **CodeItem goes to
code**.

## What the stress run found

The dual-mode stress harness (`Acceptance Tests (Slow)/Provenance Dual-Mode Stress.swift`) runs random
programs of up to 5,000 tokens under limits from PlungeGP's search settings up to "a server with RAM to
spare" (1,000,000 steps, size limits ×100, 200 MB live weight). Its largest states were **code blocks
about 965 levels deep holding about 200 million units of content** on a single interpreter. Seed 398 is
the canonical one: `DualModeStress.check(seed: 398, …)` rebuilds it exactly.

Nothing about those values is wrong. They are legal, bounded by `maxItemWeight`/`maxLiveWeight`/
`maxCodeDepth`, and both recording modes agree on them. What they expose is that everything which
*walks* a value pays for its full expansion:

- **`pretty()` costs size × depth.** It renders a block by joining its children's renderings, so every
  character is copied once per enclosing level. On seed 398 that is effectively unbounded. Hashing a run
  through `pretty()` stalled the stress harness for over ten minutes, and the harness now walks structure
  directly instead.
- **Walking a copied block visits every path.** Copies share storage (a block appended to itself holds two
  references to one array), so the stored structure is a DAG, and a walk over it is exponential in the
  number of self-copies. The harness's call walk needed a node budget to finish.
- **Depth costs stack frames.** That is now bounded (`maxCodeDepth` is enforced at push; see *Deep
  Structure Safety Tests*), but only by refusing the value, not by representing it better.

These huge values come from a handful of shapes, built by loops: **"X nested N deep"** (a wrap in a loop
body), **"N copies of X"** (dup/append in a loop), and runs of a repeated sub-block inside a larger one.
Those are exactly the shapes that have a compact description.

## The idea: what the iterator did, done for values

`IteratorItem` replaced an unrolled loop with **compact state plus the constructor that rebuilds it**:
`reconstruction()` records the constructor call, so an iterator's provenance stays O(1) however many
passes it has run, and its crux reads as the instruction that makes it.

A huge value can get the same treatment: **store a summary representation, and let a representative
instruction stand for it** in printed code and in cruxes.

```
today:    ( ( ( ( ( … 965 levels … 7 ) ) ) ) )         // printed in full, walked in full
proposed: ( 7 ) 965 .codeNest                          // prints, and reconstructs, as its constructor
          ( a b ) 1000 .codeRepeat                     // "N copies of X"
```

The instruction's semantics define the expansion. The compact form is how the value is stored, printed
and reconstructed. It is never a different value.

## Two levels, worth keeping separate

### Level 1: compress cruxes (no language change)

`CruxCompression.compressed(_:)` already turns a repeated trailing block into `( body ) N .execDoTimes`,
runnable with existing instructions. Generalizing it to find repeated runs *anywhere* in a crux, a
grammar compressor emitting nested `.execDoTimes` blocks, makes long cruxes compact and still runnable.

It could also replace over-budget **elision**. Today an item whose provenance exceeds `maxCallWeight` or
`maxCallDepth` loses its explanation entirely. A compressible history could keep a compact one instead.
(Elision must stay as the backstop for histories that do not compress.)

This needs no new instructions and no new value representation, so it is the place to start.

### Level 2: compress values

A `CodeItem` gains an internal representation with **run-length and nesting nodes**: "X repeated N",
"X nested N". New instructions (`.codeNest`, `.codeRepeat`, and string/vector analogues if the evidence
asks for them) define what those expand to, and are what a compressed value prints and reconstructs as.

What has to be got right:

- **Compress where it is cheap: at construction.** The operation that grows a value usually knows the
  shape. Wrapping a value already "nested N" gives "nested N+1", and appending a block to a copy of itself
  doubles a repeat. That is O(1), as `stepped()` is for an iterator. Finding repetition in *arbitrary*
  structure is expensive, so leave that to Level 1 (crux and display time).
- **Semantics stay on the expanded value.** Equality, `weight`, `flatSize`, `nestingDepth` and every size
  limit are defined on what the value expands to. Weight is already counted that way, so no limit moves.
  The compact form is an implementation detail with no observable effect except speed.
- **Walks must be compression-aware.** `pretty()` renders the compact form directly. Point indexing into a
  repeat or a nest is arithmetic, not a traversal. `flattenedLeaves`, `preorderPoints`, `isEqual` and the
  code instructions that walk points all need compact-aware paths, or they expand anyway. This is also the
  fix for `pretty()`'s size × depth cost.
- **Keep the new instructions out of random code by default.** They join the language, and so the search's
  vocabulary. Tag them `.cruxOnly`, the precedent the iterator constructors set (Roadmap #17), so they
  appear in cruxes and can be enabled for evolution deliberately.
- **Cruxes must round-trip, as fixed points.** The crux of a compressed value must rebuild the *same
  compact form*, as an iterator's reconstruction rebuilds the same iterator. The round-trip sweep, the
  composition sweep and the crux fuzzer cover the new instructions automatically once they are registered.
- **Both recording modes still agree.** The value parity sweeps and the dual-mode stress run must stay
  green: compression is a value representation, so it has to behave identically with provenance off.

## The first candidate: deep wrapping

The stress run's deepest states are "x nested N deep", built by `.codeWrapRoot` (Push3's `CODE.WRAP`) in
a loop body. Two ways to give that shape the iterator treatment, solving different halves:

- **A `.nesting` iterator kind**, like `.repeating` for the dup family: origin `x`, count `N`, each pass
  emitting `x` wrapped one level deeper. This fixes the *history*: its crux is its constructor, O(1),
  instead of a chain of wraps that runs into `maxCallDepth` and loses its explanation. But what it emits is
  still an N-deep block, and every stress-run failure was about the *value* (rendering at size × depth,
  release recursion, `maxCodeDepth` refusals).
- **Compression inside `.codeWrapRoot` itself** fixes the *value*. Evolved programs make deep blocks by
  wrapping in loops, not by calling a new instruction, so the compressor has to live in the wrap: wrapping
  a value stored as "x nested N" gives "x nested N+1", in O(1). This is construction-time compression,
  aimed at the one shape that dominated.

They meet in the printed form. **The representative needs no new instruction:**
`( x ) ( .codeWrapRoot ) N .execDoTimes` is already runnable Push. Replaying it re-wraps step by step, and
because the wrap compresses, the replay rebuilds the same compact value: the fixed point an iterator's
reconstruction has. A dedicated `.codeNest` would only be a shorter spelling. With nests stored compactly,
`maxCodeDepth` can go back to being a budget rather than the stack-safety bound it became in Phase 2,
because a compact nest costs no stack to release or render.

The `.nesting` iterator then stays optional: for programs that want each level as it is built, tagged
`.cruxOnly` like the other iterator constructors.

## Before building Level 2: measure what to compress

The shapes above are inferred from what huge states looked like, not from where they came from. Before
choosing which compact forms to add:

1. **Instrument the stress run** to record, for the largest item each program leaves, the instruction that
   produced it and its shape (nest depth, self-copy count, run lengths). A per-instruction histogram over
   a few hours of programs says which compact forms would cover most of the mass.
2. **Check against real search.** Run the same instrumentation over PlungeGP runs. The stress generator's
   "huge" regime is deliberately extreme, and the forms worth adding are the ones evolved programs reach.
3. **Start with the one or two forms that dominate.** "Nested N" alone would have covered seed 398.

## Open questions

- **Where does the compact form live: inside `CodeItem`, or as a separate item type?** Inside keeps the
  type system and the `.code` stack unchanged. A separate type is easier to reason about, but every code
  instruction would then have to accept it.
- **Should compression be canonical?** If two routes to the same value produce different compact forms,
  equality is unaffected but cruxes differ. Canonicalizing at construction keeps reconstruction a fixed
  point. Not canonicalizing is cheaper.
- **Do strings and vectors need it?** The stress run's huge items were code. Strings and vectors are
  bounded by `maxStringLength`/`maxVectorLength`, and a repeated string is already compact in memory.
  Add analogues only if the measurement finds them.
- **Interaction with Level 1.** Once values compress, a crux that rebuilds a compressed value is already
  short, so Level 1 matters mainly for histories rather than values. Whether that is enough to retire
  elision is a question for after both exist.
