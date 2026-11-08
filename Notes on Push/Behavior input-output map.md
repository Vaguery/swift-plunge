# Behavior input–output map (Roadmap #41)

**Status: SURVEYED (2026-11-08). Nothing built in the language.** The question: can every Behavior's
outputs be stated as well-formed edges (inputs of these types → outputs of these types), so a program
synthesizer could chain backwards from the outputs a problem wants? And should errors and the size limits
be part of those edges, or a separate filter over the pure I/O?

## How it was measured

Inputs are declared: a Behavior's `requirements` (`takes`, `reads`, `needs`, `takesMany`). Outputs are
not: they are `Router`s a transformer returns at run time. The source says where most of them go (236 of
the 270 `Router(…)` calls name a literal stack; the other 34 compute it, mostly `V.pushStack` in the
generic vector families, which is fixed per instruction, and `PushStack.defaultStack(for:)`, which is not).
But a body's branches, the errors it returns from helpers, and what the push gate does afterwards are
easier to observe than to read.

`BehaviorIOSurvey` (a diagnostic, off by default) drives each of the 607 instructions 150 times, on
seeded random stacks (edge-case numbers, empty and near-cap collections, blocks of several shapes, five
iterator kinds, random bindings). It keeps three things apart:

1. **Starvation**: the plan came up short. Decided before the body runs, and already derivable from
   `requirements` (`InstructionTrait.canStarve`).
2. **The body**: the Routers returned (stack, item type, how many), its own errors, and any direct writes
   by a `BehaviorWithSideEffects`.
3. **The push gate**: whether each Router then landed, or was refused at a size cap or `maxStackDepth`.

The full table (one row per instruction) is `Behavior IO survey (2026-11-08).tsv`, beside this note.

## What it found

| Output class (non-starved trials) | Instructions |
|---|---|
| One fixed signature (stack:type multiset) | 488 |
| Writes stacks directly, outside its Routers | 51 |
| Returns nothing (consumes only) | 38 |
| Types vary, but only on `.exec`/`.code` | 17 |
| Types vary with an argument's value | 11 |
| Fixed types, variable count | 2 |

So about **80% are a single well-formed edge already**. The rest fall into a small number of patterns,
each of which has a clean reading.

### 1. The limits are a separate filter, cleanly

82,115 results were pushed; **24 were refused** (0.03%), all at `maxVectorLength` or `maxStringLength`,
all from concatenation or replacement (`stringConcat`, `vecIntConcat`, the `ReplaceSubVec` family). A
refusal never changes *where* a result goes or its type, only whether it lands; it depends on the result's
size, not on the instruction; and the error it leaves is the interpreter's (`.sizeRefusal`, source
`nil`), not the Behavior's. **The gate is a predicate on (stack, value), applied after every edge.** It
belongs outside the map. (Stack depth was never hit at these depths; it is the same kind of predicate.)

### 2. A body's errors are partiality, not a second output

31 instructions returned an error from their own body. In **28** the error *replaces* the result:
arithmetic overflow and division by zero (`intAdd`, `intQuot`, `doubleDivide`, …), and the iterator
constructors refusing to build an iterator with nothing to emit. That is a *domain condition* on the
edge (divisor ≠ 0, the sum fits, the cursor is in range), not a different output. The edge is
`int int → int`, defined where the condition holds; outside it the instruction consumes its arguments and
writes `.error`.

In **3** (`iteratorSetStart`, `iteratorSetEnd`, `iteratorSetLaps`) the error comes *with* a result: the
setter refuses the value and hands the iterator back untouched. Read the same way: a domain condition,
whose failure branch returns the input unchanged.

Every body error here has kind `.other`; the kinds that matter for the map (missing argument, size
refusal) come from layers 1 and 3, which supports keeping them out.

### 3. Some instructions have a few outcomes, chosen by their arguments' values

These are not malformed; each outcome is itself a fixed edge, and which one happens depends on values:

- **Declining with the arguments returned.** `execDoCount`/`execDoTimes` with a count below 1 put the
  body back on `.code` (and `execDoCount` its count onto `.exec`) instead of building a loop.
- **A loop's lifecycle.** An iterator setter either rebuilds the iterator, or, when the change leaves it
  with nothing to emit, ends the loop and hands its body to `.code`.
- **An iterator's element type.** `.iterator` holds iterators over ints, strings, vectors, letters and
  words, so `iteratorStep`, `iteratorPeekStart`, `iteratorPeekEnd` and `vecFromIterator` produce
  whatever the iterator's kind says. **The stack is not a type here.** Refining it (an iterator *over T*,
  read off `kind` and `origin`) makes all four fixed again.
- **Silent declining.** `intFromString` on a string that is not a number returns *nothing*: it consumes
  the string and writes no error. (Its sibling `doubleFromString` returns `0.0` instead, and returns an
  error for a non-finite parse: three failure policies in two siblings. Worth a ruling.)

So the honest form of an edge is a **small sum of alternatives**, each a fixed multiset, with the choice
made by a predicate on argument values. Only `codeFromIterator` and `execDoWhile` vary in *count* within an
alternative.

### 4. `.exec` and `.code`: data, deferred data, and continuations

189 instructions put something on `.exec` or `.code`. The types seen there fall into three groups, and
only one of them is a problem:

- **`.code:Code`** is data: a block is a value like any other.
- **A literal on `.exec`** (`.exec:Int`, `.exec:VecString`, …) is a *deferred push*: one step later it
  rests on its default stack. The ten `.inputN` instructions work this way (the bound value goes to
  `.exec`), and so does `execDoCount`'s returned count. For the map, `.exec:T` for a literal T is
  `T` (delayed by a step).
- **`.exec:Code` and `.exec:Instruction`** are *continuations*: what they produce is whatever that
  program does, which is not a type at all. This is the genuinely open case. 40 instructions, in some
  trial, put back one of their own arguments here (`execIf` choosing a branch, `execDup`, `execSwap`,
  `codeEmitNthRoot` emitting a block's element); the rest mint fixed instructions (`.iteratorPlay`,
  `.codePop`). For backward chaining, a continuation is a *control* edge, resolved by looking inside the
  program it carries, not a data edge.

And `.iterator` sits in the same place: a loop constructor (`vecIntPushAll`, `stringPushAllChars`,
`execDoRange`) outputs `.iterator:Iterator` and `.exec:.iteratorPlay` — **a promise** of N items of the
element type over the following steps, not the items. The variable-count outputs of the language are
almost all of this form.

### 5. Effects the Routers do not show

51 instructions write stacks directly (`BehaviorWithSideEffects`): the `DeepDup`, `Flush`, `PopItems` and
`Yank` families, plus `codeDo`, `iteratorPlay` and `iteratorPlayDelayed`. The 38 that "return nothing"
are pops, `Shove` (which reorders in place, so a count-based probe sees nothing) and `Print` (which
writes the printout, not a stack). These are **shape operations**, not type transformations: a map
should state them as effects on one stack (remove n, reorder, copy), declared beside `requirements`.

### 6. Tags out of step

- 12 iterator constructors (`iteratorFromVecInt`, `iteratorFromString`, …) return errors from their body
  but are not tagged `.fallible`; the tag is on their siblings `iteratorFromIntRange` and
  `iteratorRepeating`. A real drift, cheap to fix.
- 13 instructions are tagged `.fallible` but never erred here (`doubleAdd`, `doubleSin`, …). The sample
  did not reach a non-finite double sum or the right iterator states; inconclusive, not wrong.

## Is it a DAG?

**At the level of types, no, and it cannot be**: `intInc` is an edge from `.int` to `.int`, and
`stringFromInt`/`intFromString` make a cycle. What the map is, is a **typed hypergraph**, a signature table
like a grammar's productions: each instruction an edge from a multiset of input types to one of a few
output multisets. Backward chaining over it *builds* a DAG: one instruction occurrence per node, each
consuming values produced by earlier ones. That DAG is exactly a provenance DAG, which is what a crux
already is.

## Answers to the question asked

- **The limits: keep them out**, as a filter applied after every edge. The survey supports this
  strongly: they are rare, size-driven, never redirect a result, and come from the interpreter.
- **Body errors: in the map, as domain conditions** on an edge, not as an output edge to `.error`. A
  synthesizer chaining backwards wants the result type and needs to know when it is undefined.
- **Starvation: out**; it is already derived from `requirements`.
- **What is not yet well formed**: (a) `.exec:Code`/`.exec:Instruction` continuations, which need a
  control-edge reading; (b) `.iterator` as one type, which needs refining by element type; (c) the
  direct-write and shape operations, which need declared effects.

## If this is built

A declaration beside `requirements`, say `produces`, giving each Behavior's alternatives, would make the
map a property of the language. The survey becomes its test, in the way the roles comment suggests: drive
every Behavior and fail if a Router falls outside its declared alternatives. Pieces it would need:
iterator element types; a convention for `.exec` literals as deferred pushes; a control-edge marker for
continuations; shape effects for the combinators.
