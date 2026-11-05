# Roadmap and open questions

The single live list of what is unbuilt, undecided, or deferred. Individual notes hold the full argument
for each item; this is the index. When an item is finished or answered, strike it here and fold the
resolution into its home note.

Nothing here is urgent unless a dependency says so. Ordering within a section is rough interest, not
commitment.

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

8. **Retrofit the iterator `Peek` getters** to cleanup-pop cruxes. They already leave debris on the
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
    `BlockPacking`. Placeholder exists. → *Stack economics.md* Part 3
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

## F. Decisions with a number or a semantics still open

24. **`maxIterations = 100`** — the one judgment-call number; flagged for review. → *Keeping loops
    human-sized.md*
25. **`.execDoRange` inclusive of its destination?** Currently exclusive (`4 7` → 7, 6, 5). A Push3
    compatibility question, deliberately left open. → *The first-class iterator.md*
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
33. **Code gap-based ops** — `codeCutAtGap`, `codeInsertAtGap`, `codeFlattenRange`, `codeWrapPoints` —
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
