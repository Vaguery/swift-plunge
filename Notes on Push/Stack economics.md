# Stack economics: what piles up, what dries up

Where do items accumulate, and where do they run out? This is the shape of **argument starvation**
(Design Principles, §5) — the flaw the iterator work is aimed at — so it is worth measuring rather than
guessing.

Two halves, and they **disagree**, which turns out to be the most useful thing here:

- **Part 1 — the language.** Which stacks do its instructions fill and drain? A structural question,
  answered by driving every Behavior against a fully seeded interpreter.
- **Part 2 — the programs.** Which instructions actually go hungry, and which stack was empty when they
  did? An empirical question, answered by running 2,000 random programs.

Part 1 describes a program's **steady state**; Part 2 describes its **opening**. `.code` is the
language's scarcest resource *and* the one random programs never run out of. Both are true. Read §6
before drawing conclusions from either half alone.

---

# Part 1: what the language fills and drains

## How this was measured

`Tests/PushInterpreterTests/Infrastructure/Stack Flow Probe.swift`, disabled and run by hand. It drives
**every registered Behavior** against a fully seeded interpreter and records which stacks each one leaves
deeper or shallower. Re-run it after adding instructions; if the balance moves, update this note.

Caveats worth knowing before trusting a number:

- **The `.exec` column is meaningless here.** The probe runs the interpreter briefly after each Behavior
  so that a sequence delivers its elements rather than just showing the iterator it built — which drains
  `.exec` by design.
- **Constants count as producers.** `vecInt0…9` will happily make a vector, but they read the
  *environment*; they are not computation.
- **Results depend on the sample.** The probe's iterator has a body that pushes a `.bool`, so playing it
  registers as bool production.

## The balance

Behaviors that leave a stack deeper, versus shallower, across the whole language:

| stack | deepens | shallows | ratio | verdict |
|---|---|---|---|---|
| `.iterator` | 17 | 7 | **2.43** | piles up |
| `.bool` | 67 | 44 | **1.52** | piles up |
| `.char` | 22 | 24 | 0.92 | balanced |
| `.vecBool` / `.vecDouble` / `.vecInt` / `.vecString` | 15 | 17 | 0.88 | balanced |
| `.double` | 24 | 30 | 0.80 | drains |
| `.string` | 26 | 37 | 0.70 | drains |
| `.int` | 76 | 144 | **0.53** | drains |
| `.code` | 11 | 38 | **0.29** | starves |

## 1. `.code` is the tightest bottleneck in the language

Eleven behaviors leave `.code` deeper. **Five of them are the `xQuote` family** (`boolQuote`,
`charQuote`, `doubleQuote`, `intQuote`, `stringQuote`); five more are `.code`'s own combinators, which
can only copy a block that already exists; the eleventh is `iteratorPeekBody`, which likewise hands back
a block that was already there.

So the only way to make a code item **that did not exist before** is:

- one of the five `xQuote`s, which lift a scalar; or
- a literal block in the program text.

There is **no `codeFromX` conversion family**, and no way at all to build a block out of several items.
`codeAppend` consumes two and returns one. Thirty-eight behaviors eat code.

**The CodeItem change made this materially worse**, and that is worth saying plainly because it was
otherwise a clear improvement: *every* exec instruction now takes its body from `.code`. Before, a loop's
body came off `.exec`, where the program supplied it for free. Now `execDoRange`, `execIf`, `execY`,
`codeDo`, and all five iterates compete for a resource with almost no source. A random program that runs
out of `.code` **cannot loop at all** — and it has ~11 ways to refill against 38 ways to drain.

If evolvability is the goal (§15), this is the first place to look. `codeGather` and `codeWrapPoints` are
enumerated but unimplemented, and either would be a real source.

## 2. A program cannot create a vector at all — only reshape one it was given

Sharper than the 0.88 ratio suggests, and completely invisible in it. Of the fifteen behaviors that leave
`.vecInt` deeper, **every single one** is either:

- a **constant** — `vecInt0…9`, which read the environment rather than computing anything; or
- a **combinator** — `vecIntDup`, `DeepDup`, `DupItems`, `DupTimes`, `YankDup` — which copy a vector that
  is already on the stack.

That is the whole list. Across all 38 `vecInt*` instructions, every other one needs a vector to start
with and most return a smaller one. `vecIntConj` looks like a builder but appends an int to an *existing*
vector. There is no `vecIntFromInt`, no `vecIntGather`, no empty-vector constructor. `vecIntPushAll` runs
the other way — and now that it is an iterator, one element at a time.

**So the vector stacks are closed systems.** Whatever a program is handed as an input, a constant or a
literal, it can reshape forever; the moment it flushes them, no instruction in the language can make
another. The 0.88 ratio hides this entirely, because reshaping counts as production.

This is arguably a worse gap than `.code`'s — at least `.code` has the five quotes, which genuinely lift
a scalar into a new item.

### Partly addressed: `vecXConstruct`

`vecXConstruct` (added since) takes a vector as a **shape** — never reading its contents — and consumes
that many scalars to fill a new one. It is the exact inverse of `pushAll`, which is where its argument
order comes from.

**It does not open the closed system**, and is not meant to: it still needs a vector to shape the new
one, so the stacks remain seeded-only and everything above stands. What it fixes is the sharper half of
the problem, which the "closed system" framing was obscuring: **until now a vector's contents could only
be rearranged, never computed.** A program could not put an answer into a vector. Now every element can
be something it worked out, and each element's own derivation survives into the vector's crux.

Two more sources are planned and need infrastructure first.

## 3. `.int` is the currency, and the combinators tax it

**159 behaviors take an `.int` argument. 84 of those are the per-stack combinators** — `DupItems`,
`DupTimes`, `Yank`, `YankDup`, `Shove`, `DeepDup`, `PopItems`, each generated for twelve stacks, every
one of them wanting an index or a count off `.int`.

So `.int` is not really the integer stack; it is the **shared argument channel for the whole language**.
Every stack's combinator family draws on it. That is why it drains (0.53) despite 76 producers, and it is
the concrete mechanism behind "argument starvation": a program manipulating *strings* still needs ints,
and competes for them with everything else.

Two things follow:

- **This is the reason `.iteratorPlayDelayed` re-reading its delay was a dead end.** It was not just
  wasteful in the abstract — it was drawing on the one stack every other instruction also needs.
- Any future instruction that takes a count should be viewed with suspicion in exactly this light.

## 4. `.bool` piles up, and nothing much wants it

67 producers, 44 consumers. Every comparison (`intEq`, `charGT`, `doubleLTE`…), every `StackIsEmpty`, and
every predicate lands a bool. The consumers are mostly `.bool`'s own logic operators plus a handful of
guards (`execIf`, `execWhen`, `execWhile`, `execDoWhile`) and the vector query family.

So bools accumulate as a by-product of asking questions. That is benign — it is the cheapest stack to
have a surplus of — but it means a random program's `.bool` stack is rarely empty, which makes
`execIf`/`execWhile` cheap to satisfy and `boolStackIsEmpty` almost always false. Worth knowing when
reading a fuzz trace.

## 5. `.iterator` is now the best-supplied type in the language

17 producers against 7 consumers, and **ten `iteratorFromX` constructors** — the richest conversion
family here, richer than `.int`'s four or `.double`'s four. Adding to that: the five `*Iterate`, the
explode family, and both dup families across thirteen stacks all leave one.

The consumers are `.iteratorStep`, `.iteratorPlay`, `.iteratorPlayDelayed`, `.iteratorPopState`, and the
four setters — but note the setters and Peek *hand it back*, so really only playing and stepping retire
an iterator.

That surplus is by design (a loop should be easy to make) but it is worth watching: iterators are the
heaviest items in the language, since each retains its origin and body for its lifetime. A `.iterator`
stack full of abandoned half-run loops is a plausible memory shape that nothing currently discourages.
`maxStackDepth` bounds the count and `maxItemWeight` bounds each one, so it is bounded — just untidy.

---

# Part 2: what actually starves, empirically

The half above measures the **language**: which stacks its instructions fill and drain. This half
measures **programs**: run a lot of random ones and see who actually goes hungry.

`Tests/PushInterpreterTests/Infrastructure/Argument Starvation Probe.swift`, disabled and **run alone**
(it draws from `fuzzRNG`, a shared global; a concurrent drawer breaks the seed). 2,000 programs × 120
tokens, ~10 seconds.

It does not read the `.error` stack. An error says "`intAdd` missing args" but never says *which* stack
was short, and says nothing about the attempts that succeeded — so counting errors tells you which
instructions are **common**, not which are **starved**. The probe steps by hand and inspects the
interpreter in the instant before each instruction fires, giving an exact denominator and exact blame.

**Two denominators, because they disagree wildly and both are true:**

- *per attempt* — every firing. An instruction inside a loop body fires once per pass, so this is
  dominated by whichever programs happened to loop. `boolPop` starving 123 times can be one program going
  round 123 times with an empty `.bool`.
- *per program* — each instruction once, at its first firing. The unweighted question: when a random
  program reaches this instruction, is anything there for it? **This is the one to trust.**

## 6. Structural scarcity is not empirical scarcity

The headline finding, and it contradicts Part 1.

| stack | asked | empty | rate |
|---|---|---|---|
| `.bool` | 3595 | 2815 | **78.3%** |
| `.double` | 3120 | 2232 | **71.5%** |
| `.char` | 1662 | 1065 | 64.1% |
| `.int` | 10832 | 6882 | 63.5% |
| `.string` | 4498 | 2329 | 51.8% |
| `.vecDouble` / `.vecBool` / `.vecInt` / `.vecString` | ~2200 each | ~1100 | ~48% |
| `.code` | 14947 | 981 | **6.6%** |
| `.iterator` | 62273 | 1471 | 2.4% |
| `.exec` | 2402 | 3 | 0.1% |

**`.code` is the language's scarcest resource (0.29 producers/consumers) and random programs are swimming
in it (6.6% empty).** Both are true. The generator emits literal blocks, and nothing consumes them fast
enough — so a structural famine and an empirical glut coexist. `.bool` is the mirror image: the language
*produces* bools faster than it eats them (1.52), yet random programs want one and find nothing 78% of
the time, because a fresh program has produced none *yet*.

The lesson is that Part 1 describes a program's **steady state** and Part 2 its **opening**. Most random
programs never reach a steady state — they die on `stepLimit` first — so the empirical numbers are what
a search actually experiences, and the structural ones are what a *good* program would experience.

Both matter, for different reasons, and neither substitutes for the other.

## 7. The iterator constructors are unfireable by accident, and that is mostly fine

Every `iteratorFromX` starves ~100% of the time per program. The reason is arity:

```
.execDoRange           takes [.int, .int, .code]                         — 3 args, 2 stacks
.iteratorFromIntRange  takes [.int ×5, .bool, .code]                     — 7 args, 3 stacks
```

Seven arguments across three stacks is a conjunction a random program essentially never satisfies. The
blame column shows exactly that: `int:57 bool:34 code:20` — it fails on the ints first, then the bool,
then the code.

**This is by design and not a defect**: the constructors exist so `crux()` has something to say, not for
programs to call. `execDoRange` — the instruction a program *should* use — starves rarely.

But it does mean **twelve constructors sit in the genome pool as dead weight**, drawn as often as
anything else and doing nothing. That is a real cost to a search, and it is the kind of thing
`InstructionSets.swift` exists to fix: a `crux-only` set to subtract from an evolvable language would pay
for itself. Worth doing alongside the `contingencySources` set already noted there.

## 8. An iterator exists only during a loop

Every `.iterator` instruction — `Peek`, `Swap`, `Rot`, `Eq`, the setters, `Step`, `PopState` — starves
~100% per program, while `.iteratorPlay` starves 2.4% per attempt. Both are right: `.iterator` is nearly
always occupied *while a loop runs*, and nearly always empty when a random program reaches an iterator
instruction at some arbitrary point.

So the whole `.iterator` vocabulary is only reachable from inside a loop body. That is not obviously
wrong — a getter is for asking about *your* loop — but it means a genome carrying `.iteratorPeekStride`
outside a body is carrying a no-op, and that the surplus in Part 1 (2.43) never materialises for a random
program.

## 9. `.exec` instructions are the best-fed in the language

`execDup`, `execSwap`, `execRot`, `execEq`, `execPrint`: **0% starved**, every one. `.exec` is never
empty while a program is running — if it were, the program would have stopped. They are the only
instructions guaranteed an argument.

## What this suggests, in rough order

Not decisions — the trade-offs belong to whoever picks these up.

1. **Give the vectors a source.** Something like `vecIntGather`, or an empty-vector constant. Right now
   the only vector a program can ever have is one it was handed, which makes the whole vector half of the
   language unreachable to a search that was not seeded with one. This is the clearest outright gap.
2. **A `crux-only` instruction set to subtract from an evolvable language.** Twelve constructors are
   drawn into genomes as often as anything else and can essentially never fire (§7). `InstructionSets.swift`
   is where this belongs, next to the `contingencySources` set already noted there. Cheap, and it is pure
   waste until done.
3. **Give `.code` a source** — `codeGather` (enumerated, unimplemented). Structurally the tightest
   bottleneck (§1), *but* §6 shows random programs are not short of code today, so this is less urgent
   than it looked from Part 1 alone. It will bite a program that gets past its opening, which is exactly
   the program a search is trying to find.
4. **Watch `.int`.** Not a bug, but the per-stack combinators are 84 draws on one shared channel, and it
   is empty 63.5% of the time it is wanted. That is the starvation mechanism made concrete, from both
   ends at once.
5. Nothing needs doing about `.bool` structurally — but note the 78.3% empirical shortfall is the worst
   in the language, and it is an *opening* problem, not a steady-state one.
