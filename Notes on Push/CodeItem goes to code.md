# CodeItem goes to `.code`

*Design note, 2026-07-15. Not implemented — this is the thing to react to first.*

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
| `execEq` | `.exec, .exec` | `.code, .code` | closes the last crux gap |
| `stringIterate` | `.string, .exec` | `.string, .code` | the mouse |
| `vecXIterate` ×4 | `vecX, .exec` | `vecX, .code` | the mouse |
| **`execQuote`** | `.exec` | **`.exec` — unchanged** | it wraps the top `.exec` item in a `CodeItem`; this is how a *non-block* exec item reaches `.code` at all |
| **`execPrint`** | `.exec` | **`.exec` — unchanged** | it prints the top `.exec` item |
| **`.codeDo`** | — | `.code` | new; the only way to run a block |

The `exec` combinators (`execDup`, `execSwap`, `execYank`, `execPop`, …) are not in the table because
nothing about them changes: they shuffle pending code on `.exec`, which still exists and still holds
whatever has not run yet.

## Open questions

- **Does `.codeDo` pop or peek?** Push3 has both `CODE.DO` (pops) and `CODE.DO*` (does not). Starting
  with the popping form seems right; the other is cheap to add later.
- **Do the loop bodies need `.codeDo`, or should the exec instructions spread directly?** Pushing
  `[body, .codeDo]` reuses one mechanism and keeps the instructions simple. Spreading the contents
  directly is fewer steps but re-implements `.codeDo` inside each instruction. Recommend the former.
- **What happens to a `CodeItem` on `.exec` that a combinator put there?** `execDup` duplicating a
  pending block leaves two blocks on `.exec`; both will land on `.code` when reached. That seems right,
  but it is a behaviour worth a test.
- **`codeIf` already exists in the enum, unimplemented,** and under this model it and `execIf` are close
  to the same instruction. Worth deciding whether both survive.
- **The search layer.** 22 of the 24 unimplemented behaviors are `code*`. Until they exist, the exec
  module carries the whole load of consuming code, and Plushy's nested blocks are mostly inert data.
  That may be fine — or may argue for implementing `codeDo` plus a few `code*` instructions in the same
  pass.

## Sequencing

Part 1 and part 3 are a pair: rule 1 makes blocks unreachable without `.codeDo`, so landing part 1 alone
leaves the language unable to run nested code. Part 2 is separable and closes `execEq`.

The provenance work is done and does not block this. It leaves the exec behaviors much smaller than they
were — `execDoRange` went from ~15 provenance lines to ~2 — which is most of what makes this tractable:
the continuations are already spread as explicit Routers rather than hidden inside `CodeItem` wrappers
that this change would have broken.
