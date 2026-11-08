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
> that item's stack. **And every literal that stands in for a lost history is marked** (a *stand-in*;
> see § Stand-ins). *(The second sentence was added 2026-11-07.)*

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

> **Read the "DONE" subsection at the end of this section first.** The reasoning below is how the
> counter problem was solved the first time, and it is kept because the *argument* is still the point.
> But the provenance-only `IteratorItem` it describes no longer exists: making the iterator first-class
> made the folding node unnecessary, and it was deleted.

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

*(Partly overtaken: the first-class type has a real `stride`, so the "structure vs net effect" question
below is answered for the additive case — the iterator records 333 passes of +3 as `stride: 3` and a
cursor of 333, which says exactly how it got there. The multiplicative case is still open. The rest of
this subsection is kept for that argument.)*

**Counting down and counting by an increment already work**, without a new field. The offset was a
signed running total taking an arbitrary step, so a descending loop folded to a negative offset
(`60 -49 .intAdd`, which the tests still pin) and a loop striding by 3 folded to `9`, `12`, `15`… Even a
*varying* stride accumulated correctly, because the total is all the reconstruction needs.

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

### DONE: IteratorItem is a first-class type, and the folding node is gone

**Everything above about the folding node is now history.** `IteratorItem` is a proper Push type: its own
`.iterator` stack, its own combinators, its own getters, produced by the `exec` looping instructions and
by `.iteratorFromIntRange`. See "Notes on Push/The first-class iterator.md" for the design.

The part worth recording *here* is what that did to provenance, because it is not what this document
predicted. The plan was that a first-class iterator would be popped and pushed as part of the loop's
transaction, with the provenance-only node carrying on inside `call` as before. **What actually happened
is that the node became unnecessary and was deleted.**

The reason is that `steppedCall` only ever existed to *rediscover* something the loop already knew. It
pattern-matched `from.call[0] as? IteratorItem` to work out "is this counter already an offset from some
base, and if so which?" — a question with an obvious answer that was simply not written down anywhere.
Once the iterator holds its own origin and cursor, the answer is right there, and the counter can name
its origin and offset in ordinary items:

```
counter.call = [origin, IntItem(cursor × stride), .intAdd]      crux: y0 999 .intAdd
```

Identical crux, identical O(1) bound, no special node, no folding rule, and no `crux()` override. The
whole apparatus collapses into one arithmetic projection (`IteratorItem.projection`). `IteratorItem` now
appears in nobody's `call` at all — it only rests on `.iterator`.

Two things this document worried about also dissolved rather than being solved:

- **`elidingOverBudgetProvenance` was a no-op on the type** — it clears `call`, but the old
  `callWeight` was computed from `base`, a stored field, so the budget could never bite. A real `call`
  plus a stored `callWeight` puts it back under the same backstop as everything else.
- **`AnyItem` could not encode it**, because `base` was reachable only through `call`, which the
  envelope drops by contract. The first-class type's origin, body, bounds and cursor are *value* fields,
  so the envelope carries them without breaching that contract.

The iterator's own `call` reconstructs it **by state** rather than by history —
`origin dest stride cursor emits (body) .iteratorFromIntRange` — which is the same self-describing trick
the old node used, generalized. O(1) forever, because origin, destination and body are fixed for the
loop's life and only the two literals change. And it keeps the link to *how a bound was computed*:
`origin.crux()` expands, so a loop over a computed range still explains where the range came from.

## The backstop

Genuine accumulation that is *not* a loop counter — `x 1 .intAdd` in a loop body — is honestly O(n) and
no folding rule can help.

`call` is bounded by a weight budget, mirroring how `Item.weight` and `maxItemWeight` bound value
content. When an item's `callWeight` exceeds `maxCallWeight` (or its depth `maxCallDepth`), its `call`
is replaced at the push boundary by a single **elided stand-in**, `.intAdd_elidedAs_4537` (§ Stand-ins).
*(Until 2026-11-07 it was set to `[]`, which left a bare literal no one could tell from a literal in the
program.)*

**This can never break the obligation.** A stand-in *is* a runnable program producing that value, and
it says it stands in for a dropped history. Elision costs the story, never the correctness, and now the
loss is visible. That asymmetry is what makes an aggressive budget safe. It is the last resort, and
since 2026-11-07 it comes after two lossless steps: the budget measures the crux, which builds each
shared node once (§ Sharing), and a loop's chain is folded into a counted loop
(`CruxCompression.folded`; *Compressing looped provenance*). What is still elided is a history that is
long without repeating itself, or deeper than `maxCallDepth` without being one loop's chain.

It is deliberately *not* an error: unlike `overflow(of:)`, which refuses the push and emits an
`ErrorItem`, elision pushes the item normally and merely forgets where it came from.

## Stand-ins (2026-11-07)

A bare literal satisfies the first half of the obligation for any item, which is exactly why it was a
loophole: elision and law 4b both substituted literals, and the result looked like a literal the program
contained. Nothing could count how much of a run's provenance was really derived. A **stand-in**
(`StandInItem`) is the mark.

- **It runs as the literal it replaces.** On `.exec` it pushes a copy of its value whose `call` is the
  stand-in, so a replay reproduces the original item exactly, history included.
- **It names its cause**: the instruction that observed or produced the value (or the interpreter, for
  its own diagnostics), and why: `.observed`, `.elided` or `.minted`.
  - `.boolStackDepth_actuallyWas_4`: a state read (law 4b).
  - `.intAdd_actuallyWas_« ‼️ intAdd missing args: .int »`: an error from transient stack state.
  - `.interpreter_actuallyWas_« ‼️ string length 6 exceeds maxStringLength 3 »`: an interpreter diagnostic.
  - `.intAdd_elidedAs_4537`: an over-budget history.
  - `.execDoTimes_minted_0`: a constant the instruction supplies itself (`.minted`, added the same day).
    Nothing is lost, since the instruction *is* the cause, but without the mark the counter's first value
    could not be told from a substitution. The completeness probe counts `.minted` as fully derived.
- **It is a literal leaf.** Its own `call` is always empty, so `crux()` emits it unchanged, and it
  appears in every crux computed from it: `8 .intStackDepth_actuallyWas_2 .intAdd`.
- **It has no stack of its own**, like an instruction; it only rests on `.exec`, and `AnyItem` encodes
  it (a nested item plus its label).
- **It is not forbidden in code.** In an evolved program it is a labelled constant, so no "crux-only,
  illegal in code" category is needed.
- **It costs the search nothing.** It is built only inside `recording(…)`, so with provenance off no
  stand-in is ever made (`observed(by:_:)` returns at once).

A stand-in carries the cause's *name*, not the cause. A fuller record (say, the cruxes of the items a
`StackDepth` counted) could ride along later as a non-running annotation, without claiming to reproduce
anything.

**Overlap with local variables.** A future `.ref` (Roadmap #39) also wraps one item under a name: a
mutable binding where a stand-in is an immutable label. The envelope keeps the shape generic so the two
can share it. Under every storage design being considered, a variable read that hands back the bound
item's own history needs no stand-in; stand-ins arise only for facts *about* the bindings.

## Sharing (2026-11-07)

Provenance is a DAG. When one value feeds several others, every history that uses it holds the very same
node: `.intDup` copies an item with its history (law 1), and a non-destructive read (`.boolEq`, `.vecIntNth`,
any query) records the argument it read *and leaves it on the stack* for the program to use again. Until
now `crux()` wrote out the tree, so a shared node appeared once per use: `x x .intAdd` where the program ran
`x .intDup .intAdd`.

That mattered more than it looked. **Every history the round-trip fuzz saw elided was a shared one**, not
a loop chain: a loop over a non-destructive read builds each value from the two before it, so N steps of
the program make a tree of fib(N) leaves. The elided items were 40–200 distinct nodes weighing 10,000–
20,000; none was elided for depth, and lifting `maxIterations` changed nothing.

**The crux now builds each shared node once** (`CruxSharing`). A node used by two or more argument
positions is built first, in a prelude, children before parents, and left on its stack. Each use takes a
copy (`.xDup` when it is on top, else `n .xYankDup`), and the last use takes the node itself (nothing when
it is already in place or only copies of it are above, `.xSwap` at depth 1, else `n .xYank`). The depths
are known because the crux keeps count of every stack as it writes. `x .intDup .intAdd` reads back as
itself; the 30-step `.boolEq` loop's crux is a few hundred items, not a million.

- **Only argument positions.** Reuse happens before the first instruction in a `call`, where every element
  pushes exactly one item (a node's crux nets its item on its stack; a literal pushes itself). After an
  instruction (a clean-up, a prefix argument read from `.exec`), elements are written out as before.
- **A fixed point.** Dup and yank record nothing, so the copy *is* the node, and a replay shares exactly the
  nodes the original shared. Nodes are identified by their `call`'s storage, which copies share and a value
  rebuilt another way does not, so two equal values computed twice stay two.
- **Nothing changes without sharing.** A history with no shared node comes out as the flattened tree, leaf
  for leaf (`CruxSharing.flattened`).
- **The budget measures the crux.** `callWeight` still sums the tree, so it is an upper bound. When it is
  over `maxCallWeight`, the push boundary writes the shared crux, stopping at the budget; if it fits, the
  item is kept and *weighed by its crux's length*, so its descendants sum real lengths and the walk is
  repeated only near the real budget. The decision depends on the history alone, so a replay makes the
  same one.

Results: elided items 0 in all three fuzz mixes (were 0.0%, 0.2%, 1.3% of value-stack items); 0 broken in
about 250,000 replays; the fuzz takes ~53 s (was ~40 s).

**Local variables would serve this better** (the user, 2026-11-07): bind each shared value once and read
it by name, with no depth bookkeeping. The planning would be unchanged. Roadmap #39.

## Containment (2026-11-07)

Law 1b says an item that goes into a block and comes back out is the item that went in, history intact.
It says nothing about an item that was **born inside** a block and never went in: the contents of a block
bound to `.input3`, the leaf a `.codeNthRoot` box holds, the inner block `.codeWrapPoints` makes when it
rebuilds `( 1 2 3 )` as `( 1 ( 2 3 ) )`. Such an item has no history, so `.codeDo` used to hand it out
bare. It reproduced its value, but its crux had lost the link to its container, so a result that depended
on `.input3` could have a crux that never mentioned it. The step-2 probe measured this as the largest gap
left: 15–17% of the items random programs leave on value stacks, plus the few rebuilt blocks that were
the only items with no trace at all.

**The containment law** (`Containment`): an item taken out of a container keeps its own history; if it
has none and the container has one, it records its **address**, the container, the position and the
instruction that takes it out from there, with the clean-up every non-destructive read records:

    .input3 1 .codeEmitNthRoot 1 .codePopItems .intSwap .intPop      ← the 6 out of ( 5 6 ), bound to .input3

- **Where.** `.codeDo` (root position, as `.codeEmitNthRoot`), the emit instructions themselves, and the
  iterator's element emission (`.codeEmitNthRoot` for a root walk, `.codeEmitNthPoint` for a tree walk).
  Every unwrap goes through `.codeDo`, so there is nowhere else a block's contents come out.
- **It is a fixed point.** The address is exactly what the emit instruction records, so replaying it
  reproduces the item with the same history.
- **A literal container's contents stay literals.** A block with no history is in the program text, and
  so is everything in it, so its contents come out bare, as before.
- **It costs the search nothing**: the check is behind `recording.isOn`.
- **It is representation-neutral.** Any container that can say "the thing at position k" can address its
  contents, and every representation with containers needs it.

After it (same 40 seeds × 5 programs × 2 mixes): bound-value contents 0, unmarked 0, and derived up from
70.6% to 85.1% (equal shares) and from 76.7% to 92.1% (loop-heavy). Elision is unchanged (≤ 0.2%), and all
199,510 replays hold. Some of the former bound contents now count as *observed*, because the block they
came out of has a stand-in in its history (equal shares: 5.6% → 8.4%).

**Vector and string elements** are the same law in a different shape (Roadmap #21, ruling P5). Their
elements are raw values, not items, so they cannot keep a history unless the container holds one for
them. When recording, a vector or string now keeps its **members**: first one slot per element, holding
the item that went in if it went in with a history, else nothing; then, the same day, a piece table
(below). They live in the container's provenance box
(`CallStorage`), so an item's inline size does not grow, and the search builds none.

- **In:** conj, set, replace, construct, `readItems`/`readStack`, `vecFromIterator`, `stringConjChar`,
  `stringSetChar`, `stringReplaceChar`, `stringFromChar`. **Rearranged** with their elements: slices,
  reverse, cut, concat, remove, sub-vector and substring replacement, words.
- **Out:** first, last, nth, and the iterator (pushAll, iterate, letters) hand back the member if there
  is one, else the address as before (`v k .vecIntNth`). An element's crux is then its own history, not
  the whole vector's plus a selection, which is what crux-to-function (#23) needs.
- **Strings check alignment.** Joining strings can merge characters (a combining mark after a letter), so
  members that do not line up character for character are dropped, and the characters are addressed.
- **The fixed point** needs every producer to attach the members a replay would attach, so a letter is
  built exactly as `.stringNth` then `.stringFromChar` build it.

Measured with a third fuzz mix, `.containerHeavy` (the vector and string instructions at twice a role's
share), because random programs almost never put a computed element in and take it out again: members
changed 5 items in about 5,500 under the other two mixes. Under `.containerHeavy`, members off → on:

| | derived | elided | taken out by address | mean crux length |
|---|---|---|---|---|
| members off | 81.5% | 5.2% | 30.3% | 69.9 |
| members on | 85.3% | 1.5% | 29.0% | 65.6 |

51,972 replays, 0 broken. Most of the elision members remove came from law-5 selections over long string
histories (`.stringPopItems` stand-ins: an element pulled out of a long-built string dragged the whole
string's history with it).

**A piece table (same day, the user's suggestion).** Most elements come from a few sources, so the
per-element slots became runs (`Pieces`): each run is either one item that went in, or a span of
positions of the **source** container the elements were born in, stepping forward or backward. Building
a container out of another one's elements carries their origins over, so an element is always addressed
from its source, never from an intermediate concatenation: the 4 out of `[1 2] [3 4] .vecIntConcat
.vecIntReverse .vecIntFirst` replays as `[3, 4] 1 .vecIntNth`, and an element of a bound constant names
the constant (`.vecInt3 1 .vecIntNth`). A container with no members is a source. Lookups are a binary
search over the runs.

Under `.containerHeavy` this moved derived from 85.3% to 85.6%, elision from 1.5% to 1.3% and the mean
crux length from 65.6 to 63.5, with 0 broken. How well it groups depends on how the elements got in:

| mix | vectors and strings with members | elements | runs | of which single items |
|---|---|---|---|---|
| equal shares | 901 | 7,954 | 1,304 | 493 |
| loop-heavy | 1,505 | 14,899 | 9,233 | 8,292 |
| container-heavy | 2,144 | 23,683 | 17,864 | 16,136 |

Elements born in a source group well, 4 to 9 per span. Elements that went in one at a time (conj,
construct, readStack, collecting an iterator) are one run each, no worse than the slots were. Grouping
*those* means recognizing a pattern in their histories (a counting loop's `origin k .intAdd`), which is
provenance compression, step 3.

## What checking the law actually found

Two acceptance tests check the obligation by *doing* it (`Crux RoundTrip Tests.swift`): one sweeps every
registered Behavior with synthetic arguments; one runs random programs to completion and asks every
survivor on every stack to prove its history. Between them they check ~21k provenance claims. This is
the only kind of test that can catch a `call` that *lies* — a unit test written by reading the code
transcribes whatever the code says, bug and all, which is exactly how `charGTE` came to record `.charGT`.

The sweep needs no RNG and stays enabled. The fuzz half is disabled by default like every other fuzz
test here, and the reason is worth knowing rather than inheriting: `fuzzRNG` is a `nonisolated(unsafe)`
global, and Swift Testing runs suites in parallel, so any other enabled test drawing from it consumes
the fuzzer's stream mid-generation. Enabled, it drew 21,123 claims on one run and 17,016 on the next
from the same seed. Fuzz tests here must be run alone to be reproducible.

*(Changed 2026-11-07: the crux fuzz is now always on. Each seed draws from its own generator in a
`withFuzzSeed` scope, so parallel suites cannot consume its stream; it runs 40 seeds × 5 programs under a
balanced and a loop-heavy mix and reports how complete every crux is. Other fuzz suites still share the
global generator and still run alone until they adopt the scope.)*

They immediately found two things worth recording.

**Every `StackDepth`/`StackIsEmpty` recorded a lie** (22 behaviors). They take no arguments; their value
comes from transient execution state. `.boolStackDepth` reported 4 because `.bool` happened to be 4
deep, but the crux `( .boolStackDepth )` re-runs on an empty interpreter and reproduces `0`. They now
record nothing, so the crux is the literal `4` — which reproduces exactly. That is law 4b, and the line
it draws is worth keeping in mind: `.input3` and `.int7` also read state, but *environment* state that
is re-supplied when a crux is re-run, so naming them does reproduce the value. The test is whether
re-running the name would find the same world.

**Every `xEq` compared provenance rather than value.** `eqCombinator` compares with `isEqual(to:)`,
which routed to `==`, which compared `value && call && isContingent` (that third field has since been
removed entirely — *Roadmap.md* §23a). So `2 3 .intAdd  1 4 .intAdd
.intEq` was **false** while `5 5 .intEq` was **true**. This also made `Comparable` incoherent — `<`
compares `value` alone, so two items both holding 5 were simultaneously not-less, not-equal and
not-greater, which is not a strict total order. `==` is now value-only, which fixes both at once. See
"Equality is about values" in `Items.swift`, including the open question about a *deep* identity
(`.xDup` copies an item's whole call tree onto its duplicate, so same-value-same-history does arise —
Push just has no way to ask).

Notably, the entire 450-test suite passed unchanged when `==` stopped comparing provenance. Nothing
relied on it. That is why it survived.

### Known gaps, pinned

Five behaviors provably cannot round-trip until the CodeItem change lands, and they are pinned as an
exact set (`knownGapsPendingCodeItemChange`) that fails if it grows *or* if it silently closes:

- `codeAppend`, `codeEq`, `codeItemIsEmpty`, `codeWrapRoot` — **a bare code block is not its own crux.**
  The corollary above ("a literal always reproduces the value") holds for every scalar and fails for
  `CodeItem`: a block in a program unwraps onto `.exec` and scatters, so it never reaches `.code`. Real
  programs mostly dodge this because their blocks come from `.intQuote`, which does land on `.code` —
  which is why the original `CruxTests` pass. This is also the one hole in the elision backstop: eliding
  a `CodeItem`'s call currently makes it unreproducible.
- `execEq` — **`.exec` arguments are consumed from ahead, so their crux is prefix, not postfix.** It
  inherits the shared `eqCombinator`'s postfix order, right for the other ten stacks and wrong here.
  `execQuote` gets this right today with a deliberate prefix `[.execQuote, x]`. After the change, exec
  instructions take arguments from `.code` and postfix becomes correct.

The fuzzer independently confirms the first: an `.input` bound to a code block has crux `( .input3 )`,
which scatters instead of landing on `.code`.

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
  *(2026-11-07: half true. The block kept its provenance, but its contents still came out bare when it
  was unwrapped; closed by the containment law, § Containment.)*

## A known leak: vector elements have no provenance of their own

*(Closed 2026-11-07 by members: see § Containment. The analysis below is kept as the reason.)*

`CodeItem.value` is `[any Item]`, so a block's contents keep their own `call` — which is what law 1b
rests on: an item goes into a block and comes out unchanged, history intact.

Vectors do not work that way. `VecIntItem.value` is `[Int]`, `VecBoolItem.value` is `[Bool]`, and so on —
**raw Swift values, not Items**. An element has no `call` and no `crux`. The drain is visible in one line
of `conjBehavior`:

```swift
result.append(y.value)                        // the Item is destructured to a raw value here…
call: [x, y, InstructionItem(instruction)],   // …but `y`, the Item, is recorded on the VECTOR
```

So it is worth being precise about what is actually lost, because it is narrower than it first looks:

- **The obligation still holds.** The element's history survives in the *vector's* `call`, so
  `crux(element)` — `crux(vec) .vecIntPushAll k .intPopItems` — transitively contains it and reproduces
  the value. The round-trip sweep confirms this across every vector behavior.
- **What is lost is addressability.** An element has no individual identity, so "where did element 3 come
  from?" cannot be asked of the element; it can only be answered by reading the whole vector's history.
  A code block's element can answer for itself. A vector's cannot.

Two consequences worth keeping in view:

- **Every element's crux drags the whole vector's history.** A vector built by N conjs has an O(N) chain,
  and each element pulled back out inherits all of it — where a block's element carries only its own.
  Honest, but it is why vectors press on the `maxCallWeight` budget harder than blocks do.
- **It blocks the planned crux-to-function work for vectors.** Extracting an item's crux into a `CodeItem`,
  and currying it by removing a leaf, works cleanly for a block's contents. For a vector element the
  "crux of this element" is unavoidably the whole vector's construction plus a `PushAll`/`PopItems`
  selector, which is not the subroutine anyone wanted.

Fixing it means `VecIntItem.value: [IntItem]` and friends — which costs boxing per element, a wider wire
format (`AnyItem` currently encodes a vector as `[Int]`), and a pass over every vector behavior. Not now,
but it is a real gap in the paradigm rather than an implementation detail: it is the one place where
containment destroys history, and law 1b says containment should not.

## Future work noted along the way

*Indexed in `Roadmap.md` §E.*

- ~~**A `contingencySources` instruction set**~~ — **dropped.** It would have split contingency into
  sources (the ten `.inputN`, plus `DeepDup`/`Shove`/`Yank`/`YankDup`/`StackDepth`/`StackIsEmpty` for
  every stack) and propagators (everything else, via `netContingency`), and it carried the long-standing
  open question about whether `DupItems`/`DupTimes` make their results contingent in themselves. All of
  it went when `.isContingent` was removed (*Roadmap.md* §23a); the `InstructionSets.swift` TODO that
  described it is deleted. The observation underneath is still worth keeping, though: the set was *nearly
  but not exactly* law 4b's group, because 4b asks "does the VALUE depend on transient state?" while
  contingency asked "does the result's presence or position?" — close cousins, not the same question.
- **Error provenance is inconsistent.** Int and Double error branches record their arguments, so an
  error's crux reproduces the error — genuinely useful. But `.inputN`/`.intN` "not bound" errors record
  nothing, even though the *success* path of the same instruction records `[.inputN]`. Both satisfy the
  obligation (an `ErrorItem` literal reproduces itself), so this is about explanatory value, not
  correctness. The combinators' "on empty stack" errors and the shared "missing args" error correctly
  record nothing — they are law 4b, dependent on transient stack state.

## Deliberately not addressed

- `vecXPushAll` puts element 0 on top; `stringPushAllChars` puts the *last* char on top. A real
  semantic inconsistency between siblings, but changing it changes language semantics. Flagged only.
- ~~`==` walks the entire provenance DAG.~~ No longer: equality is value-only (`isEqual`), and ignores
  `call` entirely.
- `RecordedTrace` and `RecorderSpec` both claim in comments to retain `call` provenance for downstream
  analysis. They do not — `AnyItem` drops it. Either the comments are wrong or the export is missing;
  the unimplemented `codeFuncFrom_Crux` family in `Code instruction planning.markdown` suggests the
  latter was the plan.
- `execWhile` records its continuation as `.execDoWhile`, following the klapaucius note it was ported
  from. Now moot for provenance (both are combinatory and record nothing), but the naming remains.

## Recording only when asked (Phase 2, 2026-11-05)

Provenance is now built **only when a run asks for it**. `InterpreterSettings.recordsProvenance`
defaults to `false`, and with it off no Behavior builds a `call` at all. Previously every Behavior built
its call tree and `push` stripped it afterwards (the strip existed to stop loops accumulating memory).

**The seam.** Every Behavior's transformer receives a `ProvenanceRecording` alongside its arguments
(`([any Item], ProvenanceRecording) -> [Router]`; side-effecting Behaviors read
`interpreter.recording`). Every provenance expression is written inside it:

```swift
IntItem(y.value + x.value, call: recording([y, x, InstructionItem(.intAdd)]))
```

The argument is an `@autoclosure`, so when recording is off it is never evaluated: no array, no
`Behavior.reading`/`selecting` sort, no iterator `reconstruction()`. Calculation is ordinary code; the
provenance is the marked, unevaluated expression. `IteratorItem`'s `projection`, `element(at:)`,
`collected`, `stepped` and `clamped` take the same argument (required, so no caller can forget), and
`Interpreter.iteratorLoop` gates the one reconstruction 43 looping Behaviors share.

**What guarantees it** (`Infrastructure/Provenance Off Parity Tests.swift`):
- every Behavior, seeded 0, 1 and 4 deep, leaves identical stacks, weights and live weight with
  recording on and off;
- the throughput benchmark's 200 seeded programs run identically both ways;
- with recording off no Behavior's results carry a `call` at any depth (inside blocks and iterators
  too). This replaced the strip.

Behavior tests that pin provenance construct `Interpreter.recordingProvenance()`, and the test helper
`doThis` re-runs each instruction on an off-recording twin and requires identical values. So every
mixed value-and-provenance test checks both modes. The Runner turns recording on for an evaluation that
asks for `cruxInputTokens`, since that answer is read off the crux.

**Cost.** Throughput benchmark (release, 129,615 steps): recording off 605 -> about 553 ns/step (~9%);
on 610 -> about 580 (from waste removed in passing: `collected()` no longer reconstructs its private
cursor each pass, and `iteratorPlayDelayed` no longer builds a reconstruction that `stepped()`
overwrote). On the loop-heavy Provenance Cost Benchmark, run time is about 1.03x faster with recording
off. Building call trees was never the dominant cost; the remaining profile is mostly `any Item`
boxing.

**Why not a macro (yet).** Considered for this change and deferred; see *Macros for behavior
definitions.md*. The gate gives every Behavior one explicit provenance seam, which a later macro could
emit exactly as written by hand.

