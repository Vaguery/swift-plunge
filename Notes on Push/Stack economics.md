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

### Opened: `vecFromIterator`

**This is the one that opens the closed system**, and it is worth being precise about how, because it is
not by adding a builder for each type.

`.vecFromIterator` drives an iterator to exhaustion and collects what it emits into a vector of the
matching type. So `0 10 1 0 0 true ( ) .iteratorFromIntRange .vecFromIterator` produces a `vecInt` from
**nothing but ints**. The seeded-only property is gone: a program that flushes every vector it was given
can now make more, from scalars, from a string, from a code block — from anything an iterator can walk or
count.

Two things make it possible, and both were already there:

- **Its result type is its argument's.** One instruction, four result stacks, chosen by what actually
  comes out. That is what lets it exist without a sieve — nothing can *ask* `.iterator` for an
  Int-emitter (see "Sieve arguments"), so it takes whatever is on top and answers in kind. `.code`'s
  quotes are the same trick from the other direction, and `pushDefault` already routed by type.
- **Nothing had to choose a length.** Every kind was already bounded before it could be an argument: a
  claim was clamped to `maxIterations` at `push`, a walk's length is a fact `maxVectorLength` bounds, and
  the push gate measures the result once more on the way out.

It is also the first instruction that makes `.int` *scarcer* on purpose and is right to: two ints become
a hundred, on a different stack. Given that `.int` is the most-demanded stack in the language and unmet
roughly half the time it is wanted, an instruction that turns the cheap plentiful thing into the
expensive scarce one is exactly the direction of trade this document has been asking for.

One more source is planned and needs infrastructure first.

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
| `.double` | 3493 | 1957 | **56.0%** |
| `.string` | 5863 | 3231 | 55.1% |
| `.bool` | 4814 | 2534 | 52.6% |
| `.int` | **15679** | **7616** | 48.6% |
| `.vecInt` | 2796 | 1336 | 47.8% |
| `.char` | 2637 | 1192 | 45.2% |
| `.vecString` / `.vecBool` / `.vecDouble` | ~3300 each | ~1400 | 39–45% |
| `.iterator` | 19632 | 1555 | 7.9% |
| `.code` | 18917 | 1286 | **6.8%** |
| `.exec` | 1931 | 1 | 0.1% |

> **These numbers have been restated twice, and both times the measure — not the language — was what
> changed.** The first set was understated because sixty behaviors reached into a stack they never
> declared in `takes:` (Design Principles §14), and the probe read the same declaration the bug hid
> behind. `alsoNeeds:` fixed it at the source and demand rose sharply: `.int` went from 10,832 asks to
> 15,639.
>
> This set is smaller again, for the opposite reason: **the probe now asks the Planner** (`plan(on:)`)
> instead of comparing declared counts to stack depths. That is what a Behavior actually experiences, and
> it closed the last blind spot — `vecIntConstruct`'s dynamic need was invisible to any static count, and
> now shows up starving in **100%** of the programs that reach it. But a plan **stops at the first stack
> that cannot supply**, so an instruction short of two stacks now blames one, where the old arithmetic
> blamed both. Hence the rates fall by roughly 5–7 points across the value stacks (`.int` 55.1% → 48.6%)
> **with no change to the language whatsoever.**
>
> So: *empty* now means "the stack the Behavior would have given up at," which slightly under-counts the
> stacks it never got as far as reaching for. It is a truer denominator of *refusals* and a slightly
> lower bound on *shortfall*. `asked` still comes from `staticNeeds`, which names the stacks an
> instruction draws on without claiming to know how many it wants.
>
> **Read `.int` by volume, not by rate.** It is asked **15,679 times**, three times more than any other
> value stack, so its 7,616 unmet asks remain the largest shortfall in the language by a wide margin,
> even at the lowest rate of the four scalars. A rate table flatters it; the volume is the story.

**`.code` is the language's scarcest resource (0.29 producers/consumers) and random programs are swimming
in it (6.8% empty).** Both are true. The generator emits literal blocks, and nothing consumes them fast
enough — so a structural famine and an empirical glut coexist. `.bool` is the mirror image: the language
*produces* bools faster than it eats them (1.52), yet random programs want one and find nothing half
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
5. Nothing needs doing about `.bool` structurally — but note the ~53% empirical shortfall is among the worst
   in the language, and it is an *opening* problem, not a steady-state one.


---

# Part 3: what mix of instructions should a random program have?

> **The numbers below are preliminary and their method has since been corrected — do not cite them
> yet.** They came from an early run: a single genome length (120), one seed, 300 programs, and a
> starvation rate **pooled over attempts**. Attempts within a program are not independent (a loop repeats
> one instruction), so pooling invents a denominator and understates the rate — the sound per-program
> rate is roughly double at short lengths. The probe has been rebuilt to be per-program, to sweep four
> lengths (50/100/250/500), and to **pool across bounded tranches** so a sound large sample can be
> gathered without one process filling memory (`MIX_TRANCHE=k`). A calibrated run will replace this
> section. What survives the rebuild for certain is **§0** — the lesson, not the digits.

Measured by "Instruction Mix Probe", a slow diagnostic run alone. Ten mixes over the four
`InstructionTag` partitions — the balanced centre, each tag **enriched** (a third of the draw) and
**depleted** (a ninth) in turn, plus `language-shaped` as a control.

## 0. The measure lied first, again

The raw starvation rate says `equal` starves at **4.0%** and `language-shaped` at **29.2%** — a 7×
difference that is almost entirely an artifact.

**127 of the 526 instructions can never starve.** Constants and inputs read a binding; `xStackDepth`,
`xFlush` and `xStackIsEmpty` measure or clear, and an empty stack is a fine answer for all of them. So a
mix carrying more of those scores a lower starvation rate *mechanically*, whatever it does to the
programs. Half of `equal`'s draw is environment tokens; only 17% of `language-shaped`'s is. **Comparing
their raw rates compares the dilution, not the language.**

The comparable number is the **conditional rate**: of the attempts by instructions that ask for anything
at all, how many went unfed. `Interpreter.alwaysSatisfied` makes it computable. It is a fourth instance
of the pattern this document keeps meeting — see §14 — where the obvious measure and the thing it
measures share a blind spot.

| mix | starved (raw) | **of starvable** | maxCrux | meanCrux | composed | steps |
|---|---|---|---|---|---|---|
| equal | 4.0% | **34.7%** | 250 | 2.0 | 34% | 848 |
| constant-rich | 4.3% | 34.2% | 193 | 1.8 | 29% | 807 |
| input-rich | 3.6% | 35.1% | 250 | 2.1 | 36% | 837 |
| combinator-rich | 4.3% | 36.2% | 56 | 1.9 | 28% | 779 |
| other-rich | 5.6% | 39.0% | 181 | 2.1 | 34% | 832 |
| constant-poor | 6.5% | **47.7%** | 99 | 1.6 | 26% | 777 |
| input-poor | 7.1% | 34.7% | 399 | 2.1 | 35% | 693 |
| combinator-poor | 5.0% | 35.2% | 211 | 1.8 | 30% | 874 |
| other-poor | 3.8% | 39.1% | 131 | **1.4** | **18%** | 769 |
| language-shaped | 29.2% | **54.0%** | 599 | 2.1 | 36% | 516 |

*composed* = the share of surviving items whose crux is longer than one item — i.e. that were computed
from something rather than handed over and left alone. It is the cheapest honest proxy for the thing this
whole project is for: an item that can explain itself in more than one word.

## 1. The headline: the pie chart barely matters — with one exception

**Every one of the nine deliberate mixes lands between 34% and 39%.** Enrich or deplete any tag by a
factor of three and the conditional starvation rate hardly moves. That is a genuinely surprising result:
it says the generator's proportions, which nobody had ever chosen on purpose, are **not the lever** they
looked like.

The exception is real and points one way:

> **`constant-poor` is 47.7%** — 13 points worse than anything else in the nine.

Starve the constants and the programs starve, because **constants are where values come from**. Inputs
are only 10 tokens and are bound to the same kinds of values, so `input-poor` costs nothing (34.7%); the
80 constants are the actual supply. This is Part 1's "the vector stacks are closed systems" from the
other end: a program that is handed nothing computes nothing.

## 2. The status quo is the worst option measured

`language-shaped` — drawing uniformly from `Interpreter.language.keys`, which is what
`randomInstruction()` has always done — **starves at 54%, half again worse than any deliberate mix, and
composes no better** (36% vs `equal`'s 34%, mean crux 2.1 vs 2.0).

So the ~20-point starvation reduction from simply *choosing* a mix is free. Nothing is given up for it.
That is worth knowing not because 54% is catastrophic but because it was never a decision: it is the
shape of the language — 34% furniture, 15% constants, 2% inputs — leaking into the generator through
`Dictionary.keys`.

## 3. Composition needs instructions that compute

`other-poor` (11% computing instructions) is the only mix that visibly hurts the programs: **18% composed
against 26–36% everywhere else**, and the lowest mean crux at 1.4. Its starvation rate is *fine* (39.1%)
— it simply produces less to starve over.

Which sharpens what "starvation" is worth. **Low starvation is not the goal**; `other-poor` proves you
can buy a decent rate by not attempting anything. The pair to watch is *starvation and composition
together*, and on that pair `equal`, `input-rich`, `input-poor` and `other-rich` are indistinguishable
winners — 34–39% starved, 34–36% composed.

## 4. `.int` is still the story

Every mix blames `.int` for 30–39% of its refusals, more than double the next stack. Nothing in the pie
chart changes that, which is consistent with Part 2: `.int` is asked for three times more often than any
other value stack, and no proportion of *instructions* fixes a shortage of *values*.

## What this does not answer

- **Genome length is not varied** (120 genes throughout), and the Fibonacci cliff means length is a
  high-leverage parameter — 59 genes gives 34% code, 60 gives 55%. A length sweep is the obvious next
  diagnostic.
- **`maxCrux` is noisy** (a max over 300 programs; 56 to 599 across mixes with the same mean). Read the
  mean and the composed share; treat the max as an anecdote.
- **Only the Fibonacci genome.** Whether these proportions hold for a genome whose blocks are genes
  (ForestGenome) is untested, and is exactly the kind of thing that could differ.

---

# Part 4: non-destructive queries flip consumers into producers

The 59 query instructions — lengths, `isEmpty`, `contains`, `indexOf`, comparisons, `xEq` — used to
**consume** the argument they examined. They now read it and leave it (Design Principles: "queries don't
destroy their object"; the mechanism is the `.reads` requirement + a cleanup-pop crux). The economic
consequence is direct and structural, and unlike Part 3 it needs no random sampling to see: **a query
that used to shallow its argument stack now deepens it.**

Measured by the Stack Flow Probe (each behavior run once), the flip is exact per instruction:

```
boolEq   was  bool:-1   (ate two bools, pushed one)
boolEq   now  bool:+1   (reads two bools, pushes one)
```

A +2 swing on `.bool` for that one instruction, and the same story for every query on its argument
stack(s).

## The aggregate: every value stack's ratio rose

Producer/consumer ratios (deepen ÷ shallow, one vote per behavior), against the Part-1 snapshot:

| stack | was | now |
|---|---|---|
| `.code` | **0.29** | **~0.59** |
| `.int` | 0.53 | ~0.56 |
| `.string` | 0.70 | ~1.12 |
| `.double` | 0.80 | ~1.04 |
| `.char` | 0.92 | ~1.69 |
| `.vecInt` | 0.88 | ~1.55 |
| `.bool` | 1.52 | ~1.64 |

`.string`, `.double`, `.char` and the vector stacks cross from **net-drained to net-produced** — the
closed-system framing of Part 1 loosens, because a program can now inspect a value without spending it.

**`.code` is the headline: its ratio roughly doubled** off the language's long-standing scarcest number.
Part of that is this change (its three queries — `codeItemIsEmpty`, `codeLengthRoot`, `codeEq` — flipped
from shallow to deepen); part is the collectors added earlier (`codeFromIterator`). Both pull the same
way. And the latent gain is larger: the convention makes the **unbuilt** code queries
(`.codeContains`, `.codeDepth`, `.codeNthPoint`…) non-destructive by default when built — more ways to
interrogate code without eating it.

## Two honest caveats

- **The absolute ratios are not attributable to this change alone.** The whole session added instructions
  (iterators, collectors, cut) that moved the counts too; treat the *direction* (every affected stack
  rose) and the per-instruction flip as the clean signal, not the exact deltas.
- **Runtime starvation is a downstream, confounded effect.** A query still needs its argument *present*
  to fire, so it does not starve less itself; the benefit is that the argument survives for whatever
  comes next. Whether that shows up in the Argument Starvation Probe depends on program structure, and
  its demand figures shifted this session for unrelated reasons. The tag machinery now separates
  `instructions(reading:)` from `instructions(consuming:)`, so a future probe can isolate the effect
  cleanly — the trap noted during design (a consumer set built on `staticNeeds` would have stayed blind)
  is closed.
