# Push Language Specification — `exec` module (DRAFT / trial)

**Status:** trial conversion of `Exec Behavior Tests.swift` + `Exec Behaviors.swift`
into a language-agnostic spec. Purpose: let an LLM (or a human) reimplement or
audit these instructions in *another* Push interpreter, regardless of source
language, type names, or instruction names.

## How to read this

Each instruction has two layers, deliberately separated:

- **Canonical** — portable semantics every conforming Push interpreter should
  share. This is the actual specification.
- **This implementation** *(informative, non-normative)* — details that are
  artifacts of *our* codebase: provenance tracking (`call`) and contingency
  flags. Another interpreter may differ here and still be correct. Listed so a
  reader can tell signal from noise.

  Note for readers of an earlier draft, since two things changed under them:

  - **Code arguments now come from CODE, not EXEC.** A `CodeItem` the interpreter
    meets on EXEC comes to rest on CODE intact rather than having its contents
    scattered back onto EXEC, so code is data until a program asks for it with
    `codeDo`. Every instruction below that takes a *body* takes it from CODE, and
    its body must therefore reach CODE **before** the instruction fires — it need
    not sit adjacent to it. `execEq`, `execQuote` and `execPrint` still read EXEC:
    they are asking about *pending* items, which is a different question.
    `codeDo` is the only thing that unwraps a block, and is the old implicit
    unwrap promoted to an instruction.
  - **Argument order therefore reverses** relative to the old EXEC form. EXEC
    arguments were read forward from the program; CODE is a stack, so the
    last-written block is on top. `( then ) ( else ) .execIf` reads
    first-written-first, matching every other postfix instruction here.

  Also: child-item `index` tags are gone (the field no longer exists), and no
  continuation is wrapped in a code block — every one is spread as loose items.
  Under our provenance law (`Items.swift`) an exec instruction's results are
  *combinatory*: body copies and re-pushed continuation tokens leave values where
  they already were, so they record no `call`. The exceptions are a loop counter,
  which is genuinely derived (see `IteratorItem`), and `execEq`, which records
  **prefix** because its arguments are read from EXEC (law 3b).

**Notation.** Stacks are written top-first: `[ top … bottom ]`. `INT`, `BOOL`,
`EXEC`, `CODE` name stacks (map to your own type names — e.g. `INT`→`integer`,
`DOUBLE`→`float`). "Pops EXEC" means it consumes the next *pending* item of code.

**Naming.** Names below are this codebase's. Common equivalents in other
dialects are listed per-instruction (Push3 `EXEC.DO*RANGE`, klapaucius
`:exec-do*range`, propeller `exec_do_range`). A cross-dialect name table would
live at the top of a finished document.

**Oracle.** Each spec cites the test(s) that pin it down. Where iteration order
or counts are subtle, the cited test is the precise, executable ground truth —
prefer it over prose if they ever seem to disagree.

---

## Iteration instructions

### `execDoRange` — step an index across a range
*Equivalents:* `EXEC.DO*RANGE`, `:exec-do*range`, `exec_do_range`

**Pops:** `destination : INT` (top), `current : INT` (second), `body : CODE`.
**Effect:** runs `body` once for each integer from `current` toward
`destination`, stepping by +1 or −1. Before each pass the loop index is left on
the `INT` stack so `body` can read it.

**The destination is EXCLUDED**, which is worth stating plainly because an
earlier draft of this document (and the code's own comments) claimed "inclusive"
and were wrong. `4 7 .execDoRange` emits **7, 6, 5** — never 4. The rule is that
a pass stops the loop when `|destination − current| ≤ 1`, *having already
emitted* `current`, so the last index emitted is one short of the destination.
Equal bounds are the exception: they emit once. This differs from Push3, and
whether to change it is an open question — but it is what the tests pin, and any
reimplementation matching this document should match it.

**Canonical:**
- Emit `current` to `INT`, run `body`.
- Continue with `current` stepped one unit toward `destination` iff
  `|destination − current| > 1`; otherwise stop.
- **Overflow safety** — the difference must not trap when the bounds are
  `INT.min`/`INT.max` (it overflows, and a naive `abs` traps on `INT.min`).
  Treat an overflowing difference as "far apart" → keep looping.

*Oracle:* `execDoRange doesn't loop if the counters are the same`,
`execDoRange loops if the start and end are different by 2+` (a step-by-step
trace fixing exact ordering), `execDoRange handles extreme bounds without
trapping`, `execDoRange indices record origin and offset`.

**This implementation** *(informative):* **the counting is not expressed in Push
at all.** The instruction pops its bounds, builds an `IteratorItem` holding the
origin, the destination, the stride and a cursor, pushes it to the `ITERATOR`
stack, and emits a single `.iteratorPlay` token. Each pass then emits only its
index, the body, and a `.codeDo` — the bounds never return to `INT`, and no
recursive `.execDoRange` is ever rebuilt.

This is a deliberate encapsulation: a loop's state is the iterator's own for its
duration, readable only by stepping it or by the `.iteratorStart`/`.iteratorEnd`/
`.iteratorStride`/`.iteratorBody` getters. Another interpreter is free to keep
the Push-level recursion instead — the canonical layer above is what matters.

The index is the one derived value, and it records `[origin, offset, .intAdd]`,
so its crux is `7 -2 .intAdd`: bounded, and the same size however many passes
run. The iterator itself records how to rebuild it *by state*
(`.iteratorFromIntRange`), which is likewise O(1) because its origin,
destination and body never change.

---

### `execDoCount` — run a body a counted number of times
*Equivalents:* `EXEC.DO*COUNT`, `:exec-do*count`, `exec_do_count`

**Pops:** `count : INT` (top), `body : CODE`.
**Canonical:** counts from `0` toward `count`, leaving each index on `INT` — i.e.
`execDoRange` from `0` to `count`, which (the destination being excluded) is
exactly `count` passes, emitting `0 … count−1`. If `count < 1` no loop is created
and both arguments are returned.

*Oracle:* `execDoCount builds an iterator and plays it when counter > 0`,
`execDoCount runs its body exactly count times`,
`execDoCount doesn't loop if the index < 1`.

**This implementation** *(informative):* it used to *rewrite itself* into a
literal `0 count body .execDoRange` continuation and let that do the counting. It
now builds the same iterator `execDoRange` would and hands it to `.iteratorPlay`
directly, so the delegation is gone. `execDoCount` and `execDoTimes` now differ
in exactly one flag — whether the iterator emits its index.

---

### `execDoTimes` — run a body N times, index discarded
*Equivalents:* `EXEC.DO*TIMES`, `:exec-do*times`, `exec_do_times`

**Pops:** `count : INT` (top), `body : CODE`.
**Canonical:** exactly `execDoCount`, except the loop index is **not** left for
the body to use — semantically "do `body`, `count` times." If `count < 1`, no
iteration and the body is returned.

*Oracle:* `execDoTimes doesn't loop if the counter is not positive` (tests both
−5 and 0), `execDoTimes loops if the counter is positive`,
`execDoTimes runs its body exactly count times, silently`.

**This implementation** *(informative):* it used to count by decrementing a
counter it re-pushed onto `INT` every pass, which meant the count was visible in
Push even though the instruction's whole point is that it should not be. The
count now lives inside the iterator and never escapes: `execDoTimes` builds the
same iterator as `execDoCount` with its `emits` flag off. Nothing about the
counting reaches any stack.

---

### `execWhile` — repeat a body while BOOLs are true
*Equivalents:* `EXEC.WHILE`, `:exec-while`, `exec_while`

**Pops:** `flag : BOOL` (top), `body : EXEC`.
**Canonical:** if `flag` is **false**, consume both and stop (body does not run).
If `flag` is **true**, run `body` once and re-queue the loop: push `body`, then
an `execWhile` that will consult the next `BOOL`, then `body` again — so each
iteration executes the body and then re-tests the (next) top BOOL.

*Oracle:* `execWhile doesn't act if a false is found`,
`execWhile pushes several items back to .exec when true is found`.

**This implementation** *(informative):* the re-queued items are two body copies
and a freshly minted `execWhile` token — all combinatory, so none records
provenance. (They previously named `execDoWhile` in their `call`, following the
klapaucius continuation form.)

---

### `execDoWhile` — run a body once, then behave like `execWhile`
*Equivalents:* `EXEC.DO*WHILE`, `:exec-do*while`, `exec_do_while`

**Pops:** `flag : BOOL` (top), `body : EXEC`.
**Canonical:** always run `body` **at least once** (unlike `execWhile`, which may
skip it). After the first pass, if `flag` was true, continue as `execWhile`
against subsequent BOOLs; if false, stop after the single pass.

*Oracle:* `execDoWhile acts once even if a false is found`,
`execDoWhile is a lot like execWhile when a true is found` (5-step trace).

---

### `execWhen` — run a body once iff the top BOOL is true
*Equivalents:* `EXEC.WHEN` (klapaucius `:exec-when`)

**Pops:** `flag : BOOL` (top), `body : EXEC`.
**Canonical:** if `flag` true, run `body` once; if false, discard `body`. Not a
loop — a guarded single execution.

*Oracle:* `execWhen` (true → body remains for execution; false → body discarded).

---

### `execIf` — choose one of two bodies on a BOOL
*Equivalents:* `EXEC.IF`, `:exec-if`, `exec_if`

**Pops:** `flag : BOOL` (top), `then : EXEC`, `else : EXEC`.
**Canonical:** if `flag` true, run `then` and discard `else`; if false, run
`else` and discard `then`.

*Oracle:* `execIf` (tests both branches).

**This implementation** *(informative):* order — `then` is the exec item nearer
the top, `else` the next. Result keeps the chosen branch's contingency.

---

### `execY` — the fixed-point (recursion) combinator
*Equivalents:* `EXEC.Y`, `:exec-y`, `exec_y`

**Pops:** `body : EXEC`.
**Canonical:** push a self-reapplying continuation so `body` runs repeatedly:
leave on exec `body` followed by `( execY body )`. Running that block re-pushes
`execY body`, producing unbounded recursion unless `body` breaks it. This is the
primitive that makes open-ended recursion expressible.

*Oracle:* `execY` (4-step trace showing the `( .execY body )` regeneration).

---

### `execK` — keep the first of two, discard the second
*Equivalents:* `EXEC.K`, `:exec-k`, `exec_k` (the K combinator)

**Pops:** `keep : EXEC` (top), `drop : EXEC`.
**Canonical:** discard `drop`, run `keep`.

*Oracle:* `execK`.

---

### `execS` — the S combinator
*Equivalents:* `EXEC.S`, `:exec-s`, `exec_s`

**Pops:** `a : EXEC`, `b : EXEC`, `c : EXEC` (top to bottom).
**Canonical:** rearrange to `a c ( b c )` on exec — i.e. run `a`, then `c`, then
the block `( b c )`. (Classic S: `a` applied with `c`, and `b` applied with `c`.)

*Oracle:* `execS` (shows `[ a c ( b c ) ]`).

---

## Generic stack operations *(sketch — not exec-specific)*

`execDup`, `execPop`, `execSwap`, `execRot`, `execFlush`, `execStackDepth`,
`execStackIsEmpty`, `execYank`, `execYankDup`, `execShove`, `execDupItems`,
`execDupTimes`, `execDeepDup`, and the comparison `execEq` / literal-pusher
`execQuote` are **not** exec-specific — they are the uniform stack-manipulation
family instantiated for *every* stack. These are best specified **once** as a
parameterized template ("`⟨stack⟩Dup` duplicates the top item of ⟨stack⟩;
`⟨stack⟩Rot` rotates the top three; …") and then noted as available on `EXEC`.
A per-instruction page each would be wasteful and would obscure the one thing a
reader needs: the pattern is identical across types.

Two wrinkles worth a canonical note where EXEC differs from data stacks:
- On EXEC these ops operate on *pending code*, so e.g. `execDup` duplicates the
  next instruction/code-block to be run (a cheap way to repeat work).
- `execEq` compares two exec items structurally; *Oracle:* `execEq works with
  inputs (bug fix)` — an input token must be resolved/compared correctly, not
  treated as an opaque literal.
