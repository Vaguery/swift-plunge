# Inputs and Constants

Give a program its data: inputs that change with each training case, and
constants that belong to the individual.

## Overview

A program reaches values from outside itself in two ways, and both are
instructions that take no arguments:

| | Instructions | Supplied by | Changes |
|---|---|---|---|
| **Inputs** | `.input(0)`, `.input(1)`, … | a ``TrainingCase`` | with every training case |
| **Constants** | `.constant(0)`, `.constant(1)`, … | an ``Individual`` | with every individual |

Each is a numbered family with no last member: `.input(k)` and `.constant(k)`
exist for every `k` of 0 or more. A program prints them as `.input0` and
`.constant12`, and those are also their names when encoded.

Both are maps from an instruction to an item. The `bindings(_:)` function
builds such a map from plain Swift values:

```swift
let trainingCase = TrainingCase(id: "case 1", inputs: bindings([
    .input(0): 5,
    .input(1): [1, 2, 3],
]))
let individual = Individual(
    id: "candidate 1",
    program: program { PushInstruction.input(0); PushInstruction.constant(0); PushInstruction.intAdd },
    constants: bindings([.constant(0): 10]))
```

## Inputs

An input instruction pushes the item its training case binds to it. The item can
be of any type, so `.input0` may be an int in one problem and a vector of
strings in another; the instruction is the same. A configuration can declare
each input's type and name (see *Declaring a problem's inputs*, below). An input reaches its stack by
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

## Declaring a problem's inputs

A ``RunnerConfiguration`` can declare a problem's inputs, in slot order, as
``InputSlot``s. Each may give a name and a type:

```swift
let configuration = RunnerConfiguration(inputSlots: [
    InputSlot("b", stack: .int),
    InputSlot("x1", stack: .vecInt),
    InputSlot("x2", stack: .vecInt),
])
```

**The type is checked.** ``Runner/register(trainingCases:)`` doesn't keep a
training case that binds an undeclared input, or a value that doesn't rest on
the declared stack, and returns an ``InputMismatch`` for each such input. A run
leaves a refused input unbound, so `.inputN` reports it missing. Under this
configuration, `configuration.signature(of: .input0)` says that `.input0` gives
an int, where the language alone can't say. Declaring nothing, the default,
allows any input of any type.

For an input whose values have different types from case to case, declare
`.binding` and bind each value inside a ``BindingItem``: the slot then has one
type, whatever the pair holds.

**The name is for people.** `labeled(_:)` writes a program or a crux with each
named input shown by its name:

```swift
configuration.labeled(program { PushInstruction.input(1); PushInstruction.input(0) })
// ".input-x1 .input-b"
```

The name never changes what a program means. The program, its crux, its
encoding and `pretty()` all keep `.input0`, so the same program means the same
thing whatever problem it runs on. `inputSlotIssues` describes names that are
empty, contain white space or repeat.

## Constants

A constant instruction pushes a value that belongs to the individual.

Constants exist so that a program's *structure* and its *numbers* can vary
separately. A program that mentions `.constant(3)` instead of a literal 42 can be
given a different value for `.constant(3)` without changing a single item of the
program, so a search can adjust a program's constants by one method while it
rearranges programs by another. Two individuals with the same program and
different constants are different individuals, and need different identifiers.

**A constant has no type.** Its slot holds an item of any type, including a
Boolean, a code block or a function, and the item goes to its own stack when the
instruction runs. So changing a constant means changing the value an individual
binds to it: its instruction only says which slot to read, and naming a
different slot reads a different value, not another of the same type. (Until
2026-11-19 constants had typed names, ten of each type: `.int3` became
`.constant(3)`, `.double3` became `.constant(13)`, and `.vecBool9` became
`.constant(79)`.)

A constant instruction whose slot is empty pushes nothing and leaves an error of
kind ``ErrorKind/missingConstant``; `.errorMissingConstantCount` counts them.

Like an input, a constant reaches its stack by way of `.exec`, one step after
its instruction runs.

## Putting sets together

`merged(_:)` combines maps, with later ones winning, which is convenient for
laying an individual's own values over a shared set:

```swift
let shared = bindings([.constant(0): 10, .constant(1): 100, .constant(2): "seed"])
let constants = merged(shared, bindings([.constant(0): 42]))   // constant0 is 42
```

## How many slots

As many as a problem and an individual need: the families have no last member.
The language *lists* the first few of each wherever it lists its instructions:
ten inputs (`.input(0)` to `.input(9)`, ``PushInstruction/listedInputCount``)
and eighty constants (`.constant(0)` to `.constant(79)`,
``PushInstruction/listedConstantCount``). Those are the ones random code draws
from; any other member behaves the same way.

```swift
let runner = Runner()
runner.instructions(role: .input)       // the listed inputs
runner.instructions(role: .constant)    // the listed constants
runner.signature(of: .input(25))        // the same as .input(0)'s
```

Random code fills the listed constants by a convention of its own, ten of each
type (``PushInstruction/conventionalConstantStacks``). The language does not
check it.

## Inputs, constants and provenance

Inputs and constants belong to the *environment* of a run: they are supplied
from outside and are the same every time the same pairing is evaluated. So when
an item's crux mentions `.input0` or `.constant3`, it mentions them by name, and the
crux reproduces the item when it is run with the same inputs and constants.
That is also how the library can tell you whether an answer depends on its
inputs at all (``RunnerConfiguration/cruxInputTokens``). See <doc:Provenance>.

## See Also

- <doc:WritingPrograms>
- <doc:EvaluatingPrograms>
- ``TrainingCase``
- ``Individual``
- ``InputSlot``
- ``bindings(_:)``
- ``merged(_:)``
