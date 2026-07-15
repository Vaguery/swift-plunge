# Provenance and the crux

*Design note. Started 2026-07-15, during the work to bound `.call` growth.*

## What the crux is for

Push programs resist reading. Instructions and their arguments appear in any order and at any distance
from one another; combinators rearrange the stacks at runtime; `CodeItem` blocks get restructured,
concatenated, and duplicated, so a value can surface somewhere entirely unexpected. When a promising
program evolves — one that really does turn `.input` arguments into the values you wanted — it is
usually still opaque *why* it works, and therefore unclear what to change to make it work better.

The **crux** answers that. It is built from the `Item.call` recorded when an item is created, and from
the `call`s of those items, recursively.

> **The obligation.** Running an item's crux on a fresh interpreter reproduces that item's value, on
> that item's stack.

That is the whole contract. Note what it does *not* say: it is **not a trace**. It does not have to
say what happened. It has to be *runnable*, and it has to *land the value in the right place*.

## Why the record was growing without bound

Combinatory logic cannot affect the obligation. If a value sat on `.int` and `.intSwap` moved it, the
program that produced it still produces it. So combinatory steps must not be recorded — and recording
them is exactly what made `call` grow.

Push has explicit combinators (`.intSwap`, `.vecBoolYank`), but it also has **tacit** combinatory
processes, and those are where the bugs were:

- Being placed into a `CodeItem` block, which may be restructured and concatenated but by convention
  never has its contents' `.value` changed.
- The `.exec` iteration and looping instructions. Each one preserves some counting or repeating
  continuation state and duplicates a body item every pass — a simple combinator's job. This only
  became clear recently, and the implementations predate the insight: they record the loop's
  bookkeeping into the `call` of results that a combinator should have left alone.

The result grew *and* was wrong. `execDoRange` recorded `newCounter.call = [y, x, .execDoRange]`, where
`y` is the previous counter — so depth grew by one per iteration, and `y x .execDoRange` does not
produce `y+1` anyway.

## The law

For each result a Behavior returns:

1. **Rearrangement within one stack is free.** The result keeps its argument's `call` untouched.
   Covers `dup`, `swap`, `rot`, `dupItems`, `dupTimes`, `pop`, `flush`, `yank`, `yankDup`, `deepDup`,
   `shove`, the exec combinators `execK`/`execS`/`execIf`, and every body copy or re-pushed
   continuation token an iteration emits.

2. **Relocation across stacks is not free.** `.intQuote` moves a value from `.int` to `.code`; a crux
   that omitted it would leave an int where a code item belongs. These record
   `call = [args…, InstructionItem(name)]`.
   *Transit does not count* — an argument pushed to `.exec` that `pushDefault` returns to `.int` has
   moved nowhere, so rule 1 applies.

3. **A genuinely new value** records `call = [args…, InstructionItem(name)]`, args in the order that
   re-runs postfix, instruction last.

4. **A freshly minted instruction token records nothing.** Its crux is itself; it is a literal.

5. **Several results on one stack** each record, in their own `call`, the discard that surfaces them —
   a count and the stack's `PopItems` — where the count is taken **from the end of that stack's
   results, not the order they were produced in**.

The line between rules 1 and 2 is worth stating plainly, because "does it change the value?" is the
wrong test — `yank` and `.intQuote` both leave the value alone. The test is **where the value comes to
rest**: shuffling within a stack is invisible to the obligation; moving to another stack is not.

### Rule 5 in detail

`Behavior.distribute` prepends Routers in order, so the **last** Router pushed ends up on **top**. For
`N` results on one stack, the item produced at position `i` needs `N - 1 - i` pops:

```
Routers [r0, r1, r2] pushed in order  →  stack top→bottom: r2, r1, r0
r0 produced first, lands on the bottom  →  2 pops   (not 0)
r2 produced last,  lands on top         →  0 pops   (not 2)
```

Count `N` and `i` among **same-stack results only**. `stringIterate` emits one `.char` plus several
`.exec` items, so `N = 1` on `.char` and its char needs no discard.

The discard goes **directly into the `call`** (via `Behavior.selecting`), as ordinary items:

```
call: [s, .stringPushAllChars, IntItem(2), .charPopItems]
```

so `crux()` needs no special case at all — it walks `call` and each element speaks for itself:

```
"abc" .stringPushAllChars     →  stack top→bottom: c, b, a

crux(c) = "abc" .stringPushAllChars
crux(b) = "abc" .stringPushAllChars 1 .charPopItems
crux(a) = "abc" .stringPushAllChars 2 .charPopItems
```

This composes, because each fragment leaves its value on top of its stack:

```
crux(a) ++ crux(x) ++ [.charAdd]
  = "abc" .stringPushAllChars 2 .charPopItems  <x>  .charAdd
```

**There is no `index` field.** There used to be, holding this position, and it was deleted during this
work. It was redundant once the pops could live in the `call`, and it was actively harmful: it carried
three incompatible meanings at once (mother-block ordinal, Router position, element ordinal), only one
of which `crux()` honoured; several behaviors set it on items that kept a *pre-existing* `call`, which
the old `crux()` would then use to index an unrelated block with no bounds check. Recording the pops as
items also puts the knowledge where it belongs: the Behavior knows exactly what it pushed and where, so
it states the selection outright rather than leaving `crux()` to re-derive a stack from the item's type.

## Referring to the nth of k results

This was an open question — how would a `.complexReIm`, returning the real and imaginary parts of a
complex number, let each part's crux produce *just* that part? It looked like Push had no syntax for it.

It does, once rule 5 is in place. The parts land on `.double` in a known order, so selecting one is
just discarding what sits above it. The new `<stack>PopItems` combinator (one per stack, generated by
the same family as `DupItems`/`DupTimes`) takes an `.int` and drops that many:

```
crux(im) = <c> .complexReIm                    // im is on top already
crux(re) = <c> .complexReIm 1 .doublePopItems  // discard im, exposing re
```

No new syntax, no new semantics to specify — and it is genuinely runnable, which is the whole point.

Note this leaves debris below the value (`crux(im)` leaves `re` stranded on `.double`). That is
harmless: the obligation is about the value's own resting place, not about a clean stack.

## The iteration counter

Some growth is honest. A loop counter really does get 1 added to it every few steps, so it has a real
excuse for a large call tree — its crux is `y0 1 .intAdd 1 .intAdd 1 .intAdd …`, faithful and O(n).

The idea of an `IteratorItem` to collapse this ran into an objection: an `IteratorItem` would itself
have a growing call tree, so it wouldn't reduce anything.

**The objection dissolves if the `IteratorItem` is a provenance-only node whose own `call` is always
empty.** It is self-describing — a `base` and an `offset` — it never lands on a stack, and it exists
only *inside* another item's `call`:

```swift
public struct IteratorItem: Item {
    var value: Int        // the offset
    var base: any Item    // fixed for the life of the loop
    var call: [any Item]  // ALWAYS [] — this is what stops the growth
    // crux() = base.crux() + [IntItem(value), InstructionItem(.intAdd)]
}
```

Because `base` never changes across iterations, stepping is `offset + 1` on the same base:

```
c1.call = [Iterator(y0, +1)]
c2.call = [Iterator(y0, +2)]
c999.call = [Iterator(y0, +999)]      crux = y0 999 .intAdd     O(1), and correct
```

That is the "in this period I was incrementing" pseudo-step, as literally one node. Negative offsets
cover `execDoRange`'s downward direction.

**Known caveat:** folding is not overflow-faithful. With `y0` near `Int.max`, adding 1 a thousand times
errors at a different step than adding 1000 does. Accepted deliberately.

### To revisit: extending IteratorItem

**Counting down and counting by an increment already work**, without a new field. `offset` is a signed
running total, and `steppedCall(from:by:)` takes an arbitrary step, so a descending loop folds to a
negative offset (`60 -49 .intAdd`, which the tests pin) and a loop striding by 3 folds to `9`, `12`,
`15`… Even a *varying* stride accumulates correctly, because the total is all the reconstruction needs.

What an additional field would buy is **structure rather than net effect**. `offset` records *where the
counter ended up*; it cannot say *how it got there*. A `step` field alongside a count would distinguish
"333 passes of +3" from "999 passes of +1" — identical as `y0 999 .intAdd`, different as explanations.
Since the whole point of the crux is explaining an evolved program, that distinction may be worth
having. It costs nothing in the emitted source: the crux stays `base (step × count) .intAdd`.

The case `offset` genuinely **cannot** express is non-additive stepping — a loop that doubles each pass.
That needs an operation field (add vs. multiply, or a general step instruction), at which point
`IteratorItem` becomes something closer to "a fold of a known operation over a known count", and
`crux()` emits that operation instead of a hard-coded `.intAdd`. Worth designing only when a
multiplicative iterator actually exists in the language.

### To revisit: an IteratorItem inside a running program

The stated goal is that a crux is *runnable code*, which raises the obvious question about a node whose
whole design is to be provenance-only.

**Today the invariant holds by construction, not by luck:** `crux()` never emits an `IteratorItem` — it
expands to `base.crux() + [offset, .intAdd]`, all ordinary items — so no crux can contain one, and no
reconstruction can encounter one. Nothing in the language constructs one either; only `steppedCall`
does, and only into a `call`.

But `IteratorItem` *is* an `Item`, so nothing at the type level stops one being placed in a program by
hand or by a future instruction. If that happened: `defaultStack(for:)` returns nil, so `pushDefault`
routes it to `.error`, where `requireAccepts` rejects it and records an `INVARIANT:` marker. It is
caught and named rather than silently corrupting a stack — which is the current, deliberate answer:
**it is not runnable, and it says so loudly.** `.exec` accepts any item, so it is not self-policing
there; it would be caught one step later when popped.

The open question is whether that should change. Two coherent positions:

- **Stay provenance-only.** An `IteratorItem` in a program is a bug, and the `INVARIANT:` marker is the
  right response. Simplest, and matches the current tests.
- **Give it runtime semantics** — evaluate to `base + offset` on the appropriate stack, making it a
  legitimate (if unusual) literal. This would make the type fully first-class and would matter if
  `IteratorItem` ever wanted to appear in a crux directly rather than expanding.

This gets sharper after the CodeItem change: once a `CodeItem` reaches `.code` intact rather than
unwrapping, an `IteratorItem` could ride inside a code block and travel further before being noticed.
Worth settling then.

## The backstop

Genuine accumulation that is *not* a loop counter — `x 1 .intAdd` in a loop body — is honestly O(n) and
no folding rule can help.

`call` is bounded by a weight budget, mirroring how `Item.weight` and `maxItemWeight` bound value
content. When an item's `callWeight` exceeds `maxCallWeight`, its `call` is set to `[]` at the push
boundary.

**This can never break the obligation.** `crux()` returns `[self]` for an empty `call`, and a bare
literal *is* a runnable program producing that value. Elision costs the story, never the correctness.
That asymmetry is what makes an aggressive budget safe.

It is deliberately *not* an error: unlike `overflow(of:)`, which refuses the push and emits an
`ErrorItem`, elision pushes the item normally and merely forgets where it came from.

## Growth that remains, by design

- `x 1 .intAdd` in a loop body that is not the loop counter: honestly O(n), bounded by the backstop.
- `stringIterate`/`vecXIterate`'s shrinking working string is genuinely derived each pass, so its chain
  is honestly O(n). Bounded by the backstop rather than by a second folding mechanism.

## Relationship to the CodeItem change

This work lands *before* the planned change where the Interpreter pushes a `CodeItem` to `.code`
intact instead of unwrapping it onto `.exec` (and `.exec` instructions take their arguments from
`.code`). Sequenced first deliberately:

- The exec fix is almost entirely **deletion** — `execDoRange` goes from ~15 provenance lines to ~2 —
  and deleted lines cannot be invalidated by a later rewrite of `takes:` and Router targets. The exec
  behaviors arrive at that change smaller.
- The CodeItem change then fixes two things *for free*, so no effort is spent on them here:
  `unwrapCodeItem` currently discards a block's `call` and `index` on unwrap (which is why `execIf`'s
  recorded `call` is already dead code today), and an `.input` bound to a code block currently loses its
  `[.input1]` provenance the moment it unwraps.

## Deliberately not addressed

- `vecXPushAll` puts element 0 on top; `stringPushAllChars` puts the *last* char on top. A real
  semantic inconsistency between siblings, but changing it changes language semantics. Flagged only.
- `==` walks the entire provenance DAG, so it is O(chain). Bounded chains make this tolerable.
- `RecordedTrace` and `RecorderSpec` both claim in comments to retain `call` provenance for downstream
  analysis. They do not — `AnyItem` drops it. Either the comments are wrong or the export is missing;
  the unimplemented `codeFuncFrom_Crux` family in `Code instruction planning.markdown` suggests the
  latter was the plan.
- `execWhile` records its continuation as `.execDoWhile`, following the klapaucius note it was ported
  from. Now moot for provenance (both are combinatory and record nothing), but the naming remains.
