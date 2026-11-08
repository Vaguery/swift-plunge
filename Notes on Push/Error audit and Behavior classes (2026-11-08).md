# Error audit and Behavior classes

*swift-push-interpreter, 2026-11-08. Rulings at the end. Part 1 (the audit, Roadmap #42) is built: every
failure listed in A and B is now an error, indices clamp, and the Cut and Shove gap bugs are fixed. Part 2
(the classes, #43) is not built yet.*

Two questions about the interpreter's Behaviors (the Swift implementations of Push instructions):

1. **Errors.** The interpreter now has an `.error` stack and `ErrorItem`s, which much of the older,
   hand-written code predates. The proposed rule: *every Behavior returns its intended output, or an
   `ErrorItem` if it cannot.* Which instructions still follow the older "protected" style, failing
   silently or returning an arbitrary value instead?
2. **Ontology.** Is there a formalization of what Behaviors do that is more general than "inputs →
   outputs" versus "imperative change to the interpreter state", and that covers the instructions that
   currently modify stacks directly, without rewriting them as long sequences of pops and pushes?

Background: an output survey of all 607 instructions (Roadmap #41, *Behavior input-output map.md*)
found that `intFromString` returns nothing on an unparseable string while `doubleFromString` returns
`0.0`. Those two prompted the audit below.

## 1. The audit

The Behavior sources were searched for silent declines (`return []` on bad input), fallbacks (`?? 0`,
`?? 0.0`, `?? -1`), modulo and clamping of indices, and ternary defaults, and each hit was read.

### A. Silent failures: no result and no error

These violate the rule outright. About 23 instructions:

| Instruction | When | Its argument |
|---|---|---|
| `intFromString` | the string is not a number | consumed and lost |
| `intFromChar` | a non-ASCII character | consumed and lost |
| `stringFirst`, `stringLast`, `stringNth` | an empty string | consumed and lost |
| `vecXFirst`, `vecXLast`, `vecXNth` (four vector types, 12 instructions) | an empty vector | consumed and lost |
| `stringNthWord` | no words | consumed and lost |
| `stringIndexOfChar` | not found | read, so kept |
| `codeNthRoot`, `codeEmitNthRoot`, `codeDoNthRoot` | an empty block | read, so kept |
| `codeContainer` | the needle is not in the block | read, so kept |

### B. Arbitrary values where an error belongs

- **`doubleFromString`** returns `0.0` for an unparseable string.
- **`charFromInt` and `charFromDouble`** map any number to `|n mod 95| + 32`. So `65 .charFromInt`
  gives `a`, not `A`, and `charFromInt` and `intFromChar` are not inverses of each other.
- **"Not found" gives `-1`** in `vecXIndexOf` (four), `vecXIndexOfSubVec` (four) and
  `codeIndexOfPoint`, but nothing at all in `stringIndexOfChar`. A `-1` is also dangerous: every
  instruction that takes an index accepts it and quietly turns it into a real position (1 or 0,
  depending on the family), so a failure becomes a plausible-looking answer two steps later.

### C. Modulo indexing: protected division, proper

An out-of-range index is wrapped rather than refused:

- `vecXNth`, `vecXSet`, `vecXCut`
- `stringNth`, `stringSetChar`, `stringNthWord`, `stringCut`
- the root-indexed code instructions, and every point-indexed code instruction (`CodeItem.point(at:)`,
  `replacingPoint`)
- `codeCutRootAtGap`

Two problems:

- **The families disagree about negative indices.** Vectors and code use |i| mod n, so −5 means 5;
  strings use max(0, i) mod n, so −5 means 0.
- **It contradicts Design Principles §12**, which rejects modulo because it is chaotic (100 mod 100 =
  0), and so cannot be climbed by a search or followed by a reader. That principle was written about
  loop counts, but the argument is the same.

This is the one real decision. An out-of-range index as an error means a random index into a short
collection usually errs, which changes how searches behave. Clamping is the alternative §12 already
endorses.

### D. Clamps: deliberate and documented (Design Principles §12, §14)

- the depth argument of `Yank`, `Shove`, `DeepDup` and `YankDup`, and the count of `DupItems` and
  `PopItems`
- `take`/`drop`, `substring`/`subVec`, `readItems`
- iterator burial

These are monotone ("as many as there are") and intended. One edge case: `dupTimes` with a negative
count copies nothing and says nothing.

### E. Correct as they are

Iterating, splitting or pushing all of an empty collection produces zero items, which is the right
answer, not a failure. One small inconsistency: `vecXIterate`, `stringIterate` and `codeIterateRoot`
on an empty collection drop their body silently, while a loop that finishes hands its body back to
`.code`.

**Already right:** arithmetic overflow and division by zero, non-finite doubles, and the iterator
constructors all return errors.

### Suggested course

Fix A and B now (an error each, plus the tests that pinned the old behavior), rule on C separately,
and leave D.

## 2. A formalization: one state, four parts

Treat every instruction as a function on the interpreter's whole state:

- the data stacks;
- the **continuation** (`.exec`, the rest of the program);
- the **environment** (inputs and constants);
- the **channels** (the printout and `.error`);
- the **clock** (the step counter).

Every current Behavior then factors into at most four parts, each optional:

1. **Read context**: the environment, the clock, or a stack's shape.
2. **A structural effect on positions**: move, delete or copy items, without looking at their values.
3. **A pure, partial function on values.** Outside its domain, the result is an error.
4. **Write**: to stack tops, to the continuation, or to a channel.

That gives five classes:

| Class | What it is | Examples | Provenance law it matches |
|---|---|---|---|
| **I. Operations** | a pure partial function on typed values; a `reads` query is the same with its arguments copied first | arithmetic, conversions, comparisons, constructors, queries, iterator state changes | law 3: the result records its arguments and the instruction |
| **II. Structural rules** | value-blind: deleting (pop, flush, `PopItems`), copying (dup, `DupItems`, `DeepDup`, `YankDup`, `DupTimes`), reordering (swap, rot, `Yank`, `Shove`); the deep ones indexed by an int | the combinator families, `execDup`/`execSwap` | law 1: rearranging records nothing |
| **III. Context reads** | sources with no data arguments | constants and inputs (reproducible); `StackDepth`, error counts, `pushStepCount` (not reproducible); `readItems`/`readStack` | constants and inputs record their token; state reads become stand-ins (law 4b) |
| **IV. Control** | writes to the continuation: its output is the rest of the program, not a value of some type | `codeDo`, `execIf`, the loop constructors, `iteratorPlay` | prefix recording, law 3b |
| **V. Channels** | sinks | `Print`, and the error branch of class I | — |

The interpreter's provenance laws already encode this split, which is why law 1 says rearranging
records nothing and why state reads needed stand-ins.

### The direct-write Behaviors

Rewriting them as pops and pushes is unnecessary: `n .xYank` as "pop n + 1 items, push n of them back,
then the last" adds complexity and explains nothing. Declaring their class is enough.
`BehaviorWithSideEffects` currently mixes three different things:

- **Reads, not writes.** The constants, the introspection counts and `readItems` only need read access
  to the interpreter; their results are ordinary Routers. Given a read-only context, they become class
  I or III with no imperative part.
- **Structural effects.** `Yank`, `Shove`, `DeepDup`, `Flush` and `PopItems` are permutations,
  copies or deletions of positions; `n .xYank` is "rotate positions 0…n by one". Declared that way, the
  interpreter keeps doing the work in place, and the declaration says what it does. Formally these are
  the structural rules of substructural logic: exchange, weakening and contraction.
- **Continuation writes.** `codeDo`, `iteratorPlay` and `iteratorPlayDelayed` put a program onto
  `.exec`, at a depth. In concatenative-language terms they are Joy-style combinators over quotations
  (`i`, `ifte`, `times`). An iterator is a reified continuation with a cursor: a generator.

### What this means for the input-output map (#41)

- Class I edges are the data graph, each with its domain condition.
- Class II edges are identities on types, changing only the shape of one stack.
- Class III are sources and class V sinks.
- Class IV are control edges, which is why outputs on `.exec` looked ill-formed in the survey: they are
  not data edges at all.

## Rulings (2026-11-08)

1. **A and B: all become errors.** Every Behavior returns its intended output or an `ErrorItem`. The
   silent failures, the arbitrary conversions and the `-1` "not found" sentinels all become errors, each
   with its own `ErrorKind`. Roadmap #42.
2. **Character codes are Unicode scalar values**, in both directions, so `charFromInt` and `intFromChar`
   are inverses. `charFromInt` errors outside the valid scalars (0…0x10FFFF, less the surrogates);
   `intFromChar` errors only on a character made of several scalars; `charFromDouble` truncates and then
   follows `charFromInt`. `65 .charFromInt` gives `A`.
3. **C: clamp everywhere**, as Design Principles §12 already says. An out-of-range index saturates: below
   0 is the first position, past the end the last; a cut or gap position clamps over the gaps (0…n), not
   the elements. Only an empty collection is an error (item A). This replaces a same-day ruling to keep
   modulo with Euclidean negatives: wrapping made `100 .vecIntNth` a different position for every input
   length, where a clamp means "the last" on every test case. The cost is that random constants land
   mostly on the ends; measure that after the change, and shape it in the constant distribution if needed.
   Iterator burial keeps its clamp, and its negative value keeps its meaning (end the loop).
4. **D: the clamps stay.** By default, `dupTimes` with a negative count is a clamp to zero copies, and
   iterating an empty collection hands the body back to `.code` as a finished loop does.
5. **The classes: declare, then narrow.** First every Behavior declares its class (checked by a test over
   the whole instruction set, and feeding the #41 map); then `BehaviorWithSideEffects` is replaced by
   narrower forms, one per class. Roadmap #43. Step 1 is built. Ruled while building it: taking an
   argument from `.exec` does not make a Behavior control. `execQuote` is an operation, like every other
   `xQuote`: the tradition from Push's originators is that code is data and data is code as far as
   possible, so `.exec` is special only in a contingent sense. Control means *writing* the continuation.
6. **Plain clamping, no negative indices from the end.** Considered and declined the same day: counting
   from the end (−1 the last) would make "second-to-last" mean the same at every length, but it puts a
   discontinuity at zero (−1 is the last, 0 the first), where small ints and arithmetic results cluster.
   `First`, `Last` and `ButLast` cover the ends.

### Index survey (2026-11-08)

Of the instructions that take a position, **items** (an existing element: N positions, 0…N−1) outnumber
**gaps** (a place to insert or cut: N+1 positions, 0…N). In collections, 24 instructions name items and 10
name gaps. On stacks, `Yank`, `YankDup` and `DeepDup` name items (36) and `Shove` and iterator burial name
gaps. Counts (`take`, `drop`, `DupItems`, `PopItems`, loop counts) are neither. An empty collection has
no item but one gap, so the empty-collection error (A) applies to item indices only; inserting into or
cutting an empty collection stays valid.

Under clamping, items clamp to 0…N−1 and gaps to 0…N. Two instructions get the gap range wrong today:

- **`vecXCut` and `stringCut`** take the index mod N rather than over N+1 gaps, so the tail gap is
  unreachable and the suffix is never empty (deliberately, by their comments). Clamped over 0…N, a cut
  at N gives the whole collection and an empty suffix, as `codeCutAtGap` already can.
- **`xShove` cannot reach the bottom of its stack.** After taking its item, c items remain and there
  are c+1 places to put it back (0 is the top), but it clamps to 0…c−1
  (`Combinator Behaviors.swift`, `shoveCombinator`). So the bottom is never reached, and on a two-item
  stack every `n .xShove` puts the item back where it was. The fix is to clamp to 0…c.
