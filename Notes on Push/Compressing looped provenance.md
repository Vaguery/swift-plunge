# Compressing looped provenance

**Status: BUILT at the push boundary (2026-11-07), steps 2–4 below.** `CruxCompression.folded(_:)`
folds a history that is over budget, when it is one loop's chain, into `seed ( body ) K .execDoTimes
.codePop`, and a chain that grows again joins its fold (`K` becomes `K + M`). `Interpreter.push` tries
it before eliding. `maxIterations` was deleted (2026-11-08). What was learned building it:

- **Loops were not what the fuzz elided.** Every elided history was a *shared* one (a non-destructive
  read's arguments reused, fib(N) leaves for N steps); that is solved by `CruxSharing`
  (*Provenance and the crux* § Sharing). Folding is for chains deeper than `maxCallDepth`, which random
  programs at a 3,000-step limit never reach; a fourth fuzz case holds histories to 50 levels to make
  them fold (0.4% of its items run a folded loop, all replay).
- **`.codePop` is part of the fold.** A finished loop hands its body back to `.code`, and the crux must
  leave only its item.
- **The hand-back was early.** It landed on `.code` *with* the last pass, so a body that reads `.code`
  saw its own loop's body on that pass only, and `( B ) K .execDoTimes` was not `B` K times. The body
  now waits on `.exec` under the last pass (`iteratorFarewell(_:after:)`). Found by that fourth case: a
  `.codeNthPoint` chain replayed one level short.
- **Matching is by structure** (`sameHistory`, bounded), and the fold is a function of the history
  alone, so a replay folds at the same level. Levels must be identical: a chain whose levels alternate,
  or progress (`.execDoCount`'s index), is not folded and is still elided past the budget.
- **The replay budget** follows `CruxCompression.replaySteps`, not the crux's length.

*The design as written before it was built follows.*

**Was: PROTOTYPE.** `CruxCompression.compressed(_:)` collapses the exact-repeat (`.execDoTimes`) case,
with a round-trip test (`CruxCompression Tests.swift`). Not yet integrated into `crux()` rendering or the
push boundary, and `maxIterations` is still in place. This note is the design; the prototype proves the
central claim so the rest can be built against a working reconstruction.

It is the sequel to **Keeping loops human-sized** (which argued for `maxIterations = 100`) and leans on
**Provenance and the crux** and **The first-class iterator**.

## The problem this removes

`maxIterations` clamps a counted loop's *claimed* span to ~100 passes. Re-read its own justification: the
clamp "does not buy safety (`stepLimit` had that); it buys COMPLETION" — a loop that finishes is one a
human, and `crux()`, can read. The reason a *time-bounded* loop cannot be read today is that `crux()`
reconstructs the **claim** (the iterator's declared span), and a claim cut off by `stepLimit` re-runs to
different debris. So the loop's length is capped not for memory and not for time, but to keep its
reconstruction honest.

That is the thing a better crux composition takes over. If the crux records **the passes that actually
ran** — compactly and reconstructably — the clamp has nothing left to do, and a loop is free to run until
`stepLimit`.

## The shape, from a real loop

`crux()` flattens an item's history to a runnable leaf sequence. The canonical fold
`0.0  N  ( 1.0 .doubleAdd )  .execDoTimes` produces exactly:

```
n=3   ( 0.0 1.0 .doubleAdd 1.0 .doubleAdd 1.0 .doubleAdd )
n=5   ( 0.0 1.0 .doubleAdd 1.0 .doubleAdd 1.0 .doubleAdd 1.0 .doubleAdd 1.0 .doubleAdd )
n=200 …clamped to 100 body-repeats (value 100), 201 leaves…
```

`seed` followed by the body block `1.0 .doubleAdd` repeated once per pass. Linear in the lap count, and —
because `.execDoTimes` never shows the index to its body (the whole difference from `.execDoCount`) — the
block is **identical** every pass. That is a run-length problem.

## The rewrite

Detect the longest repeated trailing block (period `P`, `N` copies) and replace it with a counted loop:

```
seed  block×N   →   seed  ( block )  N  .execDoTimes
```

This satisfies the provenance law by construction — it is runnable Push, and running it reproduces the
value (`CruxCompression Tests` runs both the original and the compressed crux and asserts equal results).
Its size is `O(block)`, not `O(N)`, so it never approaches `maxCallWeight` and is never elided. The
`IteratedCall` node people reach for is just this: a body, a count, and the loop instruction that pairs
them — and for iterator-driven walks it can *be* the iterator, which already carries origin/destination/
stride/body.

Matching is by **value equality** (`isEqual(to:)`), which is provenance-agnostic — correct here because
crux leaves compare by value, and the block's leaves (`1.0`, `.doubleAdd`) are literals. The fundamental
period wins (ties → smallest), so `1.0 .doubleAdd` is preferred over `1.0 .doubleAdd 1.0 .doubleAdd`.

## Why two passes, not per-lap

Loops are continuation-driven: `.execDoTimes` builds a counting iterator and hands off to `.iteratorPlay`,
which advances one pass and re-pushes itself on `.exec`. No single behaviour invocation sees all `N`
passes, so there is no clean per-lap hook to seal the accumulator. The composition therefore runs **after
the fact**, over the finished crux — which is also what makes it construct-agnostic: anything that leaves
a repeated leaf run compresses, regardless of which instruction drove it. The cost is a walk of the crux;
that performance is the accepted trade.

## Retiring `maxIterations`

With actual-lap recording in place the clamp is redundant, and its removal becomes the payoff:

1. **Prototype (done).** `CruxCompression.compressed` + round-trip test, `.execDoTimes` exact-repeat case.
2. **Compose at the crux boundary.** Apply compression wherever a crux is rendered or stored, so long
   loops read compactly. No interpreter change; purely additive.
3. **Compose at the push boundary.** In `elidingOverBudgetProvenance`, try compression *before* eliding —
   turning today's lossy cap on `callWeight` into a lossless one. This is what bounds the *stored*
   provenance losslessly.
4. **Retire the clamp.** With (3) in, `clampingIterations` / `maxIterations` can go: a counted loop runs
   to `stepLimit`, and its crux records the laps that completed. Keep `maxIterations` as an optional
   *readability* preference if wanted, but it is no longer load-bearing. **Done**: off by default
   2026-11-07, deleted outright 2026-11-08.

## The harder cases, deferred honestly

- **Varying index (`.execDoRange`, `.execDoCount`).** The body block includes the per-pass counter, so
  consecutive blocks are *not* equal — they progress. This is the "algebraically increasing" case:
  recognise a block that is identical except for one leaf advancing by a constant stride, and record the
  progression. Tractable, but a real extension of the exact-repeat matcher.
- **Iterator/collection walks.** Already bounded by `maxVectorLength`/`maxStringLength`, so less urgent;
  when compressed, the node is the iterator itself rather than a synthesised `.execDoTimes`.
- **Recursion (`.execY`) and hand-rolled loops.** No loop object and possibly a *tree*, not a linear
  chain, of provenance. General repeated-subtree / period mining. The hard tail — leave on the existing
  elide path.
- **Nested loops.** Compose innermost-first: an inner loop compresses to a block, which an outer loop
  then sees as its repeat unit.
- **Mid-pass cut-off.** If `stepLimit` halts inside the `K+1`th body, record `K` *completed* laps; the
  reconstructable value is the post-complete-pass one — a defined answer, occasionally one pass behind the
  live stack.

## Open questions

- Where the canonical compression lives once past prototype — a method on the crux, a step in the
  recorder, or a pass the `Runner` offers — and whether it should be always-on or opt-in.
- Whether the push-boundary integration (step 3) should compress *every* over-budget item or only those
  whose history is a clean repeat, falling back to elision otherwise (probably the latter).
- The progression matcher for `.execDoRange`: how general to make it before it stops paying for itself.
