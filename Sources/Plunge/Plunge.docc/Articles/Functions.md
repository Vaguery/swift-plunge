# Functions: Map, Filter and Reduce

Apply a function to every element of a vector or string, keep the elements a
function approves of, or fold them into one value.

## Overview

A **function** is an item on the `.function` stack: a body with typed **holes**.
Filling every hole gives a runnable program. A function is data: met on `.exec`,
it comes to rest on `.function`, as a block comes to rest on `.code`, and nothing
runs it except an instruction that applies it.

Functions come from two places.

**Starvation.** An instruction that comes up short for arguments records its
missing-arguments error, as always, and is also put on `.function` as a *bare*
function: the instruction alone, whose holes are the arguments it wanted. Nothing
it found is bound into it or taken. `.intAdd` on an empty `.int` leaves
`ƒ( ⟨int⟩ ⟨int⟩ .intAdd )`. Every instruction does this, stack shuffles included,
so `.intDup` and `.intSwap` reach `.function` too.

**`codePushAllFunctions`.** It takes a block from `.code` and runs it in a sandbox,
supplying a placeholder for every argument an instruction is missing. Every item
the block makes from a placeholder becomes a function, with a hole where the
placeholder was:

```
( 2 .intAdd .intMultiply ) .codePushAllFunctions
    →  .function holds ƒ( ⟨int⟩ ⟨int⟩ 2 .intAdd .intMultiply ) above ƒ( ⟨int⟩ 2 .intAdd )
```

One hole can sit in several places: `( .intDup .intMultiply )` yields
`ƒ( ⟨int⟩ .intDup .intMultiply )`, which squares its one argument. A block whose
derivation runs too long yields nothing and leaves one error. Errors the block
raises inside the sandbox stay there. A run pays for deriving a block the first
time it converts one with those contents; later copies cost nothing more.

## Applying a function

`vecIntMap`, `vecIntFilter`, `vecIntReduce`, their siblings for the other vector
types, and `stringMap`, `stringFilter` and `stringReduce` each take a collection
and the **topmost function on `.function` that fits** the job:

- **map** needs a hole of the element's type and a value a collection can hold;
- **filter** needs a hole of the element's type and a bool;
- **reduce** needs two holes of the element's type and a value of that type.

The element fills the function's first hole of its type. For reduce, the running
value fills the first and the next element the second: a left fold from the
first element. **Every other hole is filled from the program's own stacks**, top
first, read and left in place, so every element sees the same values:

```
.intAdd 10 [1 2 3] .vecIntMap     →  .vecInt holds [11, 12, 13], and 10 is still on .int
```

Each application runs the filled function in a fresh interpreter, which sees the
program's inputs and constants. Its **result** is the top of the function's output
stack afterward. An application that leaves nothing there passes its element
through (map), drops it (filter) or keeps the running value (reduce). A map's
results must all be one type, or the map is refused.

```
( 2 .intMultiply ) .codePushAllFunctions [1 2 3] .vecIntMap     →  [2, 4, 6]
( 2 .intMod 0 .intEq ) .codePushAllFunctions [1 2 3 4] .vecIntFilter     →  [2, 4]
( .intAdd ) .codePushAllFunctions [1 2 3 4] .vecIntReduce     →  .int holds 10
```

## When there is no function

- An **empty** `.function` is a missing argument: the instruction starves, takes
  nothing, and is itself put on `.function`.
- A `.function` with **nothing that fits**, or a function whose other holes can't
  be filled from the program's stacks, is a miss: the instruction takes its
  arguments and leaves an error of kind `notFound`.

## Cost

Every step a function takes counts against the program's own step limit, and so
does every step `codePushAllFunctions` spends deriving a block. A map that would
run past the limit is refused, so a function can't be used to escape it.

## Another way to map

An iterator with a body maps too, **stack-fed**: for each element,
`vecFromIterator` runs the element and then the body in a fresh interpreter, so the
element arrives on its own stack, and it collects what the body leaves. The
`iteratorOver…` instructions build such an iterator in one step from a collection
and a block.
