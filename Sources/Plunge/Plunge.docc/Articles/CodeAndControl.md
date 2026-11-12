# Code and Control

Blocks are data until an instruction runs them; running them is how Push
branches, repeats and recurses.

## Blocks

A **block** is a list of items in parentheses: `( 2 .intMultiply )`. It can hold
anything, other blocks included, so it is also the language's one container for
items of mixed types. Blocks live on `.code`.

A block in a program doesn't run when the interpreter reaches it. It goes onto
`.code` intact, as data, where code instructions can measure it, take it apart,
search it and build new blocks from it. To run a block, an instruction takes it
from `.code` and puts its contents onto `.exec`, the stack of things still to
run:

```
( 1 .intAdd ) 3 .codeDo        →  .int holds 4
```

## Inside a block

Code instructions address a block in three ways:

- its **root items**, the items at its top level (`codePeekNthRoot`,
  `codeLengthRoot`);
- its **points**, every node of the tree in order, the block itself first
  (`codePeekNth`, `codeLength`): `( ( 1 2 ) 3 )` has five points;
- its **gaps**, the places between items where something can be inserted or the
  block cut (`codeInsertAtGap`, `codeCutAtGap`).

An index into a block is clamped into range rather than refused. Only an empty
block, which has no items, can refuse to give one up.

## Branching

A condition is a bool on `.bool`, and the branches are blocks on `.code`, written
before the instruction:

```
true ( 10 ) ( 20 ) .execIf     →  .int holds 10; the other block is discarded
```

- `execIf` chooses between two blocks; `execWhen` runs one or discards it, and `codeDoIf` runs one or leaves it.
- `execWhen` runs a block or discards it.
- `codeDoIf` runs a block or leaves it on `.code` untouched.

## Repeating

The loop instructions take a count from `.int` and a body from `.code`:

```
1 3 ( 2 .intMultiply ) .execDoTimes    →  .int holds 8; the body returns to .code
```

- `execDoTimes` runs the body n times.
- `execDoCount` pushes 0, 1, …, n − 1, running the body after each.
- `execDoRange` counts from one int toward another, stopping short of it, as
  every counted loop does (equal bounds make one pass).
- `execWhile` runs the body as long as the bool on top of `.bool` is true, taking
  a new bool before each pass; `execDoWhile` runs it once first.

When a loop finishes, its body goes back onto `.code`, so the next instruction can
run it again or take it apart.

## Recursion and combinators

`execY` runs a block and then queues itself to run the block again, which is how
a program recurses; it stops when the step limit is reached or the block stops
it. `execK` and `execS` are the K and S combinators of combinatory logic over
blocks: `( a ) ( b ) .execK` runs a and drops b, and `( a ) ( b ) ( c ) .execS`
runs a, c, b, then c again.

## Blocks as functions

`codePushAllFunctions` turns a block into the functions its pushes compute, with
a hole wherever the block reached for an argument it did not have, and puts them
on `.function` for map, filter and reduce. See <doc:Functions>.

## Loops as items

The loops above run to completion inside the instruction that starts them. An
*iterator* is a loop that is also an item: it can be paused, inspected, adjusted
and resumed. See <doc:Iterators>.

## See Also

- <doc:CodeInstructions>
- <doc:ExecInstructions>
- <doc:Functions>
