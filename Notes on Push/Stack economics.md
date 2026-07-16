# Stack economics: what piles up, what dries up

Where do a random program's items accumulate, and where do they run out? This is the shape of **argument
starvation** (Design Principles, §5) — the flaw the iterator work is aimed at — so it is worth knowing
rather than guessing.

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

## What this suggests, in rough order

Not decisions — the trade-offs belong to whoever picks these up.

1. **Give `.code` a source.** `codeGather` (enumerated, unimplemented) would take N items and make a
   block. This is the single highest-leverage gap, and the CodeItem change is what made it urgent.
2. **Give the vectors a source.** Something like `vecIntGather`, or an empty-vector constant. Right now
   the only vector a program can ever have is one it was handed.
3. **Watch `.int`.** Not a bug, but the per-stack combinators are 84 draws on one shared channel, and
   that is the starvation mechanism made concrete.
4. Nothing needs doing about `.bool` or `.iterator`; they are healthy surpluses.
