# Design principles

What this interpreter believes, and why. These are the rules to decide *with* when you are adding an
instruction, a type, or a Behavior and the codebase does not already answer the question.

Each one is here because getting it wrong cost something. Where a principle has a fuller treatment
elsewhere, this document points rather than repeats: the provenance law lives at the top of
`Items.swift`, the budgets and their reasons in `InterpreterSettings`, and the design notes beside this
file carry the arguments — `Stack economics.md` (measured, and the one that disagrees with itself),
`The first-class iterator.md`, `Keeping loops human-sized.md`, `Provenance and the crux.md`,
`CodeItem goes to code.md`.

---

## 1. The crux reproduces a value; it is not a trace

**An item's `call` records how to rebuild it. `crux()` reads that record back as runnable Push source.
Its one obligation is:**

> running an item's crux on a fresh interpreter reproduces that item's value, on that item's stack.

It is *not* a history of what ran. This is the load-bearing distinction in the whole system, and almost
every provenance bug has come from forgetting it.

The purpose is explanatory. Push programs resist reading: instructions arrive in arbitrary order,
combinators rearrange stacks, code blocks get restructured and duplicated. When a program evolves that
works, you cannot see *why*. The crux answers that — it is the sub-program that actually mattered, with
the noise gone.

Two consequences that keep surprising people:

- **Combinatory rearrangement is not recorded.** A `dup` produces no new value, so it records nothing.
  Recording it was what made `call` grow without bound.
- **A record may name an instruction that never ran.** A loop counter records `[origin, offset, .intAdd]`
  even though `.intAdd` was nowhere near it, because that is what *reproduces* the value. This is honest
  under the obligation above, and it is the whole reason the record stays O(1).

The full rules — laws 1 through 5, and the containment and prefix sub-rules — are at the top of
`Items.swift`. Read them before writing any Behavior that records anything.

**Corollary: eliding provenance is always safe.** `crux()` returns `[self]` for an empty `call`, and a
bare literal is already a runnable program producing itself. So dropping a record costs the *story*,
never the correctness. That asymmetry is what makes an aggressive `maxCallWeight` budget acceptable.

## 2. Push is mostly postfix — and a stack reverses what you wrote

`2 3 .intSubtract` computes 2−3. The `2` was written first, so it is *deeper*; the `3` is on top. A
Behavior's `gather` pops top-first, so:

> **the top argument popped is the LAST one written in the source.**

`a[0]` is the last-written argument, `a[1]` the one before it, and so on. When a Behavior records a
derivation it must write the arguments in **source order** — reversed from the order it popped them:

```swift
call: [a[1], a[0], InstructionItem(name)]      // args first-written-first, instruction last
```

Get this backwards and the record is a program that computes 3−2.

**The rare exception is `.exec`, and it matters.** An argument taken from `.exec` is not waiting on a
stack *behind* the instruction — it is the next thing *ahead* of it in the program. So the source that
re-runs it reads `.execEq 3 3`, **prefix**, not `3 3 .execEq`. Reconstructed source is executed from
`.exec` like anything else, so it has to be written the way `.exec` reads it. `execQuote` and `execEq`
are the only two that record this way (law 3b).

**Practical relief, with a sting:** when an instruction's arguments come from *different* stacks, their
order in the record is free *for correctness*. `stringNth` takes `[.string, .int]`, so pushing the string
or the int first makes no difference — each lands on its own stack and is popped from there. Only
ordering *within one stack* changes what a program computes.

**But free is not arbitrary, and this cost a real bug.** `stringNth` recorded `[index, string]` while its
four `vecXNth` siblings recorded `[vector, index]`. Both ran correctly for years, and both were pinned by
tests. Then an iterator walked a string and recorded the *other* order — and the crux stopped being a
**fixed point**: re-running a crux produced a differently-worded crux for the same value. "The crux" was
no longer well defined.

So the rule is: **a derived value must record the same way the instruction it names would record.** Where
two instructions do the same job, they must agree. Only the fuzzer catches this; a unit test cannot,
because it transcribes whatever order the code already uses (principle 16).

## 3. Iteration, recursion and repetition are `IteratorItem`s

**Anything that does a thing more than once is an iterator.** Counting a range, walking a collection,
exploding a string, repeating a value: all one type, all one mechanism.

Before this, every loop rebuilt itself as Push source on every pass. `execDoRange` re-pushed both bounds,
a copy of its body, and a fresh copy of its own token — so the counting was *done in Push*, and the
loop's state was smeared across `.int` and `.exec` where anything could disturb it and nothing could
reason about it. Now:

```
.exec top→bottom:   body  .codeDo  .iteratorPlay
```

and that is all. The bounds, the stride and the cursor are inside the iterator, and **the mechanics of
counting need not be expressed in Push**.

The design rests on one property: **the cursor is always an `Int`, and everything emitted is a projection
of it.** A projection must be a *pure function of `(origin, cursor)`* — nothing else. That is what makes
every kind O(1), reconstructible, and addable: a Double range needs no Double counter (initialize by a
step count, or by a stride and divide), and a depth-first walk of a code tree is just the index applied
in a different mode.

`IteratorItem` began as a provenance-only node hiding inside `call`. Making it first-class did not just
promote it — it made the node **unnecessary and deleted**. That is the shape of a good change here: the
special case dissolves rather than moving.

See "The first-class iterator.md".

## 4. Nothing explodes; work takes time

**An instruction that produces N things should produce them over N passes, not all at once.**

`stringPushAllChars` used to turn a string into N characters in a single step. `xDupTimes` made N copies
at once — so violently it needed its own `maxStackDepth` guard, the only bespoke size check in the
language. Each was a loop refusing to be one.

Doing the work over time means `stepLimit` and the runaway guard govern it like any other loop, with no
special pleading. **If you find yourself writing a size check for one instruction, you have found a loop
in disguise.**

It also improves the explanation. An exploded element had to record *which of the pile it was*
(`s .stringPushAllChars 3 .charPopItems` — law 5). An emitted element just says what it is:
`s 2 .stringNth`. Independent, O(1), and true regardless of how many passes have run.

## 5. Relieve argument starvation; never deepen it

Push programs starve: an instruction wants an argument, the stack is empty, nothing happens. It is one of
the language's real design flaws, and much of the iterator work is aimed at it — a loop that yields
control instead of dumping its output can be interleaved rather than flooding a stack.

So: **an instruction must not consume arguments proportional to the work it does.** `.iteratorPlayDelayed`
originally re-read its delay every pass, which meant a thousand-pass loop ate a thousand `.int`s. That was
a dead end. It now reads once and stores the depth on the iterator, and the loop continues with a token
that consumes nothing. If for some algorithmic reason the depth needs to change, a separate instruction
(not yet written) can do that at lower risk.

Two corollaries, both measured rather than guessed ("Stack economics.md"):

- **A zero-argument form of a useful operation earns its own instruction.** `.int` is empty **63.5%** of
  the time something wants it, so `0 .iteratorSetCounter` frequently *cannot fire* where an argumentless
  `.iteratorRestart` always can. That is not a keystroke saving; in a starved language it is the
  difference between an operation that exists and one that does not.
- **Give the arguments back when you cannot act — and when you are done.** `execDoCount` with a count
  below 1 already returns its arguments rather than eating them, and a dying iterator returns its body to
  `.code`. This is not tidiness: `.code` is the language's tightest bottleneck (0.29 producers per
  consumer) and `.int` its hungriest, so anything that hands them back is a *source* for exactly what is
  scarce. An instruction that consumed something and then achieved nothing with it should not also
  destroy it.

## 6. Collections are walked front-to-back

**Element 0 first, so the LAST element ends up on top.** Uniformly, everywhere — iteration, exploding,
`Nth` indexing.

This is worth stating because the codebase did not obey it: `vecXPushAll` reverses before pushing, so
*its* element 0 lands on top, while `stringPushAllChars` leaves the last character on top. Two siblings
disagreeing about a basic question, for years, each one internally consistent and neither one wrong on
its own. That is what an unwritten principle costs. Being converted to iterators settles it — walking
front-to-back means `vecXPushAll`'s order changes, deliberately.

## 7. Code is data until a program asks for it

A `CodeItem` met on `.exec` comes to rest on `.code` **intact**. It does not scatter. `.codeDo` is one
of the several instructions that unwraps a block and executes its contents, but in every case, a program
has to ask.

This is what makes code inspectable rather than merely runnable, and it is what lets a block's `call`
survive — unwrapping on sight used to discard it, so an `.input` bound to a block lost its provenance the
moment it scattered.

Corollary, and it catches people: **an instruction's code argument must reach `.code` before the
instruction fires**, so in source it *precedes* the instruction rather than following it. And because
`.code` is a stack, `( then ) ( else ) .execIf` reads first-written-first like every other postfix
instruction.

See "CodeItem goes to code.md".

## 8. Containment leaves no mark

An item that goes into a container and comes back out **is the item that went in**. Blocks get
restructured, concatenated, duplicated and taken apart, but by convention none of that changes the
`.value` of what they hold — so containment is combinatory, and contributes nothing to an item's history.

`.codeDo` therefore drops the *block's* `call` and leaves each content's own `call` untouched, exposing
them as though they had been sitting there all along. The same holds for iterators: the getters hand back
the very bounds and body that went in, and record nothing (law 1b).

`.iteratorPeekStride` is the exception that shows the rule: there is no contained item to hand back, only
a stored `Int`, so it really is produced by that instruction and records like anything else.

## 9. Equality is about values

`==` and `.xEq` compare **values**, never provenance or contingency. Two items that mean the same number
are the same item, however they were arrived at.

This is not obvious and was once wrong: every `xEq` compared the whole provenance DAG, which also made
`Comparable` incoherent (`<` used the value alone while `==` used everything). If you add a type, its
equality compares its *state* and nothing else.

For a type whose state is a structure rather than a scalar — `IteratorItem` — "value" means the whole
state: two iterators over the same range differ if they sit at different cursors.

## 10. Encapsulate state; expose it on purpose

A loop's state is its own for its duration. Nothing leaks onto `.int` "for convenience"; a program that
wants to know asks with a getter.

**Getters are named `Peek` and are non-destructive** — the language's one deliberate exception to
"an instruction consumes its arguments". An iterator is a live loop, not a value: a getter that killed it
to report its stride would be useless in the body, which is exactly where you would want to ask.
`.iteratorPop` exists for anyone who wants it gone.

The exception is *narrow* on purpose. Everything else consumes. But there can be future changes affecting this.

## 11. Everything that can grow is bounded

Two budgets, mirroring each other: `maxItemWeight` for value content and `maxCallWeight` for provenance.
Both are enforced at `Interpreter.push`, the single validated entry point.

They behave differently, deliberately. **Overflow is an error** — the push is refused and an `ErrorItem`
lands on `.error`. **Over-budget provenance is not** — the item is pushed normally with `call = []`, and
merely forgets where it came from. That follows from principle 1: elision cannot break the obligation.

Growth that survives is *honest* (`x 1 .intAdd` in a loop body really does accumulate). The budget is a
backstop for honest growth, not a licence to record dishonestly.

**The budgets must be coherent with each other, and are not automatically.** Measured: `maxVectorLength`
is 1,000 and `stepLimit` is 1,000, so walking the largest *legal* vector emits 997 of 1,000 and dies three
short — the interpreter accepts data it will not allow you to traverse. `stepLimit` must exceed
`maxVectorLength` and `maxStringLength`, or a legal collection cannot be walked. Adding a budget means
checking it against the others.

## 12. Limit what a program *claims*, never what its data *is*

A count is a **claim**; a collection's length is a **fact**. `0 999999 .execDoRange` is a program
asserting something about a loop. A thousand-element vector is not asserting anything — it *is* a
thousand elements.

**Claims may be clamped. Facts may not.** Truncating a walk means "you only see the first hundred
elements of your own data", which is a lie about the world rather than a limit on ambition. This falls
out of the type rather than needing enforcement: a walking iterator has `destination = nil`, so there is
structurally nothing for a clamp to move.

### Clamp; never modulo

When a limit does apply, **apply it monotonically**. The earlier `.execDoFew` family took its count
modulo 10:

| int | `% 100` | clamp to 100 |
|---|---|---|
| 5 | 5 | **5** |
| 100 | **0** | **100** |
| 999_999 | 99 | 100 |

Modulo is *chaotic*: 100 becomes zero passes, 101 becomes one, 110 becomes zero again. The map from the
program's number to the loop's size has no useful derivative anywhere — **a search cannot climb it and a
reader cannot follow it**. Clamping is monotone: everything under the limit passes through untouched,
everything over it saturates, and the relationship survives.

This generalises past loops. Any transformation the language quietly applies to a program's numbers
should preserve order, because §17 says a random program must be able to improve by degrees. A chaotic
transformation is indistinguishable from noise, and evolution cannot optimise noise.

### A limit is configuration, not vocabulary

`.execDoFew`/`.execDoSome` put the magnitude **in the instruction name**, where it could not be tuned,
had to be memorised, and multiplied by every looping instruction. `maxIterations` puts the same policy in
`InterpreterSettings` beside every other budget: one dimension, one number, one place, changeable per
experiment without touching the language.

The number is arbitrary in exactly the way `1_000` is arbitrary for `maxStringLength` — it is a policy,
declared once. That is a completely different thing from arbitrariness welded into semantics.

**And the language bounds; the search shapes.** A clamp makes a huge count survivable; it does not make
counts *tend* to be human-sized. That has to come from the distribution of numbers a genome produces,
which is a search hyperparameter and belongs there. Arbitrariness in a hyperparameter is fine.

## 13. A limit must say where its number came from

Every budget in `InterpreterSettings` has a reason. **Almost none of them are obvious** — including to
us, six months later. A number with no stated reason is indistinguishable from cargo, and the next reader
will either treat it as sacred or tidy it away. Both are wrong, and you cannot tell which is worse
without knowing where it came from.

Reasons come in three kinds, and the kind matters more than the number, because it says what you are
allowed to do to it.

**Free.** A policy. It could be anything; change it at will and nothing else moves.

**Inherited.** Taken from another implementation — most of ours are "loosely after propeller's
`limits.cljc`" — for comparability rather than correctness. Changing one costs cross-implementation
comparison and nothing else. **Say so plainly.** "Inherited and never examined" is a real reason, and
recording it is far better than implying a rationale that was never had. It also tells a reader that the
number is *available* to be reconsidered, which a silent number does not.

**Derived.** Fixed by some *other* limit. These are the dangerous ones, because they look free.
`maxIterations = 100` is not a preference: at `stepLimit = 1_000` and roughly 1–4 steps per pass, ~100 is
the largest loop that can **finish**, and finishing is the entire point of it (§12). Raise `stepLimit`
and 100 is needlessly small; lower it and 100 becomes a lie. It looks inconsistent beside the other
1,000s, and **that inconsistency is information** — it is derived, and they are not.

### The failure mode, which we have already hit

`stepLimit` (1,000) must exceed `maxVectorLength` (1,000), or the largest **legal** vector cannot be
walked to completion. It does not. Measured: a 1,000-element walk emits 997 and dies three short, missing
by exactly the setup cost.

Nobody wrote the relation down, so nobody noticed it was violated — for however long both numbers have
been 1,000. That is what an unrecorded derivation costs: not a bug anyone reported, but a quiet
incoherence at the boundary of what the interpreter says it accepts.

### So, when you add or change a limit, record

1. **what it bounds** — most of ours already do this well;
2. **which kind its number is** — free, inherited, or derived;
3. **what it must stay in relation to**, if anything.

A limit whose comment explains only (1) is half-documented, and the half that is missing is the half that
will bite.

## 14. Nothing crashes the interpreter

An enumerated instruction with no Behavior, a missing argument, an oversized push, a mis-typed
push — every one of these produces an `ErrorItem` and lets the loop continue. Evolved programs are
*supposed* to be wrong; wrongness must be survivable, or the search stops.

Two structural supports:

- **`gather` is all-or-nothing.** Every stack demand is checked before anything is popped, so a Behavior
  that cannot run consumes nothing and leaves the stacks exactly as they were.
- **Stacks are homogeneous except `.exec`**, and `accepts` enforces it. A mis-tagged `Router` is a
  programming bug, not a program bug, so it leaves the distinctive `INVARIANT:` marker — the one class of
  failure that means *the interpreter* is wrong.

## 15. Contingency is a separate axis from provenance

`isContingent` marks a value whose presence depended on something the crux does not capture — a
stack-depth read, a yank from an arbitrary position. It travels alongside `call` and never inside it.
Do not conflate them: an item can be perfectly reproducible and still contingent.

## 16. Tests are the specification, and the acceptance tests are the ones that matter

Unit tests here are written by reading the code, which means they transcribe whatever the code says —
**bug and all**. That is exactly how `charGTE` came to record `.charGT` and nobody noticed.

The tests that catch a record that *lies* are the ones that check the obligation by *doing* it: run the
crux, see whether the value comes back. `Crux RoundTrip Tests.swift` sweeps every registered Behavior
this way, so a new instruction is covered the day it is added, and a fuzz half does the same for random
programs. Between them they found four wrong-instruction bugs, 22 unreproducible `StackDepth` records,
and every `xEq` comparing provenance.

When you add an instruction, the sweep enrolls it for free. When you change a *trace* test, ask first
whether the trace or the behavior is the thing being pinned — most trace tests pin the shape of a
continuation, and continuations are exactly what this design keeps deleting.

## 17. Evolvability is the goal

The reason for all of it. This interpreter exists to run programs nobody wrote, so that a search can find
ones that work.

That is why iterators are first-class: they rest on an ordinary stack where a program can dup them, yank
them, or steal one mid-loop. It looks reckless and it is the point — the earlier interpreter this comes
from found the language *markedly more evolvable* once iterators were things a program could get hold of.
A body that flushes `.iterator` out from under its own loop gets an error and stops, which is a fine
outcome. Making that impossible would cost more than it saves.

So when weighing a design: prefer the option that gives a random program more to work with, provided the
failure mode is an `ErrorItem` rather than a lie.
