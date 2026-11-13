# Vocabulary

The words this documentation uses, each with one meaning.

## Overview

Push has its own vocabulary, Plunge adds to it, and several ordinary words
(*search*, *function*, *value*) could mean more than one thing here. This page
fixes one meaning for each. The other articles use these words as they are
defined here.

## The language and the library

- term Push: The family of stack-based languages designed for genetic
  programming, and the ideas they share. See <doc:ThePushLanguage>.
- term Plunge: The dialect of Push this library implements, and the name of the
  library's module. See <doc:DesignOfPlunge>.
- term Genetic programming: Searching for programs by generating, varying and
  selecting them. Two words, never hyphenated, and never abbreviated in this
  documentation.
- term Search: As a noun, the process outside this library that makes programs
  and decides which to keep. Genetic programming is one kind. The instructions
  that search a stack or a collection for an item are called *lookups* and
  *finds*, to keep the two apart.
- term Interpreter: The machine that runs one program once. It is internal to
  the library; you reach it through a ``Runner``.
- term Run: One program executed on one set of inputs, from loading to the last
  step.
- term Step: One item taken from `.exec` and acted on. Limits on running time
  are counted in steps.

## Programs and what they are made of

- term Item: Anything that can sit on a stack: a number, a string, a code block,
  an instruction, an error. Every item has a *value* and, when provenance is
  recorded, a *history*. Items have types of their own, such as ``IntItem`` and
  ``CodeItem``.
- term Value: What an item holds, named by its Swift type: the value of the item
  `17` is an `Int`. Two items are equal when their values are equal, however
  they were made.
- term Literal: An item written into a program as itself, such as `3` or
  `"hello"`, as opposed to a result that an instruction computed.
- term Instruction: A named operation, such as `.intAdd`. In a program it is an
  item like any other.
- term Behavior: What an instruction does when it runs. The word appears in the
  API (``RunnerConfiguration/disabledBehaviors``, ``BehaviorClass``) and is
  capitalized in the library's own notes; in these articles, "what the
  instruction does" means the same thing.
- term Program: A list of items, run from first to last.
- term Stack: Where items of one type live, named with a dot: `.int`, `.exec`.
  An instruction takes from the top and pushes onto the top. *Top first* is the
  order this documentation lists a stack's items in. Without the dot (`int`,
  `vecInt`), a stack's name stands for the kind of item an instruction takes or
  gives.
- term Code block: A list of items in parentheses, nested to any depth: a
  ``CodeItem``, on the `.code` stack. Never just "block", a word that means too
  many other things.
- term Vector: An ordered collection of bools, ints, doubles or strings, all of
  one type.
- term Collection: A vector, a string or a code block: anything with elements.
- term Root, point, gap: Three ways to address the inside of a code block. See
  <doc:CodeAndControl>.

## What an instruction does with its arguments

- term Take: Remove an argument from its stack. Also *consume*.
- term Read: Examine an argument and leave it where it is.
- term Query: An instruction that asks a question and reads its arguments
  without taking them, such as `.intGT`.
- term Written order: The order a program pushes an instruction's arguments,
  first to last. In `a b .intSubtract`, `a` comes first in written order and `b`
  is on top of the stack.
- term Clamp: Bring an out-of-range index or count to the nearest one in range,
  instead of treating it as an error.

## What can go wrong

These are defined fully in <doc:ErrorsAndRefusals>.

- term Starve: Find too few items on a stack. A starved instruction takes
  nothing, leaves a *missing arguments* error, and becomes a bare function.
- term Refuse: Find arguments and be unable to use them. A refusal leaves an
  error that says why, and no result.
- term Miss: The refusal of an instruction that looked for an item that fits
  and found none. A miss leaves a *not found* error.
- term Size refusal: The interpreter declining to push a result that is too
  large.
- term Guard: A check that stops a whole run early: the runaway guard and the
  memory guard. See <doc:LimitsAndGuards>.
- term Error: An item on the `.error` stack, an ``ErrorItem``. An error is a
  record, not an exception: the program continues.
- term Print: Move an item onto the `.print` stack. What a program prints is a
  sequence of items, not text, read by a caller with a recorder.
- term Channel: A stack the program writes to and never reads: `.error` and
  `.print`. Channels have no size limits and no stack instructions of their own.

## Running programs

- term Individual: A program with an identifier and, optionally, values for its
  constants: one candidate a search wants evaluated.
- term Training case: One set of inputs, with an identifier.
- term Pairing: A request to run one individual on one training case.
- term Runner: The object that holds individuals and training cases and
  evaluates pairings. See <doc:EvaluatingPrograms>.
- term Input: A value a training case supplies, pushed by an instruction such
  as `.input0`.
- term Constant: A value an individual supplies, pushed by an instruction such
  as `.int3`.
- term Slot: One numbered place for an input or a constant: `.input3` is input
  slot 3, and `.int3` is int constant slot 3.
- term Recorder: A named request to observe one thing during a run, such as the
  top of a stack. See <doc:ObservingARun>.
- term Trace: What one recorder collected in one run.
- term Sandbox: A separate interpreter that an instruction starts to run some
  code apart from the program's own stacks.

## Loops, variables and functions

- term Iterator: A loop that is an item on the `.iterator` stack. It has a
  *source*, a *cursor*, an optional *body*, and may *emit* each element. See
  <doc:Iterators>.
- term Binding: A pair of an int *key* and an item, on the `.binding` stack.
- term Variable: All the bindings that share one key. The topmost is the
  variable's current value, and it *shadows* the ones below. See
  <doc:Variables>.
- term Fresh key: A key that no binding in this run has used yet.
- term Function: An item on the `.function` stack: a body with *holes*. This
  documentation never uses the word for a Swift function without saying so.
  See <doc:Functions>.
- term Hole: A typed gap in a function, filled by an argument when the function
  is applied.
- term Bare function: A single instruction on `.function`, put there because it
  starved. Its holes are the arguments it wanted.
- term Derived function: A function that `.codePushAllFunctions` made from a
  code block.
- term Lookup: An instruction that searches a stack for the first item matching
  a *probe*.
- term Find: An instruction that searches inside one collection for the first
  element matching a probe.
- term Probe: The item a lookup or a find compares against. See
  <doc:SearchingTheStacks>.

## Provenance

- term Provenance: The record of how an item was made. Also its *history*.
- term Crux: An item's history written out as a program. Run on a fresh
  interpreter with the same inputs and constants, it produces that item and
  nothing else. See <doc:Provenance>.
- term Stand-in: A marked literal in a crux, in place of a value whose history
  can't be replayed or was too large to keep.
- term Weight: The size of an item's content: 1 for a number, the number of
  elements for a vector, and so on. Size limits are stated in weight.

## Describing instructions

- term Summary: The one sentence that says what an instruction does, shown in
  the <doc:InstructionReference>.
- term Signature: What an instruction takes, reads and gives, as an
  ``InstructionSignature``.
- term Tag: A label on a set of instructions. Tags overlap, and anyone can add
  their own. See <doc:TaggingInstructions>.
- term Role: One of five groups that divide the language for drawing random
  test programs. Every instruction has exactly one. See ``InstructionRole``.
