# Inputs and Constants

Give a program its data: inputs that change with each training case, and
constants that belong to the individual.

## Overview

A program reaches values from outside itself in two ways, and both are
instructions that take no arguments:

| | Instructions | Supplied by | Changes |
|---|---|---|---|
| **Inputs** | `.input0`, `.input1`, … | a ``TrainingCase`` | with every training case |
| **Constants** | `.int0`, `.string3`, `.vecDouble7`, … | an ``Individual`` | with every individual |

Both are maps from an instruction to an item. The `bindings(_:)` function
builds such a map from plain Swift values:

```swift
let trainingCase = TrainingCase(id: "case 1", inputs: bindings([
    .input0: 5,
    .input1: [1, 2, 3],
]))
let individual = Individual(
    id: "candidate 1",
    program: program { PushInstruction.input0; PushInstruction.int0; PushInstruction.intAdd },
    constants: bindings([.int0: 10]))
```

## Inputs

An input instruction pushes the item its training case binds to it. The item can
be of any type, so `.input0` may be an int in one problem and a vector of
strings in another; the instruction is the same. An input reaches its stack by
way of `.exec`, one step after the instruction runs, exactly as if the value had
been written in the program at that point. A code block bound to an input
therefore comes to rest on `.code`, as any code block does.

An input instruction with nothing bound pushes nothing and leaves an error of
kind ``ErrorKind/missingInput``. That is ordinary in a search: a program drawn
from the whole language will mention inputs the problem doesn't have. A program
can count these misses for itself with `.errorMissingInputCount`.

Every bound input is also bound on the `.binding` stack when a run starts,
under its slot number: input 0 under key 0, input 1 under key 1. A program can
then reach an input through the binding instructions, and can compute which
input to read. See <doc:Variables>.

## Constants

A constant instruction pushes a value that belongs to the individual. There are
constants for eight types: ints, doubles, chars, strings and the four kinds of
vector. Bools have none.

Constants exist so that a program's *structure* and its *numbers* can vary
separately. A program that mentions `.int3` instead of a literal 42 can be given
a different value for `.int3` without changing a single item of the program, so
a search can adjust a program's constants by one method while it rearranges
programs by another. Two individuals with the same program and different
constants are different individuals, and need different identifiers.

A constant has a type, fixed by its name. A value of the wrong type for its slot
(a string bound to `.int3`) is ignored when the run is loaded, and the slot
stays empty. A constant instruction whose slot is empty pushes nothing and
leaves an error of kind ``ErrorKind/missingConstant``;
`.errorMissingConstantCount` counts them.

Like an input, a constant reaches its stack by way of `.exec`, one step after
its instruction runs.

## Putting sets together

`merged(_:)` combines maps, with later ones winning, which is convenient for
laying an individual's own values over a shared set:

```swift
let shared = bindings([.int0: 10, .int1: 100, .string0: "seed"])
let constants = merged(shared, bindings([.int0: 42]))   // int0 is 42
```

## How many slots

Today there are ten input slots and ten constant slots for each type, numbered
0 to 9. Don't build that number into your code: the instructions that exist are
the authority, and the count may grow. Ask the language instead:

```swift
let runner = Runner()
runner.instructions(role: .input)       // every input instruction
runner.instructions(role: .constant)    // every constant instruction
```

## Inputs, constants and provenance

Inputs and constants belong to the *environment* of a run: they are supplied
from outside and are the same every time the same pairing is evaluated. So when
an item's crux mentions `.input0` or `.int3`, it mentions them by name, and the
crux reproduces the item when it is run with the same inputs and constants.
That is also how the library can tell you whether an answer depends on its
inputs at all (``RunnerConfiguration/cruxInputTokens``). See <doc:Provenance>.

## See Also

- <doc:WritingPrograms>
- <doc:EvaluatingPrograms>
- ``TrainingCase``
- ``Individual``
- ``bindings(_:)``
- ``merged(_:)``
