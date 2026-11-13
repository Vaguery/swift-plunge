# How the Interpreter Runs

What happens between handing the library a program and getting results back:
loading, the step loop, how instructions find their arguments, and what ends a
run.

## One run, one interpreter

Each evaluation of an ``Individual`` on a ``TrainingCase`` gets a new
interpreter, used once and thrown away. Nothing carries over from one run to
the next, so the order in which runs happen can't matter, and any number can
happen at once. The ``Runner`` evaluates many pairings concurrently, each on
its own interpreter in its own task. See <doc:EvaluatingPrograms>.

The language itself, the table that says what every instruction does, is built
once and shared by every interpreter. It holds no state that a run can change,
which is what makes the concurrency safe.

## Loading

Before the first step, the interpreter:

1. starts with every stack empty and its step count at zero;
2. binds the training case's inputs and the individual's constants, so that
   `.input0`, `.int3` and the rest have values to push;
3. binds each input on the `.binding` stack under its slot number, so that
   input 3 is also reachable as key 3;
4. puts the program on `.exec`, its first item on top.

Instructions named in ``RunnerConfiguration/disabledBehaviors`` are left out of
the language for that run.

## The step loop

The interpreter then takes one step at a time, until `.exec` is empty or the
step count reaches ``InterpreterSettings/stepLimit``. Each step removes the top
item of `.exec` and acts on it:

- **a code block** goes onto `.code`, intact, as data;
- **an instruction** runs (one that is disabled leaves an *unknown instruction*
  error instead);
- **any other item** goes onto the stack for its type: an int onto `.int`, a
  binding onto `.binding`, a function onto `.function`.

After each step the recorders in ``RunnerConfiguration/recorders`` take their
readings (<doc:ObservingARun>), and the interpreter checks its guards.

Because `.exec` is a stack like the others, an instruction can change what the
program will do next simply by pushing onto it. That is all a control
instruction is: `.codeDo` pushes a code block's contents onto `.exec`, and a
loop pushes its body and then whatever will start the next pass.

## How an instruction runs

Every instruction declares what it needs, in order:

- items it **takes** from a stack, which are removed;
- items it **reads**, which are examined and left in place (the queries);
- items it **needs** in place, which it rearranges (the instructions that copy
  and reorder a stack);
- the **first item that fits**: the topmost item on a stack that passes a test,
  wherever it sits. Map, filter and reduce take the topmost function on
  `.function` that can do their job.

Then one of these happens:

- A stack is too short, and the instruction **starves**. It pushes a *missing
  arguments* error naming the stack that came up short, and puts itself on
  `.function` as a bare function whose holes are the arguments it wanted (see
  <doc:Functions>). Nothing else changes.
- A stack has items but none fits, and the instruction **misses**. It takes its
  other arguments and refuses with a ``ErrorKind/notFound`` error.
- The instruction has its arguments. It removes what it takes and computes.

A computation ends in one of three ways:

- **results**, each pushed onto the stack for its type;
- **a refusal**: the arguments were the wrong values for this instruction (a
  division by zero, a key with no binding). It pushes an ``ErrorItem`` that says
  why, and no result;
- **a continuation**: a control instruction pushes items back onto `.exec`,
  which is how code blocks run, loops repeat and conditionals choose.

Every error carries an ``ErrorKind``, so a search can count starvation,
refusals and size limits separately. A program can count its own errors but
can't remove them. <doc:ErrorsAndRefusals> covers all of this in detail.

## What ends a run

A run ends in one of three ways:

- **The program finishes.** `.exec` is empty.
- **The step limit is reached.** The run stops where it is, with no error. What
  it had computed so far is still on the stacks.
- **A guard stops it.** The runaway guard or the memory guard pushes an error
  and empties `.exec`.

Along the way, every result is checked against the size limits before it is
pushed, and one that is too large is replaced by a ``ErrorKind/sizeRefusal``
error. Some instructions (map, filter and reduce, `.vecFromIterator`,
`.codePushAllFunctions`) run code in a *sandbox*, a separate interpreter of
their own, and every step a sandbox takes counts against the run's own step
limit. <doc:LimitsAndGuards> describes each limit, its default, and where the
number came from.

## Recording provenance

With ``InterpreterSettings/recordsProvenance`` on, every item remembers how it
was made, and its *crux* is a short program that reproduces it on a new
interpreter. Recording is off by default, because it costs time and memory;
turn it on for the runs you want to explain. Turning it on never changes what a
program computes. See <doc:Provenance>.

## See Also

- <doc:ThePushLanguage>
- <doc:ErrorsAndRefusals>
- <doc:LimitsAndGuards>
- <doc:EvaluatingPrograms>
