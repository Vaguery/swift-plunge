# Keeping loops human-sized

**Status: RETIRED AS A DEFAULT (2026-11-07).** `maxIterations` now defaults to `Int.max` (no clamp): a crux
folds a loop's chain into a counted loop (*Compressing looped provenance*), so a loop cut off by `stepLimit`
keeps a readable history and the clamp is no longer load-bearing. The mechanism stays, opt-in, for a run
that wants loops held to a human-sized number of passes. Also changed that day: the dying loop's body now
returns to `.code` *after* its last pass, not with it (see *The first-class iterator* § farewell).

**Was: BUILT.** `maxIterations` (default 100), `.iteratorRestart`, a dying loop returning its body,
and the constructor invariant all landed together. This note is kept for the *reasoning*; the code is in
`InterpreterSettings`, `Interpreter.clampingIterations`, `IteratorItem.clamped(toPasses:)` and
`Interpreter.iteratorFarewell` / `iteratorBuilt`. The principles it argued for are Design Principles §5
and §12.

It replaces the `.execDoFew` / `.execDoSome` family of earlier interpreters, which took an `.int`
argument modulo 10 or 100 to stop a random program asking for nine hundred million passes.

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

At the default `stepLimit` of 1,000. A bodyless pass costs **1 step** (measured — the optional-body work
made sequences that cheap); a pass with a body costs that plus the body:

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

**It lives at `Interpreter.push`** — not, as this note first proposed, in `iteratorLoop`. Two reasons,
and the second is the interesting one:

- `iteratorLoop` is `static` and the exec loops are pure `Behavior`s, so neither can see `config` at all.
  Only `push` can.
- `push` is where §11 says budgets live, beside `maxItemWeight` and `maxCallWeight`, and it catches
  **every** path at once — the loop instructions, the setters, each pass's re-push, and the constructors.

The original plan carved the constructors out, on the grounds that a crux recorded under one setting must
round-trip under another. **That carve-out turned out to be unnecessary, because the clamp is
idempotent**: a clamped iterator is a fixed point of the clamp, so reconstructing one and pushing it again
changes nothing. There is a test for exactly that, because the whole design rests on it. (A crux re-run
under a *smaller* budget would clamp further — but so would a large item under a smaller
`maxItemWeight`. That is what a budget is.)

The carve-out would also have been a bypass: a program could have built an unclamped loop by hand. That
it starves ~100% of the time is not a reason to leave a hole.

**No new instructions, none renamed, none deprecated.** `execDoRange` keeps its name, its arity and its
meaning.
- **For `.elements` walks — impossible, and rightly so.** A walking iterator has **`destination = nil`**:
  its end derives from its source's length, so there is structurally nothing to move in. The clamp cannot
  reach it even if someone wanted it to.

  That is the right answer, not a lucky escape. **A count is a claim; a collection's length is a fact.**
  You can clamp a claim. Clamping a fact means "you only see the first 100 elements of your own data",
  which is a different and much worse lie. `maxVectorLength`/`maxStringLength` already bound walks at
  1,000, and *they are* a walk's iteration budget — lower them if you want shorter walks.

  So the two limits are deliberately unequal: a program may walk all of its data, and may not invent a
  loop longer than `maxIterations`. That asymmetry is the point.

### The settings must be coherent, and today they are not

Measured, and it has nothing to do with this proposal — it is true now:

```
maxVectorLength  1_000        stepLimit  1_000
walking the largest LEGAL vector at default settings → emits 997 of 1000, dies 3 short
```

The largest vector the interpreter will accept cannot quite be traversed in the steps it allows, missing
by exactly the setup cost. There is an unwritten invariant here worth writing down:

> **`stepLimit` must exceed `maxVectorLength` and `maxStringLength`** (plus a little), or a legal
> collection cannot be walked to completion.

`maxIterations` should join that: a coherent configuration wants
`stepLimit > max(maxIterations, maxVectorLength, maxStringLength)`. Whatever `maxIterations` defaults to,
it is the *counted* loops it governs, and the collection limits govern the rest.

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

---

# What a spent iterator should do

Related, because `maxIterations` makes loops end *sooner* and more often, so how they end matters more.

**Today it dies**, and the dying is invisible: on its last pass `.iteratorPlay` emits the payload and
simply does not re-push. The iterator is consumed by its own final act. So an iterator never rests in a
spent state — every one on `.iterator` has something left to emit.

One inconsistency: the `.iteratorFromX` **constructors do not check `isSpent`**, so a crux can build an
already-spent iterator that *does* rest. Playing it then destroys it silently and emits nothing. Worth
closing — refuse to push a spent iterator from a constructor, and the invariant is exact: *every iterator
on `.iterator` has something to emit*. Nothing is lost, because a spent iterator has no crux to reproduce
if it cannot exist.

## Parking a spent iterator would break nested loops

Tempting — the starvation probe shows an iterator costs seven arguments to rebuild and starves ~100% of
the time, so an exhausted one still holding a good origin, stride and body is the only cheap handle on an
expensive object. Park it, and `.iteratorRestart` could rewind it.

**It breaks nesting, and fatally.** `.iteratorPlay` takes whatever is on *top* of `.iterator`. An inner
loop's corpse parks on top of the outer loop's live iterator; the outer loop's next continuation fires,
pops the **corpse**, sees it is spent, returns nothing — **including no continuation**. The outer loop
dies and its iterator is stranded underneath. Every nested loop would end this way.

That is decisive on its own. (The corpses would also pile, but bounded by `stepLimit` you cannot end
enough loops for the runaway guard to notice.)

## Dumping its arguments back is safe where parking is not — and feeds the two hungriest stacks

The other way to die: **give everything back**. A spent iterator pushes its origin, destination and body
to `.exec`, whence `pushDefault` routes each to the stack it came from.

Three things recommend it:

1. **It does not touch `.iterator`,** so the outer loop's iterator stays on top and nesting is unharmed.
   This is the whole difference from parking.
2. **It is already the language's habit.** `execDoCount` with a count below 1 returns its arguments
   (`Router(.code, body), Router(.exec, x)`); `execDoTimes` returns its body to `.code`. "Give the
   arguments back when you cannot act" is established; this extends it to "when you are done".
3. **It is a source for the two scarcest stacks.** From "Stack economics.md": `.code` is the language's
   tightest structural bottleneck (0.29 producers per consumer, and only the five quotes can make a block
   that did not exist), and `.int` is the most-demanded stack there is and unmet more often than not. A
dying loop hands back a
   block and two ints. Every loop that ends becomes a small supply of exactly what the language is short
   of — which is a *far* better argument than tidiness.

It also reads well against principle 10: a loop's state is private **for its duration**. Dying ends the
duration, so returning the state is not a leak; it is the encapsulation ending cleanly.

**Against**: it changes every loop's trace again, and it hands back bounds nobody asked for. The pile is
bounded by `stepLimit` — you cannot end many loops in 1,000 steps — so the runaway guard will not see it
at default settings, though a long run might.

**Recommendation: worth doing**, and mostly for reason (3), which is a real answer to a real famine rather
than a nicety.

## `.iteratorRestart` — yes, and for a better reason than symmetry

Resets the cursor to 0. Leaves start, end, stride and body alone.

It is not merely `0 .iteratorSetCounter` with fewer keystrokes. **It takes no arguments**, and `.int` is
unmet more often than not — so `0 .iteratorSetCounter` frequently cannot fire, while
`.iteratorRestart` always can. In a language whose defining flaw is argument starvation, a zero-argument
form of a useful operation is worth a whole instruction.

It only ever acts on a *live* iterator, since spent ones die — so in practice it is reached from inside a
body, and a body that restarts its own loop is a `while true` bounded by `stepLimit`. Combined with a
guard (`.execIf`, `.execWhen`) it is a real do-while, built out of pieces that already exist. That is the
Push thing to do.

## Settled in the building

1. **The default is `100`.** It makes most loops complete at the default `stepLimit` of 1,000, which is
   the whole argument, even though it looks inconsistent beside the other 1,000s. Six tests that wanted
   longer loops now raise `config.maxIterations` next to the `config.stepLimit = 20_000` they *already*
   set — the pattern, not an obstacle: **a test that wants a big loop says so**, and it demonstrates the
   knob. **Review this number**; it is the one thing here that is a judgement call rather than a
   consequence.
2. **Silent.** It is not an error: `maxStackDepth` errors because the push cannot happen, whereas here
   the loop happens, just smaller. The clamped value is on the iterator for anyone who peeks, and its
   crux tells the truth about what actually ran.
3. **It supersedes the runaway guard for `dupTimes`.** Three billion copies is now a hundred that
   *finish*, where the guard used to have to stop a few hundred that never would. Raise the budget past
   what the run can afford and the guard takes over exactly as before. Both are tested.

## Still open

Tracked in `Roadmap.md`, with the argument kept here:

1. **Should a program raise its own loop's ceiling?** An `.iteratorSetIterations` would give a search a
   knob on its own tractability, and `stepLimit` still backstops it. Interesting; probably later.
   (Roadmap §F.)
2. **The other half is not done.** The clamp is a backstop, not a shaper: it makes a huge count
   survivable, it does not make counts *tend* to be human-sized. Ints drawn uniformly over a huge range
   mostly produce identical clamped loops — safe, monotone, and wasting the whole range. The tendency has
   to come from a human-scaled distribution in the genome. (Roadmap §D.)
3. **Coarsening** (stride = span/budget) is still the more expressive option for ranges, and is exactly
   the `.sampling` mechanism. Rejected here because it cannot work for counts and so needs two rules — but
   worth revisiting when `.sampling` lands. (Roadmap §F.)
