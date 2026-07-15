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

  Note for readers of an earlier draft: child-item `index` tags are gone (the
  field no longer exists), and no exec continuation is wrapped in a code block
  any more — every one is spread as loose items. Under our provenance law
  (`Items.swift`) an exec instruction's results are *combinatory*: body copies
  and re-pushed continuation tokens leave values where they already were, so
  they record no `call` at all. The one exception is a loop counter, which is
  genuinely derived; see `IteratorItem`.

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

### `execDoRange` — iterate an index across an inclusive range
*Equivalents:* `EXEC.DO*RANGE`, `:exec-do*range`, `exec_do_range`

**Pops:** `destination : INT` (top), `current : INT` (second), `body : EXEC` (top of exec).
**Effect:** runs `body` once for each integer from `current` toward `destination`
**inclusive**, stepping by +1 or −1. Before each pass the loop index is left on
the `INT` stack so `body` can read it.

**Canonical:**
- **Base case** — if `current` and `destination` differ by 0 or 1: push `current`
  to `INT` and run `body` once; no recursion.
- **Recursive case** — otherwise, arrange the exec stack so that this pass's
  index reaches `INT`, then `body` runs, then a recursive `execDoRange` fires
  with `current` stepped one unit toward `destination` (same `body`, same
  `destination`). Iteration proceeds until the base case.
- **Overflow safety** — the base-case test is `current − destination` within 1;
  it must not trap when the bounds are `INT.min`/`INT.max` (their difference
  overflows, and a naive `abs` traps). Treat an overflowing difference as "far
  apart" → recursive case.

*Oracle:* `execDoRange doesn't loop if the counters are the same`,
`execDoRange loops if the start and end are different by 2+` (13-step trace
fixing exact ordering), `execDoRange handles extreme bounds without trapping`.

**This implementation** *(informative):* the recursive continuation is spread as
loose exec items `[ current, body, nextCounter, destination, execDoRange, body ]`
(not wrapped in a code block). `isContingent` is the net contingency of the two
int args. Only `nextCounter` records provenance — everything else here is
combinatory. Its `call` is a single folded `IteratorItem`, so a counter's history
stays one node deep however many passes the loop makes.

---

### `execDoCount` — run a body a counted number of times
*Equivalents:* `EXEC.DO*COUNT`, `:exec-do*count`, `exec_do_count`

**Pops:** `count : INT` (top), `body : EXEC`.
**Canonical:** rewrites itself into an `execDoRange` from current index `0` to
destination `count`, with the same `body` — i.e. it delegates counting to
`execDoRange` (so the loop index is available on `INT`, running from 0 upward).
If `count < 1` no loop is created (the count and body are returned to exec; no
iteration).

*Oracle:* `execDoCount creates an execDoRange continuation when counter > 0`
(shows the rewrite to `[ 0 3456 .execDoRange body ]`),
`execDoCount doesn't loop if the index < 1`.

**This implementation** *(informative):* emits literal `0`, `count`,
`execDoRange`, `body` onto exec. All four are combinatory or literal, so none
records provenance — the `0` is the literal `0` whatever the arguments were, and
so is its own crux. Iteration total follows from `execDoRange`'s inclusive
semantics — defer to the trace.

---

### `execDoTimes` — run a body N times, index discarded
*Equivalents:* `EXEC.DO*TIMES`, `:exec-do*times`, `exec_do_times`

**Pops:** `count : INT` (top), `body : EXEC`.
**Canonical:** like `execDoCount` but the loop index is **not** left for the body
to use — semantically "do `body`, `count` times." If `count < 1`, no iteration.
Each pass decrements `count` and re-invokes `execDoTimes` until it reaches the
non-positive base case.

*Oracle:* `execDoTimes doesn't loop if the counter is not positive` (tests both
−5 and 0), `execDoTimes loops if the counter is positive` (shows the
`body count-1 .execDoTimes body` continuation).

**This implementation** *(informative):* the recursive continuation
`[ body, count−1, execDoTimes, body ]` is spread as loose exec items, like
`execDoRange`. It used to be wrapped in a code block that `.exec` unwrapped on the
following step; spreading it makes the co-arity of 4 visible and removes that
extra step, so each pass now arrives one step sooner. Only `count−1` records
provenance (a folded `IteratorItem`); the rest is combinatory.

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
