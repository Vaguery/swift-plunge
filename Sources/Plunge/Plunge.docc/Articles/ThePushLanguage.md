# The Push Language

A language designed to be written by evolution: every program runs, whatever it
contains.

## Overview

[Push](https://faculty.hampshire.edu/lspector/push.html) was designed by Lee
Spector and colleagues for *genetic programming*: searching for programs by
generating, varying and selecting them, instead of writing them. A search like
that produces programs no person would write, so the language is built to give
every one of them a meaning. There are no syntax errors, no type errors and no
crashes. An instruction that can't do its job leaves an error item behind, and
the program carries on.

This library implements **Plunge**, a dialect of Push. It shares the classic
ideas and departs from earlier interpreters in a number of places, which are
listed at the end of this article. In this documentation, *Push* means the
family of languages and the ideas they share, and *Plunge* means this dialect.

## Stacks and items

A Push interpreter keeps **one stack for each type**. Every value is an *item*,
and every item lives on the stack for its type:

| Stack | Holds |
|---|---|
| `.bool` | `true` and `false` |
| `.int` | 64-bit integers |
| `.double` | 64-bit floating-point numbers |
| `.char` | single characters |
| `.string` | text |
| `.vecBool`, `.vecInt`, `.vecDouble`, `.vecString` | vectors of each |
| `.code` | code blocks: lists of any items, nested (see <doc:CodeAndControl>) |
| `.iterator` | loops in progress (see <doc:Iterators>) |
| `.binding` | keyed bindings: variables (see <doc:Variables>) |
| `.function` | functions: bodies with typed holes (see <doc:Functions>) |
| `.exec` | the program still to run |
| `.error` | what went wrong, one item for each problem |
| `.print` | whatever the program printed, as items (see <doc:ObservingARun>) |

The last two are *channels*: the program writes to them and never reads them. No
instruction can pop, reorder or count what is on `.print`, and only a few can
count `.error`, so a program can't edit what it has printed or hide what went
wrong. A caller reads both with recorders.

Instructions take their arguments from the tops of the stacks they need, and
push their results onto the stacks of the results' types. Because each type has
its own stack, an instruction never meets an argument of the wrong type:
`.intAdd` takes two items from `.int` and only from `.int`. This is why a
program assembled at random still runs: whatever order its instructions come in,
each one finds arguments of the right types, or finds too few and says so.

## Programs

A program is a list of items: literals and instructions. Running it puts the
list on `.exec`, and the interpreter repeatedly takes the top item and acts on
it:

- a **literal** goes onto its type's stack;
- an **instruction** runs;
- a **code block** goes onto `.code`, as data.

So Push is postfix: arguments come first, and the instruction that uses them
comes after.

## How this documentation writes programs

The library has no text format for programs; they are built in Swift (see
<doc:WritingPrograms>). The documentation still needs to show them, so it uses
the form that ``Pretty/pretty()`` prints:

| Written | Is |
|---|---|
| `3`, `2.5`, `true` | an int, a double, a bool |
| `"hello"`, `'h'` | a string, a char |
| `[1, 2, 3]` | a vector |
| `.intAdd` | an instruction, with a leading dot |
| `( 1 .intAdd )` | a code block |
| `⟨3 ↦ "x"⟩` | a binding of key 3 to `"x"` |
| `ƒ( ⟨int⟩ 2 .intAdd )` | a function with one int hole |
| `«0→5 by 1 @2»` | an iterator counting from 0 toward 5, two passes in |
| `« ‼️ intAdd missing args: .int »` | an error |

A program is written left to right in the order it runs, and an arrow shows
what it leaves:

```
3 4 .intAdd 2 .intMultiply          →  .int holds 14
"hello" .stringLength               →  .int holds 5
( 1 .intAdd ) 3 .codeDo             →  .int holds 4
```

Where a stack is left holding several items, they are listed **top first**:
after `1 2 3`, `.int` holds 3 2 1.

When the order of arguments matters, the documentation shows the instruction as
a program writes it: `a b .intSubtract` gives a − b, because `b` was pushed last
and is on top.

## Values, items and stacks

The documentation keeps four things apart, and spells each its own way:

| Talking about | Written as | Example |
|---|---|---|
| the value an item expresses | its Swift type | `17` is an `Int`; `"foo"` is a `String` |
| the item itself, on a stack or taken as an argument | its item type | an ``IntItem``, a ``StringItem`` |
| what an instruction takes or gives, in passing | the stack's name, without a dot | takes two `int` items, gives a `vecInt` |
| a stack | the stack's name, with a dot | the `.int` stack, `.exec` |

An instruction is always written with its dot, `.intAdd`, in sentences as in
programs. The parenthesized lists of items on `.code` are always called *code
blocks*.

## Every program runs

An instruction can fail to do its job in two ways. Each one leaves an item on
`.error` and lets the program continue with its next item:

- It **starves** when a stack it needs holds too few items. It leaves a
  *missing arguments* error, takes nothing, and puts itself on `.function` as a
  function waiting for those arguments (see <doc:Functions>).
- It **refuses** when it finds its arguments but can't use them: a division by
  zero, an index into an empty string, an integer that would overflow. It uses
  up the arguments it took, pushes an error that says why, and pushes no result.
  The refusal of an instruction that looked for something and found nothing (a
  lookup with no match, a key with no binding) is called a **miss**.

Nothing is allowed to grow without bound, either. Strings, vectors, code blocks
and stacks all have size limits, and a run stops after a fixed number of steps.
<doc:ErrorsAndRefusals> describes each outcome and what a search can learn from
it; <doc:LimitsAndGuards> describes the limits.

## Code is data

A code block such as `( 2 .intMultiply )` is an item like any other. Met on
`.exec` it comes to rest on `.code`, where instructions can take it apart,
rebuild it, store it or compare it. Control instructions run code blocks:
`.codeDo` runs one, `.execIf` chooses between two, `.execDoTimes` repeats one,
and the iterators run one for each element of a collection. This is how Push
expresses conditionals, loops and subroutines without any syntax for them, and
it is also what lets a program build or change the code it is about to run. See
<doc:CodeAndControl>.

## Inputs and constants

A program meets the outside world through two kinds of instruction:

- **Inputs**, such as `.input0`, push the values bound for the current
  ``TrainingCase``. The same program runs once for each training case.
- **Constants**, such as `.int3` or `.string0`, push values that belong to the
  ``Individual``, so a search can tune them without changing the program's
  structure.

Inputs are also bound on the `.binding` stack at the start of every run, each
under its slot number, so a program can reach them by key as well as by name.
See <doc:InputsAndConstants>.

## Questions leave their arguments

Most instructions that *ask* something read their arguments and leave them in
place: `.intGT` compares the top two ints and pushes a bool, leaving both ints
where they were. Instructions that *transform* something consume it: `.intAdd`
takes two ints and gives back one. The instruction reference marks which
arguments an instruction only reads.

## Differences from other Push interpreters

If you know Push from Clojush, Propeller or PushGP, these are the differences
most likely to surprise you. <doc:DesignOfPlunge> gives the reasons for each.

- **Code blocks rest on `.code`.** Earlier interpreters unpacked a code block
  met on `.exec` and ran it. Here, code is data until an instruction runs it,
  and every control instruction takes its body from `.code`.
- **Queries don't consume.** Comparisons and other questions leave their
  arguments on the stack.
- **Failures are recorded.** Where other interpreters quietly do nothing, this
  one leaves an ``ErrorItem`` that says what went wrong, and a starved
  instruction becomes a function.
- **Loops, variables and functions are items.** Each has a stack of its own,
  and a program can inspect, change and store them.
- **Nothing is random.** An instruction's result depends only on its arguments
  and the state of the run, so the same program always gives the same result.
- **Results remember how they were made.** With provenance recording on, every
  item carries a *crux*: a short program that reproduces it. A search can use it
  to explain or reuse what a program computed. See <doc:Provenance>.
