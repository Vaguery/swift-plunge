# Observations on Push

**What this is.** The other notes here record things we *decided*: `Design Principles.md` is the rules,
and the rest are the arguments behind particular pieces. This one records things that turned out to be
**true without anyone deciding them** — behaviours that fall out of the interactions between pieces, each
of which was designed for its own reasons.

They are not bugs and they are not features. They are the language's actual behaviour, which is the thing
a search will find, whatever we intended. Worth writing down for two reasons: an emergent channel is
usually more interesting than a designed one, and the ones we do not know about are how a measure ends up
lying to us (Design Principles §14 — the measure and the bug had the same blind spot).

---

## 1. Value amplification: a bounded chain is not a bounded program

**Observed, measured, and it does what it looks like.** Every loop in this program is bounded at
`maxIterations = 100`. It produces **400 ints**, with no errors:

```
0 200 1 0 0 true ( ) .iteratorFromIntRange     ← claims 200 passes; clamped to 100 at push
.codeFromIterator                              ← ONE step; ( 0 1 2 … 99 ), a 100-point block
.codeDup .codeAppend                           ← 200 points
.codeDup .codeAppend                           ← 400 points
0 0 true ( ) .iteratorFromCode .iteratorPlay   ← walks it: 400 ints on .int
```

Two ints go in. Four hundred come out, in 418 steps, each one carrying its own O(1) crux
(`( 0 99 .intAdd )`).

### The mechanism: collecting launders a claim into a fact

This is §12 meeting itself coming the other way. The principle draws a line:

> A count is a **claim**; a collection's length is a **fact**. Claims may be clamped. Facts may not.

Both halves are right, and each is enforced by its own budget: `maxIterations` (100) bounds claims,
`maxCodePoints`/`maxVectorLength` (1000) bound facts. **What nobody decided is what happens at the
boundary between them.** `.codeFromIterator` takes the output of a claim and makes it into data — and
data's length is a fact. The clamp already ran, at `push`, and it never runs again, because the block on
`.code` is not asserting anything: it *is* four hundred elements.

So the chain does not defeat the iteration limit. It **converts** to a currency the iteration limit does
not price, at an exchange rate of 10×: `maxCodePoints / maxIterations`. Nothing is violated; the limits
were always about different things.

### Why this is a channel worth having

The language's defining failure is **argument starvation** — every scalar stack is empty roughly half the
times it is wanted, and `.int` is asked for three times more often than anything else while going unmet
(`Stack economics.md`). A random program mostly fails because nothing is there.

This chain manufactures values out of almost nothing. Two ints become four hundred, on the stack that
needs them most, and it composes: any iterator can be collected, so the same trick turns a string into
100 letters, a claim into a block, a block into a longer block. **A search will find this**, and it
should — an instruction that makes the plentiful cheap thing into the scarce expensive one is exactly the
direction of trade those notes have been asking for. §17 says evolvability is the goal, and this is
evolvability arriving by a route nobody drew.

It also stays *explainable*, which is the part that makes it worth keeping rather than closing. The
hundredth int records `0 99 .intAdd` — not "the 99th thing that fell out of a pile". The amplification
does not degrade the crux, because collecting is law 3 and boxing is law 1b.

### What it costs, stated honestly

- **The real ceiling is `stepLimit`**, not the loop budget. 400 ints cost 418 steps, because *emitting*
  them one at a time is honest work even though *collecting* them was one step. A program can amplify
  until it runs out of steps, which is the bound that was doing the work all along.
- **One step doing a thousand values' worth of work is *not* the cost**, though it looks like one.
  `.codeFromIterator` collected a 1000-point block at `counter == 1` — and it produced **one Item**,
  which is the unit that matters (§4). A block of a thousand points is one thing on one stack, gated by
  `maxCodePoints` at the push boundary. The work evaporates; the item is what persists, and it is
  bounded. The amplification is real, but it is not smuggled in through the step budget.
- **The 10× rate is an accident**, not a decision. It is the ratio of two numbers chosen for unrelated
  reasons (§13: `maxIterations` is derived from `stepLimit`; `maxCodePoints` is a policy). Anyone tuning
  either should know they are also setting an exchange rate.

### The general form

**A limit on a claim is not a limit on a value.** Any instruction that turns "what a loop would do" into
"what the data is" moves work across that line, and the line is where §12 stops looking. `.vecFromIterator`
does it too, at the same rate. If a third collector ever appears, it will do it again — and that is the
thing to notice at design time rather than discover in a measurement.
