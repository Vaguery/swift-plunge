# Writing Programs in Swift

Build a program as an array of items, print it, and ask the language what
instructions it has.

## Overview

A program is an array of items: `[any Item]`. The library has no text format
and no parser. Its callers are other programs, and a search assembles a program
from pieces it already holds as values. What the library does provide is a
short way to write a program by hand, for tests and examples, and a way to
print any item.

## The program builder

`program { … }` turns a list of Swift literals and instructions into items:

```swift
let small = program {
    3
    4
    PushInstruction.intAdd
    2.5
    "hi"
    true
}
```

Each line becomes one item. Ints, doubles, strings and bools are wrapped for
you. An instruction is a case of ``PushInstruction``, and may be written in full
or with a leading dot (`.intAdd`). Any item can also stand on a line of its own,
which is how to include the types Swift has no bare literal for:

```swift
let more = program {
    CharItem("x")
    VecIntItem([1, 2, 3])
    PushInstruction.vecIntSum
}
```

The builder (``PushProgram``) accepts `if`, `if`-`else` and `for`, so a program
can be assembled conditionally or in a loop.

## Code blocks

A code block is a ``CodeItem`` holding its own array of items. Nest one by
building its contents the same way:

```swift
let nested = program {
    CodeItem(program { 1; PushInstruction.intAdd })
    3
    PushInstruction.codeDo
}
// ( 1 .intAdd ) 3 .codeDo
```

## From values you already have

When the pieces are already in an array, as they are when a search translates
a genome, there are two more routes:

- Make the items directly: `IntItem(3)`, `StringItem("hi")`,
  `InstructionItem(.intAdd)`. This is the route for generated programs, and it
  involves no conversion.
- Convert a mixed array with `program(_:)`, which passes each element to
  ``pushItem(_:)``:

```swift
let flat = program([3, 4, PushInstruction.intAdd, "x", Character("c"), [1.5, 2.5]])
```

``pushItem(_:)`` wraps `Int`, `Double`, `Bool`, `String`, `Character`, the four
kinds of array that are vectors, and ``PushInstruction``, and returns `nil` for
anything else. `program(_:)` leaves out what it can't convert, without
complaint, so prefer the direct route where a dropped item would be a bug.

## Printing

Every item prints itself with ``Pretty/pretty()``, in the notation this
documentation uses throughout. To print a whole program, wrap it in a code
block:

```swift
print(CodeItem(small).pretty())    // ( 3 4 .intAdd 2.5 "hi" true )
print(CodeItem(nested).pretty())   // ( ( 1 .intAdd ) 3 .codeDo )
```

## Asking what the language contains

A search needs to know what instructions exist before it can write programs
with them. The ``Runner`` answers, without running anything, so these calls
need no `await`:

```swift
let runner = Runner()
runner.definedInstructions.count        // how many instructions there are
runner.summary(of: .intSubtract)        // "Subtracts: `a b .intSubtract` gives a − b; refuses on overflow."
runner.signature(of: .intGT)?.reads     // [.int: 2]
runner.instructions(producing: .vecBool)
runner.instructions(touching: .binding)
```

- ``Runner/definedInstructions`` is the whole language, in a fixed order.
- ``Runner/summary(of:)`` is the sentence the <doc:InstructionReference> shows.
- ``Runner/signature(of:)`` says what an instruction takes, reads and gives, as
  an ``InstructionSignature``.
- ``Runner/instructions(producing:)``, ``Runner/instructions(consuming:)``,
  ``Runner/instructions(reading:)`` and ``Runner/instructions(touching:)``
  answer by stack. The first is where to begin when working backward from the
  type of answer a problem wants.
- ``Runner/alwaysSatisfiedInstructions`` lists the instructions that need no
  arguments and so can never starve.
- ``Runner/instructionsByTag`` and ``Runner/tags(of:)`` answer by tag; see
  <doc:TaggingInstructions>.

All of these are derived from the instructions' own definitions when the
library loads, so they can't fall out of step with what the interpreter does.

## Programs without literals

A program doesn't have to contain any literals. One made only of instructions
gets every value it uses from an input or from a constant such as `.int3`, whose
value belongs to the ``Individual`` and not to the program. That separation
lets a search change a program's numbers and its structure independently. See
<doc:InputsAndConstants>.

## Generating programs

Making programs is the search's job, and the library doesn't do it for you.
``RandomCode`` is public only for the library's own tests, and offers nothing a
search should depend on.

## See Also

- <doc:ThePushLanguage>
- <doc:InputsAndConstants>
- ``PushProgram``
- ``pushItem(_:)``
