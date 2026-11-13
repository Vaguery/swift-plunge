# Instruction Reference

Every instruction in the language, grouped by the stack it works on.

## Overview

An instruction is named for the stack it belongs to and what it does:
`.intAdd`, `.stringReverse`, `.codeDo`. Each page below lists one stack's
instructions in a table:

- **What it does**, in a sentence. Where the order of arguments matters, the
  sentence shows the instruction as a program writes it: `a b .intSubtract` gives
  a − b, because `b` was pushed last and is on top.
- **Takes**, the arguments in the order the instruction claims them, top item
  first. An argument marked *(read)* is examined and left in place; *the topmost
  fitting* one is the first item down its stack that the instruction can use.
- **Gives**, the stacks its results go to. *May refuse* means some arguments are
  the wrong values for it; then it pushes an error instead of a result.

Some entries under **Gives** are not stacks:

- *the rest of the program*: a control instruction, whose effect is to put
  items on `.exec` to run next;
- *rearranged*: an instruction that copies, deletes or reorders the items of a
  stack and makes no new value;
- *the printout*: text appended to the run's printed output;
- *the input's type*: an input goes to whichever stack suits the value bound
  to it;
- alternatives joined by *or*: which results there are depends on the
  arguments' values, and a dash means there may be none.

Every instruction that needs arguments can also *starve*, when a stack it needs
holds too few items. A starved instruction leaves a *missing arguments* error
and puts itself on `.function` as a bare function; nothing else changes. The
tables don't repeat this for each instruction. <doc:ErrorsAndRefusals> describes
starving and refusing in full.

The tables are generated from the language itself, so they always match the
version of the library they ship with. Your code can ask the same questions
through the ``Runner``: ``Runner/summary(of:)``, ``Runner/signature(of:)`` and
``Runner/definedInstructions``. See <doc:WritingPrograms>.

## Topics

### Values

- <doc:BoolInstructions>
- <doc:IntInstructions>
- <doc:DoubleInstructions>
- <doc:CharInstructions>
- <doc:StringInstructions>

### Vectors

- <doc:VecBoolInstructions>
- <doc:VecIntInstructions>
- <doc:VecDoubleInstructions>
- <doc:VecStringInstructions>

### Code, control and state

- <doc:CodeInstructions>
- <doc:ExecInstructions>
- <doc:IteratorInstructions>
- <doc:BindingInstructions>
- <doc:FunctionInstructions>
- <doc:EnvironmentInstructions>

### Every stack

- <doc:StackInstructions>
