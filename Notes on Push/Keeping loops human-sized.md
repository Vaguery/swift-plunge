# Proposal: keeping loops human-sized

**Status: a proposal, not built.** It replaces the `.execDoFew` / `.execDoSome` family of earlier
interpreters, which took an `.int` argument modulo 10 or 100 to stop a random program asking for nine
hundred million passes.

## First, why the old scheme was annoying

Worth diagnosing before prescribing, because the annoyance was not "it imposed a limit". It was four
separate things, and only one of them is inherent:

1. **Modulo is chaotic.** `100 .execDoFew` gives **zero** passes. `101` gives one. `109` gives nine.
   `110` gives zero again. The map from the int to the loop's size has no useful derivative *anywhere* —
   so a search cannot hill-climb it, and a human cannot read it. This is the real problem. A program
   that says 100 and does nothing is not a smaller loop; it is a broken one.
2. **Instruction bloat.** Few × Some × Many × every looping instruction, forever.
3. **The magnitude is baked into the instruction name**, so it cannot be tuned per experiment. It is
   policy, welded into semantics.
4. **It lies twice**: once at the call, and again in the crux, which reads `100 .execDoFew` and
   reproduces nothing.

Only (1) is about limiting. (2), (3) and (4) are about *where the limit lives*.

## What has changed since

- **Iteration is one type now.** Every loop in the language — counting, walking, repeating — funnels
  through `Interpreter.iteratorLoop`. The scale question has exactly one place to live, where it used to
  need an instruction per magnitude per loop.
- **The work is already bounded.** `stepLimit` caps total steps and the runaway guard catches piling. A
  million-pass loop does not run a million times today; it runs a few hundred and dies.
- **Collections are already bounded.** `maxVectorLength` and `maxStringLength` are 1,000, so a `.elements`
  walk can never exceed 1,000 passes. **Only an `.int` count is unbounded** — that is, `.counting`
  (`execDoRange`, `execDoCount`, `execDoTimes`) and `.repeating` (`xDupTimes`).

So the surface is far smaller than it was: one function, two kinds.

## The proposal: `maxIterations`, clamped

**Add one budget to `InterpreterSettings`, beside the ones already there:**

```swift
/// The most passes any single loop may promise. Iteration count is the last
/// unbounded dimension in the system: `stepLimit` bounds the *work* a loop does,
/// but nothing bounds what one loop claims it will do — so a loop that asks for
/// more than the interpreter could ever run simply dies half-finished, leaving
/// debris instead of an answer.
///
/// Applied by CLAMPING a loop's span at construction, never by modulo. See
/// "Notes on Push/Keeping loops human-sized.md".
public var maxIterations : Int = 100
```

Three claims, in order of importance.

### 1. Clamp, don't modulo — this is the whole difference

| int | `% 100` | clamp to 100 |
|---|---|---|
| 5 | 5 | **5** |
| 100 | **0** | **100** |
| 101 | 1 | 100 |
| 999_999 | 99 | 100 |

Clamping is **monotone**: every count at or under the limit passes through *completely untouched*, and
every count over it saturates. Small loops are not molested; large ones become the largest affordable
loop. The relationship between the int and the loop survives, so a search can climb it and a reader can
follow it.

Modulo destroys that relationship everywhere. That is what made it annoying, and it is not a matter of
taste — it is the difference between a gradient and noise.

### 2. It is a budget, not a semantic — which is why it is not arbitrary

`InterpreterSettings` is already a family of exactly this: one dimension, one number, one place,
configurable per experiment.

```
maxStringLength  1_000     maxItemWeight   100_000
maxVectorLength  1_000     maxCallWeight    10_000
maxCodePoints    1_000     stepLimit         1_000
maxCodeDepth     1_000     maxIterations       100   ← the missing one
```

The `maxCallWeight` comment says provenance "was the one unbounded dimension left in the system". That is
now out of date: **iteration count is.** Everything else that can grow is bounded, in one declared place,
by a number an experiment can set.

`100` is arbitrary in precisely the way `1_000` is arbitrary for `maxStringLength` — it is a **policy**,
declared once, not a claim about strings. `.execDoFew` put the same policy in the *language*, where it
could not be changed and had to be memorised. That is the whole difference, and it is not cosmetic.

### 3. It buys **completion**, not safety — and completion is what "human-sized" means

This is the part worth being clear about, because it is easy to sell this as a safety feature and it is
not one. `stepLimit` already provides safety.

At the default `stepLimit` of 1,000, and roughly 2–4 steps per pass:

- `0 999_999 .execDoRange` **today**: runs ~300 passes, hits the step limit, and **dies mid-loop**. The
  `.int` stack holds 300 indices going nowhere. Nothing was computed. The crux is `0 999999 .execDoRange`,
  which is a true statement about a program that does not work.
- `0 999_999 .execDoRange` **clamped**: runs 100 passes and **finishes**. The result is whole, the loop is
  legible, and the iterator's own crux reads `0 100 1 100 0 true ( body ) .iteratorFromIntRange` — a
  complete, runnable account of a loop that actually ran.

An evolved program that *finishes its loops* is one a human can read. That is the goal, and truncation is
the mechanism — not because big loops are dangerous, but because they are **useless**, and a useless loop
starves everything downstream of it.

## Where it applies, and where it must not

- **In `iteratorLoop` — yes.** One function; every looping instruction funnels through it. **No new
  instructions, none renamed, none deprecated.** `execDoRange` keeps its name, its arity and its meaning.
- **In the `.iteratorFromX` constructors — no.** They exist so `crux()` has something to say, and they
  must reconstruct *faithfully*: a crux recorded under one setting has to round-trip under another.
  This is a theoretical bypass — a program could construct an unclamped loop directly — but the
  starvation probe shows those constructors want seven arguments across three stacks and starve ~100% of
  the time, so nothing will find it by accident. Worth stating out loud rather than discovering.
- **In `.iteratorSetEnd` — yes.** It is program-facing, and "no loop may promise more than
  `maxIterations` passes" should hold however the loop was aimed.
- **For `.elements` walks — unnecessary.** `maxVectorLength`/`maxStringLength` already bound them at
  1,000. Clamping there would mean "you only see the first 100 elements of your own data", which is a
  different and much worse lie.

**Clamp the span, not the destination.** `60 10 .execDoRange` descends: clamping its *destination* would
mean raising it. The rule is "a loop may promise at most `maxIterations` passes; if it promises more, its
destination moves in to the furthest point it can afford" — which for a descending loop moves it up.

**The clamp is recorded, so nothing lies after the fact.** The iterator's `destination` *is* the clamped
one, so `.iteratorPeekEnd` reports it and the crux reconstructs it. The adjustment exists only in the
instant of construction; from then on the iterator tells the truth about what it will do. This is
strictly better than `.execDoFew`, whose crux preserved the lie forever.

## The other half: the language bounds, the search shapes

`maxIterations` is a **backstop**, not a shaper. It makes a huge count survivable and complete; it does
not make loops *tend* to be small.

The tendency has to come from the distribution of the integers reaching loops, and that is a **generator**
concern, not a language one. Genome ints drawn uniformly over a huge range will mostly produce clamped
loops (all identical, at the limit) — which is monotone and safe but wastes the whole range. Ints drawn
from something human-scaled — geometric, log-uniform, "mostly 0–20 with an occasional outlier" — give a
search actual gradient to climb, and the clamp then almost never fires.

That belongs with the new genome representations already on the roadmap. Arbitrariness in a search
hyperparameter is fine; arbitrariness welded into semantics is what `.execDoFew` got wrong.

## The alternative worth weighing: coarsen instead of clamp

For **ranges only**, there is a more expressive option, and it is not a new idea — it is exactly the
mechanism already chosen for `.sampling` Double ranges ("initialize by a number of steps, which
determines the stride size given the endpoints"), applied to Ints.

`0 999_999` with a 100-pass budget becomes **stride 10,000**: the loop visits 0, 10000, 20000 … 990000.
It covers its whole stated range, at the resolution it can afford. Nothing is truncated; only the
*resolution* changes, where clamping changes the *extent*.

- **For** — the loop still means what it said. `0 999999 .execDoRange` genuinely does go from 0 to 999999.
  It is arguably the more honest reading of a range.
- **Against** — it cannot work for `.repeating` or `execDoTimes`, where a count is a count and not a range:
  you cannot "coarsen" doing something a million times. So it needs *two* rules, one per kind — which is
  a smaller version of the per-instruction-policy problem we are trying to leave behind.
- **Against** — the body sees 0, 10000, 20000 instead of 0, 1, 2. A loop summing its index computes
  something entirely different. Clamping changes how *much* a loop does; coarsening changes what it *is*.

**Recommendation: clamp.** One rule for every kind, monotone, and it changes only extent. Keep coarsening
in mind for `.sampling`, where a range genuinely is being sampled and the resolution is the point.

## Open questions

1. **The default.** `100` makes most loops complete at the default `stepLimit` of 1,000, which is the
   whole argument — but it is smaller than the other 1,000s and will look inconsistent. The two
   provenance tests that loop 200 and 500 times would need `config.maxIterations` raised alongside the
   `config.stepLimit = 20_000` they *already* set, which is arguably a feature: a test that wants a big
   loop should say so, and it demonstrates the knob.
2. **Should a program be able to raise its own loop's ceiling?** An `.iteratorSetIterations` would give a
   search a knob on its own tractability, and `stepLimit` still backstops it. Interesting; probably later.
3. **Silent, or noted?** Recommendation: silent. It is not an error — `maxStackDepth` errors because the
   push cannot happen, whereas here the loop happens, just smaller — and the clamped value is visible on
   the iterator to anyone who peeks.
