# Errors, Starvation and Refusals

What happens when an instruction can't do its job, what it leaves behind, and
how a program and a search can each see it.

## Overview

No Push program fails to run. An instruction that can't do its job leaves an
item on the `.error` stack and the program goes on to its next item. An error is
a record, not an exception: nothing unwinds, and nothing is skipped.

Many Push interpreters treat an instruction that can't run as a silent no-op.
This one records every such event, for two reasons. A search learns more from a
program that says "I divided by zero twice and ran out of ints once" than from
one that only gives a wrong answer. And a silent answer can do harm: a lookup
that reported "not found" as −1 would hand a plausible index to the next
instruction, which would use it.

An instruction can fail in two ways: it can *starve*, before it does anything,
or it can *refuse*, once it has its arguments. A *miss* is a refusal of one
particular kind. The interpreter can also step in on its own account.

## Starving

An instruction **starves** when a stack it needs holds too few items.

```
1 .intAdd     →  .int holds 1; .error holds « ‼️ intAdd missing args: .int »;
                 .function holds ƒ( ⟨int⟩ ⟨int⟩ .intAdd )
```

A starved instruction:

- takes nothing: whatever arguments it did find stay where they were;
- pushes a *missing arguments* error that names the stack that came up short;
- puts itself on `.function` as a *bare function*, whose holes are the arguments
  it wanted.

The last point is what makes starvation useful instead of merely harmless. In a
program assembled at random, starvation is the most common event there is, and
each one leaves behind a function that map, filter, reduce and the other
function instructions can apply later. See <doc:Functions>.

Instructions that need no arguments (the inputs, the constants, and the
instructions that measure or clear a stack) can't starve.
``Runner/alwaysSatisfiedInstructions`` lists them.

## Refusing

An instruction **refuses** when it has its arguments and can't use them:

```
1 0 .intQuot     →  .int is empty; .error holds « ‼️ Divide by zero .intQuot: 1 / 0 »
```

A refusal uses up the arguments the instruction takes (a query still leaves the
ones it reads), pushes an error that says why, and pushes no result. Common
refusals are a division by zero, an integer overflow, a double that would be
infinite or not a number, an element asked of an empty collection, and a
conversion that has no answer, such as `"abc" .intFromString`.

An index or a count that is merely out of range is not refused. It is
**clamped** to the nearest one in range, so `.intYank` with an index of 1,000 on
a stack of five items reaches the bottom one. Only an empty collection, which
has no position to clamp to, refuses.

The <doc:InstructionReference> marks every instruction that can refuse with
*may refuse*, and its summary says when. In code,
``InstructionSignature/isPartial`` says the same.

## Missing

A **miss** is the refusal of an instruction that looked for an item and found
none that fits, although the stacks were deep enough. It happens to the
instructions that search:

- a lookup or a find whose probe matches nothing (<doc:SearchingTheStacks>);
- a key with no binding (<doc:Variables>);
- an instruction that wants the topmost function that fits, when none does
  (<doc:Functions>);
- an element-by-element instruction that wants a second vector of the same
  length, when there isn't one (<doc:Collections>).

Like any refusal, a miss uses up the arguments the instruction takes and
leaves the ones it only reads. Its error is of kind ``ErrorKind/notFound``:

```
[7] [1, 2] .vecIntAdd     →  .vecInt holds [7]; .error holds
                             « ‼️ vecIntAdd: nothing on .vecInt fits »
```

Here `.vecIntAdd` took `[1, 2]`, looked for a vector of two ints below it, and
found none. A lookup, which only reads its probe, changes nothing when it
misses.

A miss is not starvation, and the two say different things about a program. A
starved instruction had too little to work with, took nothing, and became a
function. An instruction that missed had enough on its stacks, and none of it
was what it was looking for.

## When the interpreter steps in

- **Missing inputs and constants.** `.input2` in a run whose training case binds
  no input 2, or `.int3` for an individual with no int constant 3, leaves an
  error and pushes nothing. See <doc:InputsAndConstants>.
- **Size refusals.** Every result is checked against the size limits before it
  is pushed. One that is too large is dropped and an error left in its place.
  The instruction's arguments are already used up, and its other results, if it
  has any, are unaffected.
- **Guard stops.** The runaway guard and the memory guard stop a whole run,
  leaving an error marked `RUNAWAY:` or `MEMORY:` and emptying `.exec`.
- **Disabled instructions.** An instruction named in
  ``RunnerConfiguration/disabledBehaviors`` leaves an *unknown instruction*
  error when a program reaches it, and takes nothing.

Reaching the step limit is not an error. The run stops where it is and leaves
no item on `.error`. <doc:LimitsAndGuards> describes how to tell that it
happened.

## Kinds of error

Every ``ErrorItem`` has a message for people (``ErrorItem/value``) and an
``ErrorKind`` for counting (``ErrorItem/kind``). Messages may be reworded
between versions of the library; kinds are stable.

| Kind | Means |
|---|---|
| ``ErrorKind/missingArgument`` | an instruction starved |
| ``ErrorKind/notFound`` | a miss: a lookup, a find or a first-fit argument found nothing |
| ``ErrorKind/emptyCollection`` | an element was asked of a collection that has none |
| ``ErrorKind/conversion`` | a value has no counterpart in the type asked for |
| ``ErrorKind/other`` | any other refusal (division by zero, overflow, a negative count), and unknown instructions |
| ``ErrorKind/missingInput`` | an input instruction with no input bound |
| ``ErrorKind/missingConstant`` | a constant instruction with no constant bound |
| ``ErrorKind/sizeRefusal`` | a push over a size limit, or a sandbox nested too deep |
| ``ErrorKind/guardStop`` | a guard stopped the run |
| ``ErrorKind/invariant`` | a bug in the interpreter itself; please report it |

## What a program can see

A program can read its own error record and can't edit it:

- `.errorStackDepth` pushes how many errors the run has recorded;
- `.errorMissingArgCount`, `.errorMissingInputCount` and
  `.errorMissingConstantCount` count three kinds;
- `.errorPreviousStep` pushes whether the step just before recorded an error, so
  a program can react to a failure straight after it happens.

No instruction pops, reorders or clears `.error`, so a program can't hide its
own failures from whoever is scoring it. The `.error` stack is also exempt from
the limit on stack depth, so an error always has somewhere to land.

## What a search can see

Ask for the errors with recorders (<doc:ObservingARun>):

```swift
let recorders = [
    RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly),
    RecorderSpec("errors", observing: .count(.error), keeping: .finalOnly),
    RecorderSpec("last error", observing: .top(.error), keeping: .finalOnly),
]
```

The count comes back as an int. The error comes back as an item, which you can
cast to read its kind:

```swift
if case .items(let readings)? = result.traces["last error"],
   let error = (readings.last ?? nil)?.item as? ErrorItem {
    print(error.kind, error.value)   // missingArgument intAdd missing args: .int
}
```

What to do with the counts is the search's decision. The library scores
nothing: it doesn't treat a program with errors as worse than one without, and
a correct answer from a program that starved forty times on the way is still a
correct answer.

With provenance recording on, an error has a crux like any other item: a
refusal's crux is the program that reproduces the refusal. See
<doc:Provenance>.
