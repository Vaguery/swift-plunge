# CodeItem goes to `.code`

*Design note, 2026-07-15. Not implemented — this is the thing to react to first.*

**Why:** the headline is not the crux gaps — it is that `Plushy`'s hand-maintained `extraOpens` table
stops being necessary. See "The actual point" below.

## The change

Three parts, in dependency order:

1. **`Interpreter.step()`**: a `CodeItem` popped from `.exec` is pushed to `.code` **intact**, rather than
   having its contents unwrapped back onto `.exec`. `unwrapCodeItem` disappears from the interpreter.
2. **The `.exec` instructions take their code arguments from `.code`**, not `.exec`, and push their
   results to `.exec` as they do now.
3. **A new `.codeDo`** — the traditional Push name, and currently absent from `PushInstruction`. Without
   it nothing can run a block at all (see below), so it is not optional.

## What it buys, measured

A spike of **part 1 alone** (three lines in `step()`, since reverted) was run to get real numbers rather
than guesses:

- **Four of the five known crux gaps close immediately**: `codeAppend`, `codeEq`, `codeItemIsEmpty`,
  `codeWrapRoot` all round-trip. The `knownGapsPendingCodeItemChange` assertion fired in the direction
  it was built to fire — *"these now round-trip, remove them"*.
- `execEq` remains, and needs part 2: `.exec` arguments are consumed from ahead in the program, so a
  postfix crux cannot reach them. Sourcing from `.code` makes postfix correct.
- **The blast radius is 9 test issues across 4 suites**, not the "every test that nests a block" I
  expected. Most tests either use flat programs or drive Behaviors directly via `doThis`, bypassing
  `step()` entirely.

The 9 break down as: the gap assertion above (working as designed); `CruxTests.crux can work through
contingent code` and two `ProvenanceTests` whose *programs* rely on a block unwrapping; and three
`InterpreterTests` that assert the unwrap semantics directly. All are expected consequences, and all
want part 2 before they can be rewritten sensibly.

It also fixes, for free, two things the provenance work had to leave alone: `unwrapCodeItem` currently
discards a block's `call` on unwrap, and an `.input` bound to a code block loses its `[.input3]`
provenance the moment it scatters. Both stop happening when the block stays intact.

## The actual point: `extraOpens` goes away

The crux gaps are a symptom. The motivation is `Plushy.destructivePlushy2push`, which carries a
**27-entry hand-maintained table** (`extraOpens`) mapping each exec instruction to how many implicit
`(` it must synthesise into the genome:

```swift
.execDoCount : 1,   .execIf : 2,   .execS : 3,   .execRot : 3,
.execDoRange : 1,   .execK : 2,    .execY : 1,   .stringIterate : 1,   …
```

It exists for one reason: **an exec instruction should run a *block*, not the single next
instruction.** So the genome layer fabricates the parentheses that make the body a block, and the count
has to be right per instruction, and it has to be maintained as the language drifts. It is exactly the
kind of table that rots — it must already be re-checked against every new exec instruction, and nothing
enforces that.

Sourcing `.exec` arguments from `.code` dissolves the requirement rather than automating it. A block
lands on `.code` simply by *being a block*, so the body is a block by construction, and the table has
nothing left to assert. The positional coupling goes too: today the body must sit syntactically
adjacent to its instruction, because the implicit `(` is inserted right there. After the change, a block
need only be **somewhere before** the exec instruction fires — it will be waiting on `.code`.

This also feeds the crux. A body that is a first-class block on `.code` is a reusable unit with its own
provenance, rather than a run of items the genome layer happened to fence off.

## Code is data until run

This is the part with teeth, and it is not a side effect — it *is* the change.

```
1 2 .intAdd                    →  .int has 3
( 1 2 .intAdd )                →  .code has the block; nothing runs
( 1 2 .intAdd ) .codeDo        →  .int has 3
3 ( 1 .intAdd ) .execDoTimes   →  runs
```

Nesting in an evolved program stops being control flow and becomes structure. Every existing program
means something different. Plushy generates nested blocks freely, so this reshapes what the search
process is searching over — worth thinking about separately from the interpreter change.

## `.codeDo` must spread, not push

The obvious implementation is wrong, and the reason is worth writing down.

Push3's `CODE.DO` works by pushing the code item onto `EXEC`, where lists unwrap and execute. Here, a
`CodeItem` pushed to `.exec` goes **straight back to `.code`** by rule 1 — an infinite bounce.

So `.codeDo` must pop the top of `.code` and **prepend the block's contents to `.exec`**. Which is to
say: `.codeDo` *is* today's `unwrapCodeItem`, promoted from an implicit interpreter behaviour to an
explicit instruction. That is a pleasing outcome — the unwrapping still exists, but a program now has to
ask for it.

It should carry over `unwrapCodeItem`'s contingency propagation (`copy.isContingent =
netContingency(of: code, copy)`), which is the only thing that function does besides spreading.

**Provenance:** `.codeDo` is combinatory. It moves items from a block to `.exec` without changing any
value, so law 1 applies and it records nothing. The items it spreads keep the `call` they already had —
which is exactly the leak that unwrapping causes today, fixed by the block having kept its own `call`
while it sat on `.code`.

## How a loop re-supplies its body

The intricate bit. `execDoTimes` will take `[.int, .code]` and must both *run* the body once and
*re-supply* it to `.code` for the next pass. Both fall out of rule 1 rather than needing new machinery:

- To re-supply: push the `CodeItem` to `.exec`. It lands on `.code`. Done.
- To run: push the `CodeItem` followed by `.codeDo`.

So the continuation, `.exec` top→bottom:

```
[ body, .codeDo, newCounter, body, .execDoTimes ]
   │      │          │         │        └─ takes .int + .code — both now waiting
   │      │          │         └─ lands on .code, re-supplying the body
   │      │          └─ lands on .int
   │      └─ pops the block from .code, spreads its contents onto .exec → runs
   └─ lands on .code
```

Note this is *more* steps per iteration than today, not fewer — the opposite of the step saving that
came from unwrapping the three `CodeItem` continuations earlier. Worth accepting knowingly.

## Instruction-by-instruction

| Instruction | Takes today | Takes after | Note |
|---|---|---|---|
| `execDoCount`, `execDoTimes` | `.int, .exec` | `.int, .code` | |
| `execDoRange` | `.int, .int, .exec` | `.int, .int, .code` | |
| `execDoWhile`, `execWhile`, `execWhen` | `.bool, .exec` | `.bool, .code` | |
| `execIf` | `.bool, .exec, .exec` | `.bool, .code, .code` | |
| `execK` | `.exec, .exec` | `.code, .code` | |
| `execS` | `.exec, .exec, .exec` | `.code, .code, .code` | |
| `execY` | `.exec` | `.code` | |
| `stringIterate` | `.string, .exec` | `.string, .code` | the mouse |
| `vecXIterate` ×4 | `vecX, .exec` | `vecX, .code` | the mouse |
| **`execEq`** | `.exec, .exec` | **`.exec` — unchanged** | compares two *pending* items; see below |
| **`execQuote`** | `.exec` | **`.exec` — unchanged** | it wraps the top `.exec` item in a `CodeItem`; this is how a *non-block* exec item reaches `.code` at all |
| **`execPrint`** | `.exec` | **`.exec` — unchanged** | it prints the top `.exec` item |
| **`.codeDo`** | — | `.code` | new; the only way to run a block |

The `exec` combinators (`execDup`, `execSwap`, `execYank`, `execPop`, …) are not in the table because
nothing about them changes: they shuffle pending code on `.exec`, which still exists and still holds
whatever has not run yet. They pop from `.exec` directly, so they still see a `CodeItem` before
`step()` can route it to `.code` — worth a test (see below), not a change.

### `execEq` stays on `.exec`, and its crux gap stays open

Keeping `execEq` on `.exec` is right — it is asking "are the next two pending things the same?", which is
a question about `.exec`. But it does mean this is the one gap the change does **not** close, and the
reason is worth stating rather than leaving to be rediscovered.

Its crux must be **prefix** (`.execEq <A> <B>`), because `.exec` arguments are consumed from ahead. That
works only while `crux(A)` and `crux(B)` are each a *single* item:

```
.execEq 44 55                    ✓  reproduces
.execEq 0 5 .intAdd  X           ✗  execEq grabs `0` and `5`, not the sum and X
.execEq ( 0 5 .intAdd ) X        ✗  execEq grabs the BLOCK, and compares that instead
```

Bracketing does not rescue it: under this change a bracketed crux *is* a block, and comparing the block
is a different question from comparing the value it computes. Three ways out, none obviously best:

- **Leave it as a permanent known gap.** Honest, costs nothing, and `execEq` on a derived pending value
  is a rare shape.
- **Record nothing (provenance law 4b).** "Are the next two pending things equal?" is arguably a reading
  of *transient execution state*, exactly like `.execStackDepth` — in which case the honest crux is the
  literal bool, which reproduces perfectly and closes the gap. The wrinkle: unlike `StackDepth`, it does
  consume real arguments, so this is a judgement call about what `execEq` is *for*.
- **Restrict the recorded call to single-item argument cruxes** and elide otherwise. Precise but fiddly,
  and the elision rule would be unlike anything else in the law.

Worth a ruling before implementing; law 4b looks most defensible to me.

## Settled

- **`.codeDo` pops** (it consumes the block), matching today's `unwrapCodeItem`. A non-destructive form
  is not needed here: a planned general feature for non-destructive instruction execution will handle
  that distinction across the language, rather than `CODE.DO*` handling it for one instruction.
- **The loop expansions use `.codeDo`** rather than each instruction spreading its own body. One
  mechanism, and it puts the unwrap on the record where a crux can see it.
- **`execDup` on a pending `CodeItem` must be tested**: two copies, and *both* land on `.code` intact.
  It pops from `.exec` before `step()` can route the block, so this is the seam where the old and new
  behaviours meet.

## `codeDoIf` — better name than `codeIf`

The unimplemented `codeIf` is really a `.codeDoIf`: it consumes the code item and the top `.bool`; if
true the item is unwrapped and executed, if false the item goes back to `.code`. It can be built out of
the pieces already here — push `.codeDo` when the bool is true, replace the block otherwise — which is a
good sign the decomposition is right.

## Still open

- **What does `.codeDo` record?** There is a real tension here and I do not want to guess.

  By law 1 it records nothing: it moves items out of a block onto `.exec` without changing any value, and
  the items it spreads already carry their own `call`, so a crux reaches them through their own history.
  That is also what makes the change fix the current unwrap leak.

  But law 5 says a Behavior putting several results on one stack records the discard that surfaces each —
  and `.codeDo` puts N items on `.exec`. Applying it would give a block's k-th item the crux
  `<block> .codeDo k .execPopItems`. The snag: law 5 assumes results *come to rest* on that stack, and
  `.exec` items do not rest — they execute. Popping N exec items to "surface" one leaves it about to run,
  not sitting there to be read.

  So: does an item that came out of a block get its provenance *through* the block (`.codeDo` +
  `popItems`), or does it keep the history it already had? The two disagree, and the answer decides
  whether `.codeDo` is combinatory or generative.

- **The search layer.** 22 of the 24 unimplemented behaviors are `code*`, so at first the exec module
  carries the whole load of consuming code. This is less of a problem than it looks: `.codeIterate` is
  planned and addresses the nested-code-unreachable concern directly, and the genome change is the point
  rather than a casualty. But `.codeDo` plus a few `code*` instructions may want to land together.

## Where this is heading

Recorded so the change is not designed too narrowly. `.code` becomes a **pool of reusable subroutines**,
not just a place blocks sit. Planned work on top:

- Instructions that extract an item's **crux** and produce a `CodeItem` from it — the
  `codeFuncFrom_Crux` family sketched in `Code instruction planning.markdown` — and then curry that into
  a "function" by removing a leaf. This is the payoff the whole provenance exercise is for: a crux is
  runnable source, so it can become a first-class code value.
- `.codeIterate`, which gives nested code a way to be reached.
- The `IteratorItem` upgrade to a first-class type with its own stack and combinators.
- A general non-destructive execution feature (see `.codeDo` above).

Together with the expanded `code*` instruction set, these are what make the language more functional —
the CodeItem change is the enabling step, not the whole story.

## Sequencing

Part 1 and part 3 are a pair: rule 1 makes blocks unreachable without `.codeDo`, so landing part 1 alone
leaves the language unable to run nested code. Part 2 is separable and closes `execEq`.

The provenance work is done and does not block this. It leaves the exec behaviors much smaller than they
were — `execDoRange` went from ~15 provenance lines to ~2 — which is most of what makes this tractable:
the continuations are already spread as explicit Routers rather than hidden inside `CodeItem` wrappers
that this change would have broken.
