# Forms of a Crux

Take a crux further: replace its constant work with values, turn its constants
into holes, give its inputs parameters, or reduce it to its shape.

## Overview

A crux (<doc:Provenance>) is the part of a program that made one item. From it
follow four more forms, each a step more abstract, and each still a program
that runs:

```
program    .input0 .double0 .double1 .doubleMultiply .doubleMultiply true .boolNot
           2.0 3.0 .doubleAdd 7 .intDup .intAdd .input1 .doubleMultiply .doubleAdd
crux       ( .input0 .double0 .double1 .doubleMultiply .doubleMultiply
             2.0 3.0 .doubleAdd .input1 .doubleMultiply .doubleAdd )
distilled  ( .input0 «distilled .doubleMultiply: 1.5» .doubleMultiply
             «distilled .doubleAdd: 5.0» .input1 .doubleMultiply .doubleAdd )
abstract   «fn (dbl, dbl) -> dbl: .input0 $0 .doubleMultiply $1 .input1 .doubleMultiply .doubleAdd»
tunable    «fn (dbl, dbl, dbl, dbl, dbl, dbl) -> dbl: .input0 $0 .doubleMultiply $1 .doubleAdd
             $2 .doubleMultiply $3 .input1 $4 .doubleMultiply $5 .doubleAdd .doubleMultiply .doubleAdd»
skeleton   «fn (dbl, dbl, dbl, dbl) -> dbl: $0 $1 .doubleMultiply $2 $3 .doubleMultiply .doubleAdd»
```

Here `.input0` is 4.0 (call it x), `.input1` is 10.0 (y), `.double0` is 0.5 and
`.double1` is 3.0, and every form gives 56.0: x·(0.5·3) + (2 + 3)·y.

| Form | Made by | What it keeps | What it is for |
|---|---|---|---|
| crux | ``Item/crux()`` | everything that made the item | the structure a program built |
| distilled | ``Item/distilledCrux()`` | work that reads inputs or the run's state | the work that matters, run cheaply |
| abstract | ``DistilledCrux/abstracted(_:literals:limit:)`` | inputs in place; constants as holes | fitting constants to data |
| tunable | ``DistilledCrux/tunable(_:sites:literals:limit:)`` | inputs in place, each with parameters | fitting everywhere; a standard form |
| skeleton | ``DistilledCrux/skeleton(_:literals:limit:)`` | typed holes and the work between them | comparing and combining shapes |

None of them changes a run, and no instruction can see them: they are tools for
searching and for analysis.

**Value, then structure.** The crux and the distilled crux replay the item's
value exactly. The abstract, tunable and skeleton cruxes describe and modify the
crux's *structure* instead, so they are built on its rolled form (see "Rolled
structure" below). Filled with what was there, they still give the value, but
that is a check, not their purpose.

## The crux: what a program built

A crux shows the semantic structure a program actually encoded for one item,
out of everything it did. It keeps enough to replay that item's processing
explicitly, step by step, so it reads as an explanation and runs as a program.
In the example the bool and int work is gone: the value never depended on it.

## The distilled crux: the work that matters

Much of a random program's work manipulates constants: a constant string
reversed, a character at a constant index removed, the result used to filter a
constant vector of strings. Such work gives the same value whenever the
constants are the same. A distilled crux puts that value in its place, as a
stand-in marked `distilled`, and keeps everything that reads an input or the
run's state. What is left is the part of the crux that really produces the value
from the data, and it runs in fewer steps: 9 here, where the crux takes 15.

Every history node records what it reads (``CruxDependence``), so finding the
constant work needs no evaluation: each node already holds the value it made.
Each replaced branch is listed in ``DistilledCrux/derived`` as a
``DerivedConstant``, with the constant slots it read and the history it
replaced, so a search can tune it as a new constant of its own, or expand it
again after changing a slot it read.

A distilled crux keeps the crux's promise. Run with the same inputs and
constants, it gives the same value, and with other inputs it gives what the crux
gives. It is never longer. Two things are deliberately left as they are:

- **The run's state.** An observed stand-in (a stack depth, an error count) is
  context, not constant work, so it stays, and so does the work that uses it.
- **A print.** A printed item rests on `.print`, so the print stays; the work
  before it is distilled.

This is not simplification. No algebra is done: `x 1 .intAdd 1 .intSubtract`
stays as it is when `x` reads an input.

## The abstract crux: fitting constants

The abstract crux turns every constant (each constant slot, each derived
constant, each literal) into a typed hole and **leaves the inputs where they
are**. Each hole has an ``AbstractCrux/Role`` saying what was there, and
``AbstractCrux/function`` makes it a ``FunctionItem`` the language can apply and
compose.

With the inputs in place it is still a model of the data it came from, with its
constants free, so numerical methods can assign them anew. The example's
abstract crux is x·k₀ + k₁·y. Fitted by least squares to data made by 3x + 2y,
it gives k₀ = 3 and k₁ = 2, and
``AbstractCrux/program(filling:)`` writes the fitted program,
`( .input0 3.0 .doubleMultiply 2.0 .input1 .doubleMultiply .doubleAdd )`. A
structure found by search informs better constants, and the fitted program is
simpler code congruent with the original. Filled with
``AbstractCrux/originalFillers``, it gives back the crux's value.

Constant slots of one type are interchangeable: reading `.double3` instead of
`.double0` gives the same abstract crux, and so the same
``AbstractCrux/key``. Which input is read is not interchangeable. With
``AbstractCrux/Reading/perDistinct`` a slot used twice is one hole; with
``AbstractCrux/Reading/perUse`` each use is its own.

## The tunable crux: fitting everywhere

The tunable crux wraps each input in a parametric transform whose parameters
are control holes, with a neutral setting that leaves the crux exactly as it
was:

| Type | Transform | Neutral |
|---|---|---|
| int, double | x·a + b | a = 1, b = 0 (−0.0 for a double) |
| bool | (x and m) xor c, which reaches all four one-argument functions | m = true, c = false |
| char | its code point shifted by s | s = 0 |
| vecInt, vecDouble | every element scaled and shifted, then framed and trimmed | 1, 0, empty, 0 |
| vecBool | every element (v and m) xor c, then framed and trimmed | true, false, empty, 0 |
| string, vecString | a prefix and a suffix joined on, then items dropped from each end | empty, 0 |

Code blocks, functions, iterators and bindings get none, and nonlinear
transforms (a logarithm, a square) are left for search to find.

Fitting can then reach parts of the code that had no constant to tune, and it
starts from the crux itself, so it can only improve on it. The tunable crux is
also meant as the standard form for comparing code: a fragment written with a
parameter and one written without should come out the same. Today the tunable
crux of the bare input `.input0` is exactly the abstract crux of
`.input0 2.0 .doubleMultiply 1.0 .doubleAdd`. Decoration is not yet
idempotent, though: an input that already has a transform gets another.

## The skeleton crux: shapes

The skeleton crux makes the inputs holes too, leaving only typed holes and the
work between them. `x·c`, `y·c`, `2·y` and `(c₀ + c₃)·x` all have the skeleton
`«fn (dbl, dbl) -> dbl: $0 $1 .doubleMultiply»`.

It compares programs at the most abstract level, and can track a search's
progress through program architectures. Because it can be made a function
(``AbstractCrux/function``), it also supports moves Push otherwise lacks: ``AbstractCrux/opening(_:)`` turns any
subtree in ``AbstractCrux/subtrees`` into a hole of its type, and the result
works with `.functionApply`, `.functionCompose` and the maps.

## Rolled structure

A history records a loop once per pass: `0 ( .input0 .intAdd 12 .intMin ) 50
.execDoTimes` leaves a crux with its body written out fifty times. Abstracting
that would give every pass its own holes, as if each `12` were a different
constant. So the abstract, tunable and skeleton cruxes first **roll** the
history: every run of identical passes, written as a loop or not, becomes a
counted loop again, `seed ( body ) count .execDoTimes .codePop`, with its
original count. Three passes or more always roll; two roll when the body has at
least three items.

Holes then attach to the rolled structure:

```
abstract   «fn (int, int, int) -> int: $0 ( .input0 .intAdd $1 .intMin ) $2 .execDoTimes .codePop»
tunable    «fn (int, int, int, int, int) -> int: $0 ( .input0 $1 .intMultiply $2 .intAdd .intAdd $3 .intMin )
             $4 .execDoTimes .codePop»
skeleton   «fn (int, int, int, int) -> int: $0 ( $1 .intAdd $2 .intMin ) $3 .execDoTimes .codePop»
```

The seed, the body's constant and the count are each one hole. An input read in
the body keeps its place and, in the tunable crux, gets one transform, the same
on every pass. A hole inside a loop's body is marked in
``AbstractCrux/template``. ``AbstractCrux/function`` still makes a function the
language can run, by building that body from quoted pieces:
`( .input0 .intAdd ) $1 .intQuote .codeConcat ( .intMin ) .codeConcat`.

The abstract, tunable and skeleton cruxes are written as trees, so a value the
history reuses (by dup or yank) is written out once per use. To roll loops but
keep reuse shared, as the distilled crux does, use
``DistilledCrux/rolledProgram``: its size counts a loop once and a reused value
once, and it replays to the same value.

Rolling keeps a loop's count. To lower it, use
``Item/minimizingLoops(on:settings:stack:)``, which tries smaller counts and keeps
one only while replays on the cases given still produce the item's value: the
loop above needs 3 passes, not 50.

## Constructing structures

New structures can be built from known ones as well-typed expressions. Each step
returns a new ``AbstractCrux``, or `nil` when the operator's signature doesn't fit:

| Step | Builds | From `$0` |
|---|---|---|
| ``AbstractCrux/wrapped(by:)`` | op(S) | `$0 .doubleAbs` |
| ``AbstractCrux/extended(by:with:leafFirst:)`` | op(S, a new hole) | `$0 $1 .doubleMultiply` |
| ``AbstractCrux/reused(by:)`` | op(S, S), shared | `$0 .doubleDup .doubleMultiply` |
| ``AbstractCrux/combined(with:by:)`` | op(S, T) | `$0 $1 .doubleDup .doubleMultiply .doubleSubtract` |
| ``AbstractCrux/grafted(_:into:)`` | a hole of S replaced by T | `$0 $1 $2 .doubleAdd .doubleMultiply` |

They compose, since every template nets one value on its output stack. A new hole
added by construction has the role `anyInput` or `anyConstant`: which input or
constant fills it is for the filler to say.

## Getting the forms

Record provenance, take the item, and ask for each form:

```swift
let distilled = answer.item.distilledCrux()
print(CodeItem(distilled.program).pretty())
let abstract = distilled.abstracted()!       // nil only past the size limit
print(abstract.key)
let refitted = abstract.program(filling: [DoubleItem(3), DoubleItem(2)])
```

## What the forms can't reach yet

- **Functions.** A function made by `.codePushAllFunctions` enters a crux as an
  observed stand-in, so a map over it isn't distilled, and the constants in its
  body never become holes.
- **Deeper code blocks.** Holes reach into a rolled loop's body, one level
  deep. A loop the interpreter folded itself (over the history budget), and a
  code block nested inside a body, keep their constants as they are.
- **Repeats that differ by an index.** A loop over a vector's elements, or a
  map written out element by element, isn't rolled yet: its passes differ by
  the index.
- **Shared literals.** Constant slots can share a hole; equal literals don't.

## See Also

- <doc:Provenance>
- ``DistilledCrux``
- ``AbstractCrux``
- ``TunableCrux``
- ``LoopMinimization``
- ``CruxDependence``
