# Sieve arguments: finding an argument rather than taking one

**Status: the planner is built; the sieve is not.** Question 2 below was answered *yes* — take the
mechanism, leave the feature — so `Planner.swift` now exists and `Requirement` has three kinds
(`.takes`, `.needs`, `.takesMany`). A sieve would be a fourth, and everything §1–§5 says about it still
stands as written: **explored, not decided.**

What that bought, all of it predicted here in §2: `isSatisfied` is now "the plan succeeds" rather than a
depth count; `vecXConstruct`'s hand-rolled check is gone; `alsoNeeds:` folded in; the starvation probe's
blind spot closed (and `vecIntConstruct` promptly turned up starving in 100% of the programs that reach
it); and a refusal can name the stack it stopped at. The bargain of §14 is now structural and tested once
for the whole language instead of Behavior by Behavior.

**And question 1 is now answered too, by building the thing it asked about.** `.vecFromIterator` is the
polymorphic collector §5 proposed, and it works: one instruction, four result stacks, chosen by what the
iterator actually emits. **So the vector case does not need a sieve, and never did.** What remains is
§5's honest conclusion — *the matrix case has no such escape*, because dimensional compatibility is a
relation between two arguments and no polymorphism dodges it.

**So the sieve is now justified by matrices alone, and matrices do not exist yet.** That is a good place
for it to sit. What is left to decide is only the sieve itself — the predicate, its cost, and whether a
program can tell the difference. Adding it is one enum case and one branch in `plan`, which was the point
of sequencing it this way.

---

## The premise

Some stacks hold items that are all **the same type** but not all **usable for a given job**. Which one
is usable depends on an argument the Behavior has *already* taken.

The canonical case, from earlier Push interpreters and not yet here: **matrix multiplication.**
`.matrixMultiply` pops a 4×3 matrix as its second argument. The only companion that will work is some
N×4. Taking whatever is on top of `.matrix` will usually fail — not because the stack is empty, and not
because the item is the wrong type, but because it is the wrong *shape*.

The proposal is a **sieve**: examine the stack top-down for the **first item matching a constraint**
derived from the arguments already in hand.

- **If one exists**, extract it — pulling it out of wherever it sat, leaving the rest of the stack
  otherwise intact and in order.
- **If none exists**, the Behavior is missing its arguments, exactly as if the stack were empty.

### Why it is being raised now

Because `IteratorItem` is a **liquid type**. Every other stack in this language is homogeneous in two
senses at once: one Swift type, and every item interchangeable as an argument. `.exec` is heterogeneous
in both. `.iterator` is the first stack that is **homogeneous by type and heterogeneous by behaviour** —
each iterator emits a particular scalar type when poked, and that type is a property of the *instance*,
not of the stack.

So a Behavior that needs "an iterator that emits Ints" cannot ask for it. It can only take the top one
and hope. The sieve is how it would ask.

### The claim to be tested

> Looking at the top of a stack versus looking for the first matching item in a stack is **no different
> from the transparent operation of combinators or CodeItem rearrangement**, and is therefore allowed by
> the fundamental paradigm.

This note's job is to work out whether that is true, and what it would cost if it is.

---

## 1. Is it law-legal? — Yes, and more cleanly than expected

The paradigm's rule (Design Principles §1, and the law at the top of `Items.swift`) is that a crux must
**reproduce a value on a fresh interpreter**. So the question is: does a sieved argument's record still
do that?

**It does, and it is not even contingent** — which is a stronger result than the analogy suggests.

Compare `yank`, the nearest existing thing. `yank` reaches to an arbitrary depth and moves an item to the
top. It records **nothing** (law 1: rearrangement within one stack is free) but it sets
`isContingent = true`, because *which* item it grabbed depended on the stack's arrangement, and the crux
cannot say "the thing that was three deep."

A sieve is different in exactly the way that matters: **the record names the item, not the position.**

```
crux of a sieved multiply:   (5x4) (4x3) .matrixMultiply
```

Re-run that on a fresh interpreter and `.matrix` holds exactly those two. The sieve looks for an N×4,
finds the 5×4, and produces the same answer. The position was incidental; the *identity* is what was
recorded, and identity is reproducible where position is not.

So: **law 1 applies (records nothing), and unlike `yank` it is not contingent.** The user's claim holds.

### The real risk is composition, not reproduction

The obligation is about a **fresh** interpreter, and a sieve satisfies it. But `crux()` builds a parent's
record by **concatenating its children's**:

```swift
return self.call.flatMap { $0.crux() }
```

That works today because of a property nobody wrote down: **every crux fragment leaves exactly its own
value on top, and every instruction takes the top.** So fragments compose without interfering — there is
a test named for it (`a result composes into a later computation`).

A sieve reaches *past* the top. So a fragment could sieve up something an *earlier* fragment left behind,
and the concatenation would compute something the original never did.

Today's fragments **are** debris-free — spot-checked rather than assumed, running each crux alone and
looking at every stack:

```
intAdd           leaves int:1
vecIntNth        leaves int:1
vecIntConstruct  leaves vecInt:1      ← consumed its template and both ints
stringNth        leaves char:1
intQuote         leaves code:1
```

Each records exactly what it consumed, so it leaves one value and no litter. **That is why a sieve would
probably work — and "probably" is the problem.** The property is a comfortable accident of how the law
happens to be written; nothing states it and nothing tests it. A sieve would promote it to load-bearing.

If sieves are adopted, this needs to become a rule:

> a crux fragment leaves its value and nothing else, on any stack

The crux fuzzer is what would catch a violation, and it should be pointed at this specifically. It is
worth doing **regardless** of the sieve — see question 4.

## 2. `gather` would have to become transactional — and that is the good news

The blocker is a chicken-and-egg:

- `isSatisfied` runs **before** anything is popped, and decides whether the Behavior may run.
- A sieve's predicate depends on an argument **already gathered**.

So satisfaction cannot be decided up front, and popping-then-discovering means eating arguments on
failure — the exact bug just fixed in the sixty combinators (§14). Doing that deliberately, for the
hardest case, would be a poor trade.

**The fix is plan-then-commit**, and it is worth more than the sieve:

1. **Plan.** Walk the requirements in order, resolving each against the interpreter *without mutating
   anything*, and with the already-resolved arguments in hand. Each resolves to a concrete
   `(stack, index)` — or the plan fails.
2. **Commit.** If every requirement resolved, remove them all at once (descending index per stack, or the
   earlier removals shift the later indices).

`isSatisfied` becomes "the plan succeeds," which is a truer definition than counting depth.

**This one mechanism subsumes four things that are currently four things:**

| today | as a plan step |
|---|---|
| `takes: [.int]` | resolve index 0 of `.int`; remove it |
| `alsoNeeds: [stack: 2]` | resolve index 1 of `stack`; **don't** remove it |
| `vecXConstruct`'s hand-rolled check | resolve N of `.int`, where N is a *previous* argument's length |
| a sieve | resolve the first index of `stack` matching a predicate |

All four are "resolve a requirement against the interpreter, given what is resolved so far." That the
same shape keeps recurring — and that each recurrence has so far been solved separately, twice by hand
and once wrongly — is the strongest argument here. **The sieve is not the feature; the planner is.** The
sieve is one requirement kind it happens to make possible.

It would also close the last blind spot in the argument-starvation probe, which cannot see
`vecXConstruct`'s dynamic need because `needs` is a constant rather than a function of the interpreter.
*(Built, and it did: the probe now asks the planner, and the dynamic need is measured like any other.)*

## 3. It is an anti-starvation mechanism, which is the strongest argument for it

Measured (`Stack economics.md`): every scalar stack is empty roughly half the times it is wanted, and
`.int` — the most-demanded stack in the language, asked three times more often than any other — leaves
the largest shortfall there is by a wide margin. Argument starvation is not a theoretical flaw here; it
is the dominant failure mode of a random program.

A sieve is the only proposal so far that makes an instruction **more likely to fire**. `matrixMultiply`
on a stack of random matrices is nearly always unsatisfiable if it takes the top; with a sieve it
succeeds whenever *any* compatible pair exists. That is a large change in the reachable search space, and
it is exactly what §5 asks for.

## 4. What it would cost

**A new unbounded dimension: work per step.** Every budget assumes a step is O(1)-ish. A sieve is
O(depth), and `maxStackDepth` is 10,000 — so one step could run 10,000 predicate evaluations, and
`stepLimit` would count it as one. That is precisely the shape §11 exists to prevent, and it would want a
budget of its own with a stated reason (§13). Note this is *not* the same as the runaway guard's concern:
the guard watches stacks growing, not steps getting expensive.

**A predicate is a new kind of thing in a Behavior.** Today a Behavior is a name, some stacks, and a
transformer. A predicate is code that inspects a candidate — the first thing in the language that
*reasons about* an item rather than transforming it. Worth being deliberate about: it is a genuinely new
capability, not a refactor.

**`.iterator` would be the first stack where two items of the same type are not interchangeable.** That
is the "liquid type" observation and it deserves a name in the principles, because it is the thing that
makes the sieve necessary rather than merely convenient.

## 5. The vector case may not need it at all

**Worth settling before building anything**, because if it is right, the sieve loses its urgency and can
be judged on matrices alone.

The second vector-creation route is "cause an Iterator to emit a vector of Ints, Doubles, Bools or
Strings." That does not obviously need a sieve, because **an iterator already knows what it emits**:

```
.iteratorCollect   →   pop the top iterator, run it, gather what it emits into
                       a vector of the matching type
```

No searching. The instruction is **polymorphic in its result**: hand it an Int-emitting iterator and it
pushes a `VecIntItem`; hand it a Bool-emitting one and it pushes a `VecBoolItem`. That is not a new idea
here — `.elements` iterators *already* emit to a stack derived from the element, and `pushDefault`
already routes by type. A result stack that depends on the argument is established practice.

The sieve is only needed if a Behavior must have a **specific** type — `.vecIntFromIterator`, which wants
an Int-emitter and should not settle. Both are defensible:

- **`.iteratorCollect` (polymorphic)** — no infrastructure, always fires, one instruction instead of four.
  But a genome cannot *ask* for a vecInt; it gets whatever the top iterator happens to be.
- **`.vecXFromIterator` (sieved)** — a genome can say what it wants, and finds an Int-emitter under three
  Bool-emitters. But it needs all of the above.

**The matrix case has no such escape**: dimensional compatibility is a relation between two arguments,
and no polymorphism dodges it. So matrices are the honest motivation for the sieve, and iterators may
not be.

---

## Questions worth settling before any of this is built

1. ~~**Is `.iteratorCollect` (polymorphic result) enough for the vector case?**~~ **Answered: yes.**
   Built as `.vecFromIterator`. A genome still cannot *demand* a vecInt — it gets whatever the top
   iterator emits — and that has turned out to be a price worth paying rather than a gap to close, since
   the alternative was to make the instruction refuse most of the time in a language whose defining
   failure is argument starvation. The sieve is justified by matrices alone and can wait for them.
2. ~~**Build the planner without the sieve?**~~ **Answered: yes, and done.** Plan-then-commit was worth
   having on its own, and the sieve is now one more requirement kind whenever it is wanted.
3. **What bounds a sieve's cost?** A `maxSieveDepth`, or a stated invariant that stacks searched by a
   sieve stay small, or nothing and accept O(depth) steps?
4. **Does the composition invariant hold?** "A crux fragment leaves its value and nothing else" is
   currently an accident. Is it worth promoting to a tested rule regardless of the sieve? (Probably yes.)
5. **Should the sieve be visible to a program?** A sieved argument is *found*, not taken. If a program
   can tell the difference — via contingency, or a `.xSieve` combinator of its own — that is a language
   feature; if not, it is an implementation detail of particular instructions.
