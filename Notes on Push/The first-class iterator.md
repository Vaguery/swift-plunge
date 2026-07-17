# The first-class iterator

## What this is

`IteratorItem` is a proper Push type: its own `.iterator` stack, its own combinators, its own getters.
It encapsulates the state of one loop — where it started, where it ends, its stride, how far it has
come, and the body it emits each pass.

It comes from an earlier interpreter project, where making it first-class **made the language markedly
more evolvable**. That is the reason for the whole exercise; everything below is downstream of it.

## The point: the counting is not in Push any more

Before this, `execDoRange` kept its bounds as loose ints on `.int` and rebuilt its own recursion as Push
source every single pass:

```
.exec top→bottom:  y  body  .codeDo  newCounter  x  body  .execDoRange
```

Every pass re-pushed both bounds, a fresh copy of the body, and a fresh `.execDoRange` token — the
counting was *done in Push*, and the loop's state was smeared across `.int` and `.exec` where anything
could disturb it, and where it could not be reasoned about as a thing.

Now:

```
.exec top→bottom:  body  .codeDo  .iteratorPlay
```

and that is all. The bounds, stride and cursor are inside the iterator resting on `.iterator`. State
escapes by stepping, or through a getter, and by no other route.

## The core insight: the cursor is always an Int

**Everything an iterator emits is a projection of one `Int` cursor.** This is what lets one type cover
every case:

| kind | state | projection at cursor `i` |
|---|---|---|
| `.counting(stride:)` | `origin`, `destination` : IntItem | `origin + i × stride` → `.int` |
| `.elements` | `origin` : String/Vector | `origin[i]` → the scalar stack |
| `.sampling(steps:)` *(not built)* | `origin`, `destination` : DoubleItem | `origin + i × (dest−origin)/steps` → `.double` |
| any walk, `laps > 1` | + `laps` : Int | `origin[i % sourceCount]` → the scalar stack |

### Cycling: the cursor is monotone, the projection wraps

`laps` makes a walk go round its source again — `[a b c]` cycled three times emits `a b c a b c a b c`.
It is an **attribute rather than a kind**, which is the whole reason it costs nothing: at `laps == 1` the
wrap is the identity, so one expression serves both and there is no second code path to keep honest. It
composes with `.points` for free when that lands.

**The cursor does not rewind, and that is the design.** Only the index wraps. Resetting the cursor to 0
at the end of a lap is observably identical *this pass* and wrong forever after:

- `reconstruction()` names the cursor, so a rewound cursor rebuilds an iterator that has done no laps —
  and the crux stops being a fixed point;
- with nothing else to count by, an iterator that rewinds its only state is **infinite**. Bounding it
  would need a second counter, which costs the type its one invariant.

**It costs provenance nothing.** `element(at:)` records `origin index .vecIntNth`, and for a wrapped
index that record is already right: element 2 of the third lap *is* element 2. No new `Nth`, no new
record, still O(1).

Only the walking kinds cycle. `.counting` keeps its span in `destination` and `.repeating` its count;
laps there would be a second number for something the iterator already knows — and `.repeating` **is** a
cycle of length 1 run `destination` times, which is worth noticing but not worth collapsing. A sawtooth
counter is a cycling walk over a vector of the numbers.

The interesting consequence is a budget one, and it is in Design Principles §12: a lap is a number the
*program made up*, so cycling moves a walk from fact to claim and `maxIterations` starts applying to it.

A Double range needs no Double counter, which is what makes this hold: initialize by a number of steps
(which fixes the stride from the endpoints) or by a stride (which fixes the step count by division). The
`Int` cursor stays the ground truth either way.

## The instruction family

A **pass** is: emit the projection (if the iterator emits at all), push `body` and `.codeDo`, advance
the cursor, and put the iterator back. The body runs *between* the payload and any continuation, which
is what lets it see — or steal — the iterator.

| instruction | what it does |
|---|---|
| `.iteratorStep` | One pass, by hand, no continuation. |
| `.iteratorPlay` | One pass + its own next copy buried `burial` items under the payload. **The only continuation token.** |
| `.iteratorPlayDelayed` | Pops a burial **once**, stores it on the iterator, then plays — handing off to `.iteratorPlay`. `< 0` ends the loop; `0` is an ordinary tight loop; `> 0` interleaves. |
| `.iteratorPopState` | Advance without emitting — skip a pass. |
| `.iteratorPeekStart` / `.iteratorPeekEnd` / `.iteratorPeekStride` / `.iteratorPeekBody` | The getters. Non-destructive. |
| `.iteratorFromIntRange` | Construct only, never runs. Exists for `crux()`. |
| `.iteratorPrint`, + the 15 combinators | The usual per-type furniture. |

### Burial, and argument starvation

Every iterator carries a **`burial`** (always ≥ 0): how deep in `.exec` it hides its next copy. Zero —
what every tight loop carries, because the creators of tight loops simply never gather one — puts the
copy directly under the payload. A positive burial lets other pending work run in between, so the loop
interleaves rather than monopolising `.exec`. That is a coroutine, without the `.execShove` gymnastics.

**`.iteratorPlayDelayed` originally re-read its delay every pass, and that was a dead end.** A
thousand-pass loop would eat a thousand `.int`s — deepening *argument starvation*, the Push design flaw
this whole effort is meant to relieve. It now reads the depth once, stores it on the iterator, and hands
the loop to a plain `.iteratorPlay` that consumes nothing. A `.iteratorPlaySlow` was considered as a
separate "persisting" variant and rejected: it collapses into this, and one play mechanism is better
than two.

Burial is *state*, not a passing argument — two iterators alike but for where they hide their next copy
behave differently — so it is part of `isEqual`, part of the `AnyItem` envelope, and carried by the
constructor for `crux()`.

### Can a tight loop be paused? (measured)

**Yes, and burial is the only self-contained way.** A body that runs `2 .iteratorSetDepth` re-aims its
own loop, and the next pass's continuation lands two items deeper in `.exec`, so pending work runs in
between. Traced, with five pending items behind the loop:

```
tight (burial 0):     play play play  true true true true true
body sets depth 2:    play play  true true  play  true true true
```

Everything else needs something the loop may not have:

- **The continuation token is anonymous.** `.iteratorPlay` advances whatever is on top of `.iterator` —
  not "its" iterator. So `.iteratorSwap`/`.iteratorRot`/`.iteratorYank` pause a loop by displacing it,
  and the pending token simply plays whoever surfaced. "Pause this loop" and "run that loop" are the same
  operation, which is why two loops interleave by trading places. **But it takes two**: with a lone
  iterator on the stack, swap and rot have nothing to swap with and shove is a no-op.
- **`.exec` surgery** on the token — `.execYank`, `.execPopItems` — works but is blunt and
  depth-dependent, and the body has to count.
- **`.iteratorPop`** kills rather than pauses, and so do the setters that empty a loop (`0
  .iteratorSetLaps`, a negative depth, a counter carried past the end).

**The gap this leaves: a lone iterator cannot be shelved.** There is no `.iteratorQuote`, so an iterator
cannot be moved to `.code` and parked — even though a CodeItem can perfectly well hold one (§7b), and
`( «iter» ) .codeDo` would restore it via `pushDefault`. The five quotes are bool/char/double/int/string,
and iterators were not considered. That is the missing instruction if parking is ever wanted.

**A wart, found while measuring this.** On the last pass, `.iteratorPlay` deliberately re-pushes neither
the iterator nor a continuation — but the **body still runs**, and a body that re-aims its own loop
therefore reaches for an iterator that is already gone: `iteratorSetDepth missing args: .iterator` on
`.error`, once, on the way out. It is honest and it is documented behaviour, but any self-modifying loop
pays it.

### Bodies are optional

`body: CodeItem?`. **nil means a sequence rather than a loop**: it only emits its elements, and a pass
costs one step instead of three. That is what keeps exploding cheap — a 200-character string costs 200
steps, not 600, which against `stepLimit` is a difference in behaviour and not merely speed.

`init` normalizes an *empty* body to nil, so `CodeItem([])` can never exist to be confused with "no
body". That is what lets one constructor per source serve both forms: a crux writes `( )` for a bodyless
iterator and gets nil back. An empty body is a no-op body, so nothing is lost.

**Termination never dangles.** On the last pass neither the iterator nor a continuation is emitted. A
stray continuation can only arise if the body removed the iterator, and then "missing args" is the
honest answer. Because `gather` is all-or-nothing, `.iteratorPlayDelayed` meeting an empty `.int` leaves
the iterator *un-popped*: the loop stalls with its state intact rather than vanishing.

## Provenance

Two results, both better than expected — see "Provenance and the crux.md" for the full story.

1. **The folding node was deleted.** `steppedCall` existed only to rediscover, by pattern-matching on
   `call`, something the loop already knew. The iterator knows its origin and cursor, so the counter
   just says so: `[origin, IntItem(cursor × stride), .intAdd]`. Same crux, same O(1), no special node.
2. **The iterator's own `call` reconstructs it by state**, not by history:
   `origin dest stride cursor emits (body) .iteratorFromIntRange`. O(1) forever, and it keeps the link
   to how a computed bound was computed, because `origin.crux()` expands.

**Law 1b extends from CodeItems to iterators**: containment is combinatory, so `.iteratorPeekStart`,
`.iteratorPeekEnd` and `.iteratorPeekBody` hand back the items that went in with their `call` untouched.
`.iteratorPeekStride` is the exception that shows the rule — no contained item to give back, so it records
under law 3.

## The destination is excluded (a real bug, found here)

`4 7 .execDoRange` emits **7, 6, 5** — never 4. The old base case fired at `|current − dest| ≤ 1`
*having already emitted* `current`, so the last index is one short of the destination. Both
`Specifications/exec.md` and the code comments claimed "inclusive" and were **wrong**; both are now
fixed.

The generalization `|dest − current| > |stride|` is bit-for-bit identical at stride ±1 and extends
sensibly (0→10 by 3 emits 0, 3, 6, 9), so the behavior is preserved exactly.

Whether it *should* be inclusive, to match Push3, is a separate open question — it would change every
loop's output, and is deliberately not touched here.

## Decisions worth knowing

- **Getters are non-destructive.** Push convention says an instruction eats its argument, and
  `.iteratorDup` is right there. But an iterator is a live loop, not a value: a getter that killed the
  loop to report its stride would be unusable in the body, which is exactly where a program wants to
  ask. `.iteratorPop` is there for anyone who wants it gone.
- **Storage is `origin` + cursor, not a shrinking remainder** — a remainder cannot satisfy an
  origin+offset crux, which needs the original. This is unobservable either way: with no cursor getter
  and `.iteratorPeekStart` returning the original, nothing in the surface can tell which way it is stored.
- **`execDoCount` and `execDoTimes` now differ in exactly one flag** (`emits`). `execDoCount`'s
  rewrite-into-`execDoRange` delegation is gone; both build their iterator directly. Both use
  `destination = x`, *not* `x − 1` — since the destination is excluded, counting 0 toward `x` is exactly
  `x` passes.
- **`.execDoRange` and friends left `PushInstruction.iterators`**, because they no longer re-push
  themselves; `.iteratorPlay`/`.iteratorPlayDelayed` are the runaway guard's in-flight signal now.
- **`.iterator0…9` constants were skipped** — there is no literal iterator syntax to seed them from.
- **Stride is not reachable from `.execDoRange`**, which always builds ±1: the instructions keep their
  arity. The type carries stride; new constructors are how it gets set.

## Everything that produces many things is an iterator now

The five `*Iterate`, the explode family (`stringPushAllChars`, `stringParseToLetters`, `stringSplit`,
`vecXPushAll`), and both dup families across all thirteen stacks. Three things fell out:

- **Law 5 has no users.** `Behavior.selecting`/`<stack>PopItems` answered "which of these k results am
  I?"; an iterator never produces k results at once, so an element says what it *is* (`s 2 .stringNth`)
  instead. The machinery stays for any future multi-result Behavior; nothing emits it.
- **`xDupTimes`'s bespoke `maxStackDepth` guard is gone.** It was the only per-instruction size check in
  the language, and it existed purely because the instruction exploded. Copying over `count` passes puts
  the work back under `stepLimit`, the push boundary, and the runaway guard — which now catches a runaway
  `dupTimes` by itself, because `.iteratorPlay` on `.exec` is exactly the control-side signal it looks
  for. It could see none of that when the copies arrived in one step.
- **The box is the universal origin.** A CodeItem holds any item, so `( item ) count cursor burial
  .iteratorRepeating` is **one** constructor for all thirteen stacks rather than thirteen. Law 1b makes
  it free: the item that comes back out is the item that went in.

### `.exec` interleaves now, deliberately

`execDupItems` boxes its copies and walks them, which makes it in essence a first `.codeIterate` — but
emitting onto `.exec` means **run**, not **place**. Each copy executes before the next is emitted, where
they used to be laid down contiguously and run as a block. So `execDupItems 2` over `7 .intInc` now runs
the copied `.intInc` *before* the copied `7` arrives; it complains and the loop carries on.

Every other stack rests its elements, so only `.exec` notices. This is a real change of meaning, taken
knowingly as the price of one uniform mechanism.

## Collecting: a sequence as a value

`.vecFromIterator` drives an iterator to exhaustion **in Swift, inside one step**, and hands back a
vector of what it emitted. The mechanics of iterating were never meant to be done in Push, and this is
that principle applied to the result rather than the loop.

Three things it settles:

- **The result type is the argument's** — one instruction, four result stacks, read off what actually
  came out rather than off the kind. That is what lets it exist without a sieve, and it answers question
  1 of "Sieve arguments" in the affirmative: the vector case never needed one.
- **`.codeFromIterator` is the general form, and never refuses.** A CodeItem is the vector-of-anything
  (§7b), so every iterator has an answer there: a tree walk emitting subtrees, a mixed block, a string's
  chars. Read the pair the right way round and the asymmetry disappears — **a vector is the special case
  where the emissions are uniform scalars**, and `.vecFromIterator` points at its sibling when it turns
  something away. It is also one of the few genuine *producers* of `.code`, the scarcest stack there is.
- **Nothing chooses a length.** Every kind was already bounded before it could be an argument (§12), so
  the question "how long should a collected vector be?" turned out to be already answered, twice, for
  two different reasons.
- **It follows the pass protocol, not `isSpent`** — emit at the cursor, stop when `hasNextPass` says the
  last has gone by. `execDoRange` is deliberately not inclusive of its destination, so a collector using
  the other rule would return a longer sequence than the same iterator emits when *played*, and the
  language would contradict itself. Collecting and playing must agree, and there is a test that says so.

Two deliberate asymmetries with playing, both of which follow existing rules rather than inventing any:
**`emits` is ignored** (it exists to keep an index off `.int` while a body runs; collecting has no body
and litters nothing), and **a success returns the body to `.code`** unrun — the same farewell every
other ending pays. A *refusal* hands the whole iterator back, as the setters do.

## Next

- **map/filter** — the iterator needs somewhere to *collect* body results, not just emit them: an
  accumulator field plus a rule for reading what the body left. This is what the "pseudofunction" work
  wants. Note `.vecFromIterator` is **not** this: it collects projections, and never runs a body.
- **`.points(into:)`** — the zipper walk of a code tree. The architecture already admits it (a pre-order
  walk is a pure function of `(origin, cursor)`, which is all a projection must be); it wants
  `codeNthPoint` implemented and a memoized point-count on `CodeItem` first.
- **`.sampling(steps:)`** for Double ranges, and behaviors that make iterators from other sources.
- **A real `.codeIterate`**, which would give the boxed-code walk an honest name of its own.
## Fixed in passing

**`run(stepLimit:)` ignored its argument entirely** and looped on `config.stepLimit` — found because it
silently ran a mid-flight test to completion. It now rewrites `config.stepLimit`, and the rewrite
sticks: it is that instance's limit from then on, not a loan for one call.

The parameter became `Int?` rather than keeping its `Int = defaultSettings.stepLimit` default, because
"not given" and "given the default" have to mean different things here. `Runner.evaluateOne` sets
`interpreter.config = configuration.settings` and *then* calls bare `run()`; had the argument defaulted
to 1000 and assigned unconditionally, honoring it would have clobbered every configured run in the
Runner. Omitting it now means "leave `config` alone", which is exactly what every existing bare caller
already relied on.
