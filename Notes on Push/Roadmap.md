# Roadmap and open questions

The single live list of what is unbuilt, undecided, or deferred. Individual notes hold the full argument
for each item; this is the index. When an item is finished or answered, strike it here and fold the
resolution into its home note.

Nothing here is urgent unless a dependency says so. Ordering within a section is rough interest, not
commitment.

---

## A. Language features not yet built

1. **`.points(into:)`** — the depth-first code-tree walk (a zipper). The architecture already admits it;
   reserved in an `IteratorItem.swift` comment. Wants `codeNthPoint` and a memoized point-count on
   `CodeItem` first. → *The first-class iterator.md*
2. **map / filter** — an accumulator field on the iterator plus a rule for reading what the body left
   (the "pseudofunction" work). Note `.vecFromIterator`/`.codeFromIterator` are **not** this — they
   collect projections and never run a body. → *The first-class iterator.md*
3. **`.sampling(steps:)`** — Double ranges, initialised by a step count or a stride. Also the
   "coarsening" mechanism §F wants. → *The first-class iterator.md*
4. **A real `.codeIterate`** — an honest name for the boxed-code walk `.execDupItems` is currently the
   first instance of. → *CodeItem goes to code.md*
5. **`codeDoIf`** — consume a block, unwrap it onto `.exec` if the bool is true, replace it on `.code`
   if false. Decomposes into pieces already present.
6. **The unbuilt `.code*` queries** — `codeContains`, `codeDepth`, `codeNthPoint`, `codeLengthPoints`,
   `codeWidth` — non-destructive by default under the query convention (Design Principles §5). This is
   the real `.code`-relief payoff.
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
    the difference (via contingency, or an `.xSieve` combinator), it is a language feature; if not, an
    implementation detail. → *Sieve arguments.md*

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

18. **`contingencySources` instruction set** — sibling to `PushInstruction.iterators`; TODO on
    `InstructionSets.swift`. Includes the long-standing sub-question: **do `DupItems`/`DupTimes` make
    their results contingent in themselves?**
19. **Deep identity in equality** — `xDup` copies an item's whole call tree, so same-value/same-history
    genuinely arises, but Push has no way to ask. → *Items.swift* "Equality is about values"
20. **Error-provenance inconsistency** — `.inputN`/`.intN` "not bound" errors record nothing, while the
    success path of the same instruction records `[.inputN]`. Explanatory value, not correctness.
21. **Vector elements have no provenance** — `VecIntItem.value` is a raw `[Int]`. The one place
    containment destroys history, against law 1b. Costs addressability, not correctness. **Blocks #23.**
22. **(marginal)** `RecordedTrace`/`RecorderSpec` comments claim crux retention that `AnyItem` drops.
23. **`codeFuncFrom_Crux`** — turn an item's crux into a `CodeItem`, then curry it by removing a leaf.
    The payoff the whole provenance exercise is for. Wants #21 first. → *Code instruction planning.markdown*

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

## G. Deferred infrastructure

29. **The runaway guard's exec scan is 256 items deep** (`Interpreter.runawayExecScan`), so a runaway
    whose body queues thousands ahead of its iterator is not diagnosed. Long deferred, still fine to
    defer.

---

## Resolved / overtaken (kept briefly so the old notes can be trimmed to point here)

- **First-class `IteratorItem`**, everything human-sized (the clamp, `maxIterations`, `.iteratorRestart`,
  the setters), the collectors (`.vecFromIterator`, `.codeFromIterator`), cycling (`laps`),
  `.iteratorQuote`, `.vecXCut`/`.stringCut`, non-destructive queries, the `Planner`/`.reads` requirement,
  `InstructionTag`, the Fibonacci genome, and the mix diagnostic — **all done.**
- **"A program cannot create a vector / the vector stacks are closed systems"** — **partly opened** by
  `.vecXConstruct` (shape from a vector) and `.vecFromIterator` (from anything an iterator walks). Fully
  open only for a from-nothing constructor. → *Stack economics.md* Part 1.
- **`vecXPushAll` vs `stringPushAllChars` disagreed on which end lands on top** — **resolved**,
  front-to-back everywhere (Design Principles §6).
- **The composition invariant "a fragment leaves its value and nothing else"** was an untested accident
  (old Sieve Q4) — **now a stated, tested rule** (Design Principles §1, `Composition Invariant Tests`).
- **Sieve Q1–Q3** (polymorphic collector enough? build the planner first? what bounds a sieve's cost?) —
  all answered; see *Sieve arguments.md*.
