# Code and Control

Code blocks are data until an instruction runs them; running them is how a
program branches, repeats and recurs.

## Code blocks

A **code block** is a list of items in parentheses: `( 2 .intMultiply )`. It can
hold anything, other code blocks included, so it is also the language's one
container for items of mixed types. Code blocks live on the `.code` stack.

A code block in a program doesn't run when the interpreter reaches it. It goes
onto `.code` intact, as data, where code instructions can measure it, take it
apart, search it and build new code blocks from it. To run a code block, an
instruction takes it from `.code` and puts its contents onto `.exec`, the stack
of things still to run:

```
( 1 .intAdd ) 3 .codeDo        →  .int holds 4
```

Every instruction that runs a code block takes it from `.code`, so a code block
is always written before the instruction that uses it. That keeps the code block
an ordinary item until the moment it runs: a program can copy it, edit it or
bind it to a variable first. <doc:DesignOfPlunge> says more about this choice.

## Inside a code block

Code instructions address a code block in three ways:

- its **root items**, the items at its top level (`.codePeekNthRoot`,
  `.codeLengthRoot`);
- its **points**, every node of the tree in order, the code block itself first
  (`.codePeekNth`, `.codeLength`): `( ( 1 2 ) 3 )` has five points, which are
  the whole code block, `( 1 2 )`, 1, 2 and 3;
- its **gaps**, the places between items where something can be inserted or the
  code block cut (`.codeInsertAtGap`, `.codeCutAtGap`).

An index into a code block is clamped into range, not refused. Only an empty
code block, which has no items, can refuse to give one up.

## Branching

A condition is a bool on `.bool`, and the branches are code blocks on `.code`,
written before the instruction:

```
true ( 10 ) ( 20 ) .execIf     →  .int holds 10; the other code block is discarded
```

- `.execIf` chooses between two code blocks, and discards the one it doesn't
  run.
- `.execWhen` runs one code block when the bool is true, and discards it
  otherwise.
- `.codeDoIf` runs one code block when the bool is true, and otherwise leaves it
  on `.code` untouched.

## Repeating

The loop instructions take a count from `.int` and a body from `.code`:

```
1 3 ( 2 .intMultiply ) .execDoTimes    →  .int holds 8; the body returns to .code
```

- `.execDoTimes` runs the body n times.
- `.execDoCount` pushes 0, 1, …, n − 1 in turn, running the body after each.
- `.execDoRange` counts from one int toward another, stopping short of it, as
  every counted loop does (equal bounds make one pass).
- `.execWhile` runs the body as long as the bool on top of `.bool` is true,
  taking a new bool before each pass; `.execDoWhile` runs it once first.

When a loop finishes, its body goes back onto `.code`, so the next instruction
can run it again or take it apart. A loop doesn't use up its body.

## Recursion and combinators

`.execY` runs a code block and then queues itself to run the code block again,
which is how a program recurs. It stops when the code block stops it or the run
reaches its step limit. `.execK` and `.execS` are the K and S combinators of
combinatory logic, over code blocks: `( a ) ( b ) .execK` runs a and drops b,
and `( a ) ( b ) ( c ) .execS` runs a, c, b, then c again.

## Code blocks as functions

`.codePushAllFunctions` turns a code block into the functions its pushes
compute, with a hole wherever the code block reached for an argument it did not
have, and puts them on `.function` for map, filter and reduce. See
<doc:Functions>.

## Loops as items

The loops above run to completion once started. An *iterator* is a loop that is
also an item: it can be paused, inspected, adjusted and resumed. See
<doc:Iterators>.

## See Also

- <doc:CodeInstructions>
- <doc:ExecInstructions>
- <doc:Functions>
