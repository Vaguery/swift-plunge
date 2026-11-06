# Compressed stacks

**Status: TO THINK ABOUT.** A plan that was set aside on 2026-11-06 to finish the speed-up round. Nothing is
built. It follows *Compressing huge values* (which compresses individual values) and extends the idea to
whole stacks.

## Where it came from

`.error` is exempt from every size limit, so overflow reports can always land, and it therefore grows for a
whole run. The `errorCount*` instructions used to scan it on every call, which made two stress-run programs
take minutes. That is fixed by a lazy per-kind tally (`StackSet.errorCount(of:)`), but `.error` still has no
bound. It must not be capped or made writable: it is the program's external monitor, and the rule in
*Introspection Behaviors* is that errors arrive one way and never leave.

The proposal is to pair a stack with an **archive**: a compressed account of what falls below a live window.
The same structure could handle ordinary stack overflow when the overflow is low-complexity. 350,000 copies
of `[0.1 0.2]` is a run, not 350,000 facts.

## Part A: measure first, with a stack-composition probe

Before choosing representations, look at how diverse stacks actually are in arbitrary runs. Compressible
patterns were hard to see in the old stress tests, before iterators existed to name them.

- **Detector vocabulary: the iterator kinds.**
  - A run of identical items is a `.repeating` loop.
  - An arithmetic progression in `.int`/`.double` is a `.counting(stride:)` loop.
  - A short repeated cycle is an `.elements` walk with laps.
  - Detected segments print as the `IteratorItem` that would emit them, the notation cruxes already use.
  - The runaway guard's `runawaySymptom` already tests the top 256 for few-distinct values, period ≤ 8 and
    monotone runs, so it is the reference.
- **A `StackSegmenter`.** It covers a stack from the bottom up, greedily, with runs (k ≥ 3, `isEqual`),
  progressions (exact stride ≠ 0, or bit-identical double differences), cycles (period 2–16, at least two
  laps, partial last lap allowed) and literals. The cost is O(n·P) with adjacent comparisons only.
  Expanding its segments must give back the original items.
- **A probe acceptance test,** gated on `PUSH_PROBE_DIR`.
  - **Programs:** the throughput-benchmark programs and about 2,000 `DualModeStress.makeCase` programs
    across regimes.
  - **Snapshots:** every stack at 8 step marks, at the end, and whenever its depth doubles past 256.
  - **Measures:** depth; distinct values; coverage by each shape; segments; compression ratio; how much a
    frequency dictionary of the top 10 values would cover; and the depth-over-time profile (linear growth
    marks a loop).
  - **Outputs:** a CSV, a summary, and an examples file with the most and least compressible deep stacks,
    plus `.int` and `.string` samples, rendered as segments.
- **Questions for the data:**
  - Which segment kinds are worth having?
  - Does a frequency dictionary add anything beyond runs and cycles?
  - Does `.string` need its own shape, such as "each = previous + suffix" growth chains?

## Part B: the segmented stack (design, after the data)

- **A live top window of real items** (≥ 256) over a deque of **segments**: literal, run, progression, cycle.
  - **Why the window:** almost all traffic is at the top (`push`, `act`, `step`, recorders' top, second and
    count, the runaway guard's top-256 window), so those paths are unchanged.
  - **When it compresses:** at spill time, as an item crosses the window boundary and is compared against
    the last segment. That is O(1) amortized: construction-time compression, as *Compressing huge values*
    prescribes.
  - **Deep operations** (yank, yankDup, shove, deepDup, `bury`, Planner reads) find a segment by cumulative
    count and split it.
  - **Bulk operations** (popItems, flush, readItems, readStack, `recomputeLiveWeight`) work from
    per-segment counts and weights.
- **Semantics stay on the expanded stack.** `stackDepth`, equality, cruxes and both recording modes see
  exactly what an uncompressed stack would hold.
- **The decision the data has to inform: what the limits measure.**
  - `maxStackDepth` and `maxLiveWeight` bound expanded size today, so a compressed run would still trip
    both.
  - Letting compressible overflow through means splitting each limit into *stored* size (memory) and
    *expanded* size (what the program sees), and saying which one each limit bounds (Design Principles
    §13).
- **Equality and hashing.** No item is `Hashable`, and `isEqual` is O(size) for containers. Run detection
  only needs adjacent comparison. A frequency dictionary would need a fingerprint.

## The `.error` archive (the first application)

- **The live window** holds real `ErrorItem`s, so recorders' top and second, and messages near the top,
  are unchanged.
- **Below it, the archive** keeps:
  - per-kind counts (the current tally becomes part of it)
  - per-(kind, instruction) counts for starvation errors, whose instruction is already stored on the item
  - a capped frequency dictionary of other messages, with an "other" bucket
  - the first and last step of each key
  - whether each marker (`RUNAWAY:`, `MEMORY:`, `INVARIANT:`, `PROVENANCE:`) was ever seen
- **What survives:** `errorStackDepth` and `errorCount*` read live + archived counts. Nothing a program can do
  edits the archive, so the "never leaves" rule holds in the sense that matters.
- **To spell out:**
  - The archive's cost in `liveWeight`.
  - What the full message list becomes for tests and for the planned server Runner, which is meant to
    return the error stack.
  - Whether finer counts (by instruction) should become instructions of their own.

## Gaps found while exploring (not fixed)

- `insert`, `place` and `place(contentsOf:)` don't check `maxStackDepth`, so deepDup, `bury` and `codeDo`
  can exceed it.
- `requiresProvenance` prepends to `.error` without updating `liveWeight`.
