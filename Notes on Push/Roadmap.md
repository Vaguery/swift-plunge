# Roadmap and open questions

The single live list of what is unbuilt, undecided, or deferred. Individual notes hold the full argument
for each item; this is the index. When an item is finished or answered, strike it here and fold the
resolution into its home note.

Nothing here is urgent unless a dependency says so. Ordering within a section is rough interest, not
commitment.

> **Cross-repo overview (2026-11-06):** PlungeGP's `Notes and Planning/Open directions.md` collates every open
> item from these notes, the app's notes and both repos' code, including the many interpreter items that
> have no number here. This Roadmap stays the authority for numbered language work.

---

## P. First priority (2026-11-07): provenance completeness

Every item on every stack must be recoverable from a runnable Push program derived from the run, and any part
that can't be derived must say so. The rule: a crux reproduces its value on its stack, and every literal that
stands in for a lost history is a marked **stand-in**: it runs as that literal, names its cause
(`.boolStackDepth_actuallyWas_4`), and appears in every downstream crux. The audit, the loopholes and the full
rulings are in PlungeGP's `Notes and Planning/Open directions.md` § First priority and § 6. Order of work:

1. ~~Stand-ins: the item type; state reads (law 4b) record them; elision leaves them. Remove `execEq` (#26).~~
   **BUILT** 2026-11-07: `StandInItem`; state reads, transient-state errors and interpreter diagnostics
   record `.observed` stand-ins, and elision leaves an `.elided` one. → *Provenance and the crux.md*
   § Stand-ins. `execEq` removed.
2. ~~Measure: a completeness probe, and the round-trip sweep always-on and large on its own seeded generator,
   with a loop-heavy mix.~~ **BUILT** 2026-11-07 (and `.execDoRange` became inclusive first, #25). The crux
   fuzz is always on, each seed in its own `withFuzzSeed` scope, 40 seeds × 5 programs under `.equalShares`
   and `.loopHeavy`, and `CruxCompleteness` classifies every item left on a result stack.
   **Baseline** (value stacks; `.error` is ~100% "missing args" stand-ins by design):

   | mix | items | derived | observed | elided | program literal | bound-value contents | unmarked |
   |---|---|---|---|---|---|---|---|
   | equal shares | 23,759 | 70.6% | 5.6% | 0.0% | 6.5% | **17.3%** | 0 |
   | loop-heavy | 85,529 | 76.7% | 5.8% | 0.2% | 2.5% | **14.7%** | 9 |

   182,202 replays, 0 broken, 0 cut off by the step budget. Fixed on the way: the iterator constructors' and
   setters' refusals and the `…FromIterator` refusals now record stand-ins; `.codeDoNthPoint`/`…Root` box a
   point as a new block and now record it as `.codeNthPoint`/`…Root` would; and a third stand-in reason,
   `.minted`, marks a constant an instruction supplies itself (the 0 `.execDoTimes`/`.execDoCount` count from).
   **Found:** the largest gap is not elision but **container contents with no history of their own** (next).
3. Provenance compression replaces elision (generalized `CruxCompression`, looped-provenance steps 2–4); then
   retire `maxIterations` (#24).
   **Found first (2026-11-07):** every history the fuzz elided was a *shared* one, not a loop. A
   non-destructive read leaves its arguments, so a loop over one builds each value from the two before
   it: a few dozen distinct nodes, weighing 10,000–20,000 as a tree (fib(N) after N steps). No elision
   was for depth, and lifting `maxIterations` changed none of them.
   **Sharing BUILT (2026-11-07):** `crux()` builds each shared node once and reuses it by dup and yank,
   as the program did (`CruxSharing`; § Sharing in *Provenance and the crux.md*); the push boundary
   measures that crux, not the tree, and weighs a kept history by it. Elided items 0 in all three mixes
   (were 0.0% / 0.2% / 1.3%); 0 broken; the fuzz takes ~53 s (was ~40 s).
   **Loop folding BUILT (2026-11-07):** a history over budget that is one loop's chain folds into
   `seed ( body ) K .execDoTimes .codePop` (`CruxCompression.folded`), joining an earlier fold as it grows;
   `maxIterations` off by default (#24), and deleted 2026-11-08. A loop's body now returns to `.code` *after* its last pass (it came
   back with it, so a body reading `.code` saw itself on that pass). A fourth fuzz case (loop-heavy,
   histories held to 50 levels) makes random programs fold: 0 broken in all four, about 460,000 replays,
   ~75 s. **Not folded:** chains whose levels alternate or progress (`.execDoCount`'s index); they are
   still elided past the budget (0.3% of items in the 50-level case).
4. Per-element provenance for vectors **and strings** (#21), as a parallel array filled only when recording.
   **Widened by step 2's finding to code blocks**: an item with no history inside a container that has one
   (a block bound to `.input3`, then unwrapped; the blocks the structural code edits rebuild along their
   path) comes out as a bare literal and loses its link to the container, so a crux can look input-blind
   when it is not. 15–17% of value-stack items. Candidate rule: when such an item is taken *out* of a
   container (`.codeDo`, the emit/iterate family), record it relative to the container (`C k .codeEmitNthRoot`
   for root element k). The 9 unmarked items in the baseline are this class; the fuzz records them as a
   known issue until this lands.
   **Code contents BUILT (2026-11-07)**: the containment law (`Containment.swift`; § Containment in
   *Provenance and the crux.md*). Bound-value contents and unmarked items both 0; derived 85.1% / 92.1%
   (was 70.6% / 76.7%); 0 broken. The fuzz now asserts both stay at zero.
   **Vector and string members BUILT (2026-11-07)**: a per-element slot array in the provenance box, filled
   only when recording; extraction hands back the member, else the address. A third fuzz mix,
   `.containerHeavy`, exercises them: elision 5.2% → 1.5%, derived 81.5% → 85.3%, 0 broken. Then a
   **piece table** (`Pieces`): origins stored as runs, each element addressed from its source; elision
   1.3%, derived 85.6%.
5. Opt-in history encoding in `AnyItem` (#22). **BUILT 2026-11-08** as `ItemArchive`, a separate type so
   the default envelope stays value-only: a node table, children first, each shared node written once (the
   identity `crux()` shares by). It carries `call`, nested items' histories (block contents, an iterator's
   origin/destination/body, a stand-in's value), members, and a remeasured weight. Decoding needs no
   interpreter or bindings; encoding a decoded archive gives the same table. Random programs' items
   round-trip (value, crux, measures) in all three mixes; their tables hold about 0.56 of the tree's
   nodes. Also fixed: `AnyItem` dropped an iterator's `laps`.
6. Crux-to-function, both forms (#23).

A representation-neutral derivation graph, for other GP representations, is a later project.

### Rulings on numbered items (2026-11-07; decided, not yet built unless struck)

- **#2** map/reduce: a map element whose function leaves no result passes through unchanged. **filter** is
  designed alongside (no result counts as false).
- **#9** member reads (`vecXNth`, `stringNth`, `xMax`/`xMin`) become non-destructive.
- **#11** sieve Q5 stays parked until matrices exist.
- **#12 ForestGenome and #15 (mix under Forest): dropped.**
- **#13** BB9 is kept, to be designed later.
- **#21** (**done**) element provenance: a parallel per-element array, filled only when recording. Strings too.
  *Representation:* **a piece table (built 2026-11-07, the user's suggestion).** Runs of one item that
  went in, or of a source container's positions, so an element born in a constant is addressed from the
  constant. Elements that went in one at a time stay one run each; grouping those is compression (step 3).
- **#22** (**done** 2026-11-08) opt-in history encoding: `ItemArchive`.
- **#23** both forms, as two instructions: substitute an input, and delete the leaf.
- **#24** (**done**) retire `maxIterations` once provenance compression lands. Off by default 2026-11-07;
  **deleted** 2026-11-08 (the setting, the push-boundary clamp, `IteratorItem.clamped(toPasses:)` and
  `promisedPasses`).
- **#25** (**done**) `.execDoRange` becomes **inclusive**: |span|+1 passes (`4 4` → 4; `4 7` → 7, 6, 5, 4). Today it makes
  max(1, |span|) passes. `.execDoCount`/`.execDoTimes` keep their pass counts.
- **#26** `execEq` is removed; `( A ) ( B ) .codeEq` asks the same.
- **#29a** closed: not taken.
- **#37** new types vs a richer `CodeItem` is decided when taken up.
- **Also:** build `codeDoIf` alongside `codeIf`; rewrite `Specifications/exec.md` to match the code; defer the
  Macros note's open questions as a block (the `.error` combinators keep their trap); "general non-destructive
  execution" is closed as subsumed by the query convention; open registration of consumer instructions and
  types is wanted, and any registered instruction must obey the crux rule and be covered by the round-trip check.

---

## A. Language features not yet built

1. ~~**`.points(into:)`** — the depth-first code-tree walk~~ **BUILT** (`codeIteratePoints`, the `.points`
   IteratorKind). → *Code instruction planning.md*
2. **map / filter** — apply a crux-function to each vector element. Concrete design done (approved, not yet
   built): one `BehaviorWithSideEffects` per op, **no iterator** (map/reduce produce one item — §4), a
   sub-`Interpreter` rebinds the function's `.inputN` holes per element. Note `.vecFromIterator`/
   `.codeFromIterator` are **not** this — they collect projections and never run a body.
   → *Map and reduce from a crux-function.md*
3. **`.sampling(steps:)`** — Double ranges, initialised by a step count or a stride. Also the
   "coarsening" mechanism §F wants. → *The first-class iterator.md*
4. ~~**A real `.codeIterate`**~~ **BUILT** — `codeIterateRoot` (root elements) and `codeIteratePoints`
   (whole tree). → *Code instruction planning.md*
5. ~~**`codeDoIf`**~~ **BUILT** as `codeIf` (bool + two blocks, run the chosen on `.exec`).
6. ~~**The unbuilt `.code*` queries**~~ **BUILT** — `codeContains`/`codeDepth`/`codeWidth`/
   `codeLengthPoints`/`codeNthPoint`/`codeNthRoot`/`codeIndexOfPoint`/`codeContainer`, all non-destructive.
7. **A multiplicative / doubling iterator** — would need an "operation" field; the additive `stride`
   cannot express it. → *Provenance and the crux.md*

## B. Non-destructive-query follow-ups

8. ~~**Retrofit the iterator `Peek` getters** to cleanup-pop cruxes.~~ **BUILT** (noted 2026-11-06):
   `.iteratorPeekStride` and `.iteratorPeekLaps` record through `Behavior.reading`
   (*Iterator Behaviors.swift*; see also Resolved, issue #26). They already leave debris on the
   argument stack — the first latent violators of the composition invariant (Design Principles §1) — and
   `Behavior.reading` fixes them with the same helper the queries use.
9. **Borderline element-access / selection** (`vecXNth`, `stringNth`, `xMax`/`xMin`) — an opt-in second
   wave if "a query does not destroy its object" is judged to extend to reads that return a *member*
   rather than a fact.

## C. The sieve — parked, justified by matrices alone

10. **The sieve itself**, for matrix multiplication (find an N×4 to a 4×3). One more `Requirement` kind
    (`.reads` already showed a fifth slots in cheaply). → *Sieve arguments.md*
11. **Q5 — should a sieved argument be visible to a program?** Found, not taken: if a program can tell
    the difference, it is a language feature; if not, an implementation detail. The contingency half of
    this question is gone with `.isContingent` (#23a), so an `.xSieve` combinator is the only remaining
    way a program could ask. → *Sieve arguments.md*

## D. Genome and search

12. **ForestGenome** — the evolvable genome: block lengths carried as genes, on the shared
    `BlockPacking`. Placeholder exists (since 2026-07-19 in PlungeGP's `Genome Reference/`, not here). → *Stack economics.md* Part 3
13. **BB9 genome** — placeholder, undesigned. (Worth keeping alive? — flagged as marginal.)
14. **A genome-length sweep** — the obvious next diagnostic; the Fibonacci cliff makes length
    high-leverage. → *Stack economics.md* Part 3 "does not answer"
15. **Re-run the mix diagnostic under ForestGenome** — the Part-3 proportions may not hold once
    code-fraction is a free gene rather than a side effect of length.
16. **A human-scaled number distribution in the genome** — the *other half* of loop-sizing. The clamp is
    only a backstop; a search still needs counts to *tend* small, which is a genome hyperparameter. →
    *Keeping loops human-sized.md*
17. **A `crux-only` instruction set** — the ~12 `iteratorFromX` constructors want ~7 arguments and starve
    ~100% of the time, so they are dead weight in an evolvable genome. `InstructionTag` now exists;
    tagging this set is the remaining step. → *Provenance and the crux.md* TODO
    **Tag BUILT** (noted 2026-11-06): `.cruxOnly` is on 15 constructors (13 `iteratorFrom…`, 2
    `iteratorRepeating…`), asserted in *Instruction Tag Tests*. What's left is on the consumer side: nothing
    in PlungeGP reads the tag yet, and its `essential` preset still includes nine of them.

## E. Provenance open questions → *Provenance and the crux.md*

18. ~~**`contingencySources` instruction set**~~ — **dropped with `.isContingent`** (#23a). The set only
    had meaning as a classification of the flag, so it went with it, and so did its sub-question about
    whether `DupItems`/`DupTimes` make their results contingent in themselves. The `InstructionSets.swift`
    TODO that described it is deleted.
19. **Deep identity in equality** — `xDup` copies an item's whole call tree, so same-value/same-history
    genuinely arises, but Push has no way to ask. → *Items.swift* "Equality is about values"
19a. **~0.05% of crux claims failed under a long fuzz** (issue #27) — **resolved, 95 → 0.** Almost all of
    it was the checker, not the language: `brokenClaim` re-ran each crux under the *program's* `stepLimit`,
    but a crux flattens a call DAG per path and is routinely far longer than the run that built it, so the
    reconstruction was cut off and compared against a half-finished stack (93 of 95). Two more were the
    size caps refusing the interpreter's own reconstruction, fixed by relaxing them for replay
    (`InterpreterSettings.reconstructing`) — the caps bound a population's throughput, and a
    reconstruction is one individual explaining itself. The last was a real provenance bug: a **cycling**
    walker recorded itself cursor-first, and a cursor live at `laps == 7` is past the end at the
    `laps == 1` a constructor starts with, so the rebuild was refused as spent. It now builds at cursor 0,
    sets laps, then carries the cursor. → *Design Principles.md* §1

*#20–23 were dropped by accident in the #27 commit (`81af0cd`) and are still cited elsewhere; restored
2026-11-06 with their original text and a current status.*

20. **Error-provenance inconsistency** — `.inputN`/`.intN` "not bound" errors record nothing, while the
    success path of the same instruction records `[.inputN]`. Explanatory value, not correctness.
    **FIXED since:** both record `[InstructionItem(name)]` (*Input Behaviors.swift*, *Constant Behaviors.swift*).
21. ~~**Vector elements have no provenance**~~ — `VecIntItem.value` is a raw `[Int]`. The one place
    containment destroys history, against law 1b. Costs addressability, not correctness. **Blocks #23.**
    **DONE 2026-11-07:** members (§P step 4).
22. ~~**(marginal)** `RecordedTrace`/`RecorderSpec` comments claim crux retention that `AnyItem` drops.~~
    **DONE** 2026-11-08: `ItemArchive` encodes histories (opt-in), and the comments say which encoding
    keeps what.
23. **`codeFuncFrom_Crux`** — turn an item's crux into a `CodeItem`, then curry it by removing a leaf.
    The payoff the whole provenance exercise is for. Wants #21 first. → *Code instruction planning.md*
    **Depends on call trees:** a crux-consuming behavior must guard with `Interpreter.requiresProvenance(name)`
    and no-op when recording is off. The *CruxToFunction Diagnostics* found substituting an input is the
    faithful curry and deleting a leaf gives a repositioned function (*Map and reduce from a crux-function.md*);
    which one is canonical is open.
23a. **Remove the `.isContingent` flag entirely.** — **done**, see Resolved below.

## F. Decisions with a number or a semantics still open

24. ~~**`maxIterations = 100`** — the one judgment-call number; flagged for review.~~ **DELETED**
    2026-11-08, once a crux could fold a loop. → *Keeping loops human-sized.md*
25. ~~**`.execDoRange` inclusive of its destination?**~~ **DONE** 2026-11-07: inclusive, as in Push3
    (`4 7` → 7, 6, 5, 4; `4 4` → 4). It was max(1, |span|) passes, now |span|+1. → *The first-class iterator.md*
26. **`execEq` permanent known gap** — leave as-is / record-nothing (law 4b) / restrict to single-item
    argument cruxes. → *CodeItem goes to code.md*
27. **Coarsening (stride = span / budget)** for ranges — more expressive than the clamp; revisit when
    `.sampling` (#3) lands. → *Keeping loops human-sized.md*
28. **`.iteratorSetIterations`** — let a program raise its own loop ceiling (`stepLimit` still backstops).
    "Probably later." → *Keeping loops human-sized.md*
29a. **Un-type the `.code` stack** (let bare items of any type sit on `.code`, as Clojush's untyped code
    stack did). Would make tree leaves first-class needles with no singleton-unwrap convention, and
    simplify point access — but it severs the load-bearing assumption that *an item's type determines the
    one stack it rests on* (the basis of the crux/`PopItems`/round-trip system), reclassifies `.code` as
    the second heterogeneous stack, rewrites ~31 `as! CodeItem` casts, and reopens the quotes' semantics.
    A coherent, foundational change; **not taken** (singleton-unwrap, Design Principles §7b, gets the
    practical benefit at none of the cost). Recorded here as a real option for its own deliberate effort.

## G. Deferred infrastructure

29. **The runaway guard's exec scan is 256 items deep** (`Interpreter.runawayExecScan`), so a runaway
    whose body queues thousands ahead of its iterator is not diagnosed. Long deferred, still fine to
    defer.

36. **Compressing huge values** — store "X nested N" / "N copies of X" compactly, with representative
    instructions (`.codeNest`, `.codeRepeat`, tagged `.cruxOnly`) that a compressed value prints and
    reconstructs as, the way an iterator's crux is its constructor. Level 1 (generalized
    `CruxCompression`) needs no language change and comes first; Level 2 waits on measuring which
    instructions produce the stress run's huge items. After the current speed-up round.
    → *Compressing huge values.md*

37. **Structured data types** — think about Matrix, trees (n-ary, binary, red/black and AVL, heaps),
    spatial trees (quadtrees, octrees, k-d), graphs, sets and maps, with diverse instruction families and
    traversal iterator kinds, for graph algorithms and recursive processes. Likely waits on the type
    registry / `@PushItem` work, since adding a type costs ~28 edits today. → *Structured data types.md*

38. **Compressed stacks** — a live top window of real items over compressed segments (runs,
    progressions, cycles, named by the iterator kinds that would emit them), so low-complexity overflow
    is stored compactly; `.error` gets an archive (per-kind and per-instruction counts, marker flags)
    instead of a cap. First a stack-composition probe, to measure how compressible stacks really are.
    After the current speed-up round. → *Compressed stacks.md*

39. **Local variables (`.ref`)** — noted 2026-11-07; nothing built. Push will need a way to create,
    assign and read a local variable; earlier implementations used a `.ref` type that could hold any item.
    **How the interpreter stores the bindings is not settled.** Earlier variants used a dictionary keyed by
    `.ref`, a collection of stacks (one per variable), or a container item like a `.code` block. For
    provenance: if a read hands back the bound item's own history (binding as containment, law 1b), the
    variable is transparent under all three, and no stand-in is needed. If a read records only
    `[ref, .read]`, replay on a fresh interpreter finds no binding, so the assignment must travel with the
    crux (or a stand-in mark it). Questions *about* the bindings (bound?, how many?) are state reads, so
    stand-ins. A ref and a stand-in share a shape (one item under a name), and the `AnyItem` envelope keeps
    it generic so they can share it. → *Provenance and the crux.md* § Stand-ins
    *Two uses noted by the user (2026-11-07, while step 3 was built):* the shared crux (§ Sharing) would
    read better with variables: bind each shared value once and read it by name, instead of the
    `.xDup`/`n .xYankDup`/`n .xYank` bookkeeping. The planning (which nodes are shared, which uses can
    reuse) would stay as it is; only the writing would change. The same goes for a container a crux
    addresses repeatedly (a vector, string or block): put it in a variable and refer to it. That might
    not be less code in the end.

40. **Behavior arguments as a scratch array** — noted 2026-11-07 for exploration *after* the provenance
    batch; nothing designed. Instead of loading a Behavior's arguments into local Swift variables, load
    them into a sequential `[any Item]` scratch space that the closure reads as `$0`, `$1`, … . It changes
    no result by itself; the interest is that the scratch space could persist, or be manipulated, after
    the Behavior runs, which might allow interesting dynamics with local variables (#39).

41. **A map of Behaviors' inputs and outputs, as a DAG** — noted 2026-11-07, to explore *soon after* the
    crux rework is finished. An organized map of which stacks and types each Behavior reads and writes
    allows **backward-chaining** from the outputs a problem wants to the inputs that can produce them,
    for program synthesis. The aim is for the map to be a completely defined DAG. Open: whether every
    output is well defined, especially `.code` and `.exec` results, where several types are possible.
    (The reading/writing plans each Behavior already declares, `takes`/`reads`/`alsoNeeds` and its
    Routers, are where it would start.)
    **SURVEYED 2026-11-08** → *Behavior input-output map.md* (`BehaviorIOSurvey`, off by default): 488 of
    607 instructions have one fixed output signature; the size limits refused 24 of 82,115 results and never
    redirect one (a separate filter); body errors are domain conditions (28 of 31 replace the result).
    Not yet well formed: `.exec` continuations, `.iterator` as one type, and the shape effects of the
    direct-write combinators. A type-level map is a hypergraph with cycles; backward chaining builds the DAG.

42. **Every Behavior returns its intended output or an error** — **RULED and BUILT 2026-11-08** (three new
    `ErrorKind`s: `.emptyCollection`, `.notFound`, `.conversion`; clamping lives in `Position`) → *Error audit and
    Behavior classes (2026-11-08).md*. The ~23 silent failures, the arbitrary conversions
    (`doubleFromString` → 0.0, `charFromInt` mod 95) and the `-1` "not found" sentinels become errors.
    Character codes are Unicode scalar values both ways. Out-of-range indices **clamp** in every family
    (nth, set, cut, code points and gaps), replacing today's modulo, as Design Principles §12 says; only
    an empty collection errors. (A same-day ruling for modulo was reversed; negative indices counted from
    the end were considered and declined.) Item indices clamp to 0…N−1, gap indices to 0…N. Two gap bugs
    to fix with it: `vecXCut`/`stringCut` wrap mod N, so the tail gap is unreachable, and `xShove` clamps
    to 0…c−1 where it should be 0…c, so it never reaches the bottom and is a no-op on a two-item stack.

43. **Behavior classes** — **RULED 2026-11-08**, same note. Five classes: operations, structural rules,
    context reads, control (continuation writes) and channels. Declare each Behavior's class first, with a
    whole-set test; then replace `BehaviorWithSideEffects` with one narrower form per class. Not rewriting
    the direct-write combinators as pops and pushes.
    **Step 1 BUILT 2026-11-08** (`BehaviorClass`, declared with `as:`; plain Behaviors default to
    `.operation`, `BehaviorWithSideEffects` must say): 295 operations, 145 structural, 127 context reads,
    27 control, 13 channels; *Behavior Class Tests* check each declaration against what it does. Ruled:
    `execQuote` is an operation like the other `xQuote`s. `.exec` is special only contingently; Push's
    tradition is that code is data and data is code, as far as possible.
    **Step 2 BUILT 2026-11-08**: `BehaviorWithSideEffects` is gone. Each class has its own body
    (`BehaviorBody`): operations and control return `Router`s; structural rules return a `PositionEffect`
    (or a loop, for `DupItems`/`DupTimes`); context reads see a read-only `ReadContext`; control can also
    place and bury on `.exec` (`ControlEffect`); channels return a `ChannelWrite`. Only `act` mutates. All
    144 structural rules, plain dup/pop/swap/rot included, are declared effects. `execK` is control (it
    runs the kept block), not structural. `DeepDup`'s copy now goes through the validated push.
    Macros stay postponed, but come back with new types and instructions: see *Extensibility goal -
    compass and straightedge.md*. The user expects macros to get simpler as the representation is
    refined.

44. **Typed operation constructors** — noted 2026-11-08, not designed. A parameter-pack constructor,
    `operation(.intGT, takes: IntItem.self, IntItem.self, gives: BoolItem.self) { a, b in a > b }`, would
    write the casts and `Router` once, make an operation's result type data (#41), make partiality a
    `throw` (#42), and derive `call` from the declared arguments. A throwaway prototype compiled and ran
    under Swift 6. The macro-free half of what new types need (*Extensibility goal*).
    **Started 2026-11-08**: `Behavior.operation(_:takes:|reads:gives:)` in *Typed Operations.swift*, with
    `ValueItem` (a type's home stack and initializer), `Refusal` (a thrown error, auto-tagged `.fallible`),
    `WrittenOrder` (requirements and `call` from the declared order: stacks by first appearance, each
    deepest first, which reproduced every hand-written `call`), and `Behavior.gives` (the result stack, for
    #41). Converted: all int, double, bool and char operations (64), with identical messages and cruxes;
    release throughput unchanged. **Then, same day, three item-level forms**, whose bodies get typed items
    rather than values: `assembling` (a container plus its elements' origins, `Built`), `extracting` (an
    element taken out, traced when it kept a history, `Extraction`), and `splitting` (several results on
    one stack, each with its selecting crux). With them every string and vector operation that makes a
    value is typed, except the iterator-loop ones (pushAll, split, parseToLetters, iterate) and the context
    reads. `MemberItem`/`TracingItem` are the container protocols. Side effect: where keeping the recorded
    `call` puts a different stack first (stringDrop/Take, the char replaces, stringSetChar, non-int
    vecXSet, and the three string char queries), the requirement order changed, so a "missing args" error
    with several stacks short names a different one. **Code operations, same day**: `CodeItem` is a
    `ValueItem`; 15 code operations are typed (append, flatten, the point and gap edits, the size and
    search queries, `codeNthRoot`). Left: control; anything with an `IteratorItem` (not a `ValueItem`:
    its value is only a cursor, and its setters record their own reconstruction); `execQuote` (prefix
    crux); and the ones whose result embeds an argument item with its history (the scalar `xQuote`s,
    `codeWrapRoot`, `codePair`, the replace-points pair), plus the two code cuts. **Then built**:
    `composing` (items in, a value out, for a result that contains an argument with its history) and a
    `splitting` overload for types without element origins; those eight are typed too.
    **Status at the end of 2026-11-08:** 154 construction sites typed (106 `operation`, 30 `assembling`,
    8 `composing`, 6 `extracting`, 4 `splitting`). Hand-written by design: control, structural rules,
    context reads, channels, iterator operations (an `IteratorItem` is not a `ValueItem`), the
    iterator-loop deliverers (pushAll, split, parseToLetters, iterate), and `execQuote` (prefix crux). **Ruled and fixed 2026-11-08:** double comparisons follow IEEE 754 (any
    comparison with NaN is false). `doubleGTE`/`doubleLTE` and `vecDoubleGTE`/`vecDoubleLTE` had been
    "not less/greater than", so a NaN made them true: a silent bug.

## H. Collection coverage — deferred pieces → *Vector and Collection Coverage.md*

The clear-cut vector cases are built (comparisons, sub-vector search/replace, read-only constructors).
Left for later, with the arguments in the coverage note:

30. **Vector `split`** — prefer an explicit-separator `vecXSplitOn(separator)` (uniform, data-driven)
    over the "negatives-as-whitespace" analogy. Its own small proposal.
31. **`parseToLetters` vector analog** — an iterator emitting one-element vectors. Low value; add on a
    concrete use.
32. **Chunking** (fixed windows, overlapping/non-overlapping) — needs a **new `IteratorKind`**; `stride`
    is honoured only by `.counting` today (the `.points` kind now exists as a further precedent, and its
    `PointsEmission` mode shows a kind carrying an emission variant without new kinds). Overlaps #A.1.
33. ~~**Code gap-based ops**~~ **BUILT** (noted 2026-11-06; see Resolved, `CodeGaps.swift`). Original
    entry: `codeCutAtGap`, `codeInsertAtGap`, `codeFlattenRange`, `codeWrapPoints` —
    **the only unbuilt code instructions left**, postponed for a **gap coordinate model** design pass (how
    positions *between* points are numbered; child-array splice vs Plushy Open/Close-with-repair). The rest
    of the code batch is **built** (`Code instruction planning.md`, branch `codeTreeInstructions`): every
    `code*` instruction incl. the `.points` iterator and singleton-unwrap needles (Design Principles §7b),
    plus the `.exec` point-access family — `codeEmitNth{Point,Root}`/`codeDoNth{Point,Root}` and
    `codeIterate{Emit,Do}Points` (the three-way `PointsEmission`: boxed / whole / unwrapped).
34. **Pattern as a first-class item** — connects sub-vector search, the sieve (§C), and `.points`. A
    research direction, not an instruction.
35. **Naming reconciliation** (`stringSubstring`↔`subVec`, `stringSetChar`↔`set`, `stringConjChar`↔`conj`)
    — left as-is; renaming churns cruxes and tests for cosmetics.

---

## Resolved / overtaken (kept briefly so the old notes can be trimmed to point here)

- **First-class `IteratorItem`**, everything human-sized (the clamp, `maxIterations`, `.iteratorRestart`,
  the setters), the collectors (`.vecFromIterator`, `.codeFromIterator`), cycling (`laps`),
  `.iteratorQuote`, `.vecXCut`/`.stringCut`, non-destructive queries, the `Planner`/`.reads` requirement,
  `InstructionTag`, the Fibonacci genome, and the mix diagnostic — **all done.**
- **"A program cannot create a vector / the vector stacks are closed systems"** — **now opened**:
  `.vecXConstruct` (shape from a vector), `.vecFromIterator` (from anything an iterator walks), and the
  read-only `.vecXReadItems`/`.vecXReadStack` (from loose scalars, non-destructively) all make vectors.
  → *Stack economics.md* Part 1, *Vector and Collection Coverage.md*.
- **Vector coverage: comparisons, sub-vector search/replace, read-only constructors** — **done** (branch
  `collectionCoverage`). Deferred pieces in §H above.
- **`vecXPushAll` vs `stringPushAllChars` disagreed on which end lands on top** — **resolved**,
  front-to-back everywhere (Design Principles §6).
- **The composition invariant "a fragment leaves its value and nothing else"** was an untested accident
  (old Sieve Q4) — **now a stated, tested rule** (Design Principles §1, `Composition Invariant Tests`).
- **Sieve Q1–Q3** (polymorphic collector enough? build the planner first? what bounds a sieve's cost?) —
  all answered; see *Sieve arguments.md*.
- **The composition invariant had three unenforced cases** (issue #26) — **fixed.** Multi-result
  Behaviors stranded the sibling their selector did not want; the iterator collectors left the body their
  farewell hands back to `.code`; the recording peek getters left the iterator they hand back. All three
  reproduced the right value on top of debris, which is invisible to a check that reads only `.first` —
  so the fix is as much in the tests as the code. `Composition Invariant Tests.swift` now sweeps the whole
  language rather than the one family it was written for, and `brokenClaim` checks for debris. A 40-seed
  fuzz went from 971 broken claims to 95 (issue #27 is the remainder). → *Design Principles.md* §1, §16
- **The `.code` instruction set is complete**, and with it every name in `PushInstruction`: 608 of 608
  now have Behaviors. The last four were the gap-based ops, which waited on a model for naming a
  position *between* things in a tree rather than a point — now `CodeGaps.swift`, generalizing
  `codeCutRootAtGap`'s "N items have N+1 gaps" from the root array to the whole tree, so head and tail
  are addressable at every level. Five introspection instructions (`pushStepCount`, `errorStackDepth`,
  the three `errorMissing…Count`) landed alongside, with `ErrorKind` to make the counts exact.
  → *Code instruction planning.md*, *Introspection Behaviors.swift*
- **`.isContingent` removed entirely** (#23a, and with it #18's `contingencySources`). The flag marked a
  value whose *presence* depended on something the crux did not capture. Nothing consumed it: every read
  was either `Behavior.netContingency` propagating it to the next item or a test asserting it, and
  `crux()` never looked at it at all. Input-dependence is now read off the crux directly (`cruxMentions`
  → `CaseResult.cruxMentionsInput`). Removal touched 41 files, −1656/+485, and left the crux fuzzer's
  output byte-identical — which is the evidence that the flag was inert. Only **stochastic Behaviors**
  would revive the need; there are none, and none planned.
