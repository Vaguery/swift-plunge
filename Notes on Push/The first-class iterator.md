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

## Next

- **The five collection iterates should adopt this.** `stringIterate` and the four `vec*Iterate` (one
  generic factory) build `.elements` iterators. The machinery is already written and tested —
  `IteratorItem.element(at:)` records `origin cursor .vecBoolNth`, O(1), replacing today's `.stringRest`
  chain, which is O(n) and bounded only by the backstop. Needs five `.iteratorFromX` constructors.
- **map/filter** — the iterator needs somewhere to *collect* body results, not just emit them: an
  accumulator field plus a rule for reading what the body left. This is what the "pseudofunction" work
  wants.
- **`.sampling(steps:)`** for Double ranges, and behaviors that make iterators from other sources (every
  word of a string).
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
