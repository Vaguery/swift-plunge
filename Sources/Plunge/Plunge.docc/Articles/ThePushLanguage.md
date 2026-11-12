# The Push Language

A language designed to be written by evolution: every program runs, whatever it
contains.

## Overview

[Push](https://faculty.hampshire.edu/lspector/push.html) was designed by Lee
Spector and colleagues for *genetic programming*: searching for programs by
generating, varying and selecting them, rather than writing them. A search like
that produces programs no person would write, so the language is built to give
every one of them a meaning. There are no syntax errors, no type errors and no
crashes. An instruction that can't do its job leaves an error item behind, and
the program carries on.

This library implements a modern dialect of Push. It shares the classic ideas and
departs from earlier interpreters in a number of places; those are noted below.

## Stacks and items

A Push interpreter keeps **one stack per type**. Every value is an *item*, and
every item lives on the stack for its type:

| Stack | Holds |
|---|---|
| `.bool` | `true` and `false` |
| `.int` | 64-bit integers |
| `.double` | 64-bit floating-point numbers |
| `.char` | single characters |
| `.string` | text |
| `.vecBool`, `.vecInt`, `.vecDouble`, `.vecString` | vectors of each |
| `.code` | blocks: lists of any items, nested |
| `.iterator` | loops in progress |
| `.binding` | keyed bindings: variables |
| `.function` | functions: bodies with typed holes (see <doc:Functions>) |
| `.exec` | the program still to run |
| `.error` | what went wrong, one item per problem |

Instructions take their arguments from the tops of the stacks they need, and
push their results onto the stacks of the results' types. Because each type has
its own stack, an instruction never meets an argument of the wrong type: `intAdd`
takes two items from `.int` and only `.int`.

## Programs

A program is a list of items: literals and instructions. Running it puts the list
on `.exec`, and the interpreter repeatedly takes the top item and acts on it:

- a **literal** goes onto its type's stack;
- an **instruction** runs;
- a **block** goes onto `.code`, as data.

So Push is postfix. In this documentation programs are written with instructions
prefixed by a dot, blocks in parentheses, strings in double quotes and characters
in single quotes:

```
3 4 .intAdd 2 .intMultiply          →  .int holds 14
"hello" .stringLength               →  .int holds 5
( 1 .intAdd ) 3 .codeDo             →  .int holds 4
```

When an argument order matters, the instruction reference writes it the same way:
`a b .intSubtract` gives a − b, because `b` was pushed last and is on top.

## Every program runs

An instruction that finds too few items on a stack it needs does nothing to the
stacks and pushes a *missing arguments* error onto `.error`. An instruction that
finds its arguments but can't use them (a division by zero, an index into an
empty string, an integer that would overflow) **refuses**: it uses up the
arguments it took (a query still leaves what it only read), pushes an error
explaining why, and pushes no result. Either way the program continues with its
next item.

Nothing is allowed to grow without bound, either. Strings, vectors, blocks and
stacks all have size limits, and a run stops after a fixed number of steps. See
<doc:HowTheInterpreterRuns>.

## Code is data

A block such as `( 2 .intMultiply )` is an item like any other. Met on `.exec` it
comes to rest on `.code`, where instructions can take it apart, rebuild it, store
it, or compare it. Control instructions run blocks: `codeDo` runs one,
`execIf` chooses between two, `execDoTimes` repeats one, and the iterators run
one per element of a collection. This is how Push expresses conditionals, loops
and functions without any syntax for them.

## Inputs and constants

A program meets the outside world through two kinds of instruction:

- **Inputs**, `input0` to `input9`, push the values bound for the current
  ``TrainingCase``. The same program runs once per training case.
- **Constants**, such as `int3` or `string0`, push values that belong to the
  ``Individual``: a search can tune them without changing the program's
  structure.

Inputs are also bound on the `.binding` stack at the start of every run, under
the keys 0 to 9, so a program can reach them by key as well as by name.

## Questions about the stacks

Most instructions that *ask* something read their arguments and leave them in
place: `intGT` compares the top two ints and pushes a bool, leaving both ints
where they were. Instructions that *transform* something consume it. An
instruction that searches and finds nothing is a refusal, like starvation.

## Differences from other Push interpreters

If you know Push from Clojush, Propeller or PushGP, these are the differences
most likely to surprise you:

- **Blocks rest on `.code`.** Earlier interpreters unpacked a block met on `.exec`
  and ran it. Here, code is data until an instruction runs it, and every control
  instruction takes its body from `.code`.
- **Queries don't consume.** Comparisons and other questions leave their
  arguments on the stack.
- **Refusals are explicit.** Where other interpreters quietly do nothing, this one
  leaves an ``ErrorItem`` saying why.
- **Iterators are first-class.** Loops are items on their own stack, which a
  program can inspect, adjust and resume.
- **Results remember how they were made.** With provenance recording on, every
  item carries a *crux*: a short program that reproduces it. This is what a search
  can use to explain or reuse what a program computed.
