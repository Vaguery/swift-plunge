# How the Interpreter Runs

What happens between handing the library a program and getting results back:
loading, the step loop, how instructions find their arguments, and the limits
that keep every run finite.

## One run, one interpreter

Each evaluation of an ``Individual`` on a ``TrainingCase`` gets a fresh
interpreter, used once and thrown away. The ``Runner`` evaluates many pairings at
once, each on its own interpreter in its own task, and returns the results in the
order the pairings were given. ``RunnerConfiguration/maxConcurrentEvaluations``
caps how many run at a time. For a one-shot batch, ``evaluate(request:)`` does the
same without a `Runner`, and ``evaluate(streaming:)`` hands results back as they
finish.

The language itself, the table of every instruction's behavior, is built once and
shared by every interpreter. It holds no per-run state, which is what makes the
concurrency safe.

## Loading

Before the first step, the interpreter:

1. empties every stack and resets its step counter;
2. binds the training case's inputs (`input0`, `input1`, …) and the individual's
   constants (`int0`, `string3`, …), so those instructions have values to push;
3. binds each input on the `.binding` stack under its slot number, so input 3 is
   also reachable as key 3;
4. puts the program on `.exec`, its first item on top.

Instructions that ``RunnerConfiguration/disabledBehaviors`` names are left out of
the language for that run.

## The step loop

The interpreter then takes one step at a time, until `.exec` is empty or the
step count reaches ``InterpreterSettings/stepLimit``. Each step removes the top
item of `.exec` and:

- **a block** goes onto `.code`, intact, as data;
- **an instruction** runs (an instruction that is disabled or has no behavior
  leaves an "unknown instruction" error instead);
- **any other literal** goes onto the stack for its type.

After each step the recorders in ``RunnerConfiguration/recorders`` observe the
state they were asked about, and the interpreter checks its guards (below).

## How an instruction runs

Every instruction declares what it needs, in order:

- items it **takes** from a stack, which are removed;
- items it **reads**, which are examined and left in place (the queries);
- items it **needs** in place, which it rearranges (the stack instructions).

If any stack is too short, the instruction is **starved**: it changes nothing
and pushes a *missing arguments* error naming the stack that came up short.
Otherwise it removes what it takes and computes. The outcome is one of:

- **results**, each pushed onto the stack for its type;
- **a refusal**: the arguments were the wrong values for this instruction (a
  division by zero, a key with no binding). It pushes an ``ErrorItem`` that says
  why, and no result;
- **a continuation**: control instructions push items back onto `.exec`, which
  is how blocks run, loops repeat and conditionals choose.

Every error carries an ``ErrorKind``, so a search can count starvation, refusals
and size limits separately. A program can measure `.error` (`errorStackDepth`)
and count some kinds of error on it (`errorMissingArgCount`,
`errorMissingInputCount`, `errorMissingConstantCount`), but no instruction can pop
or reorder it: a program can't hide its own failures.

## Limits

Every push is checked against the size limits in ``InterpreterSettings``, and a
push that would break one is refused with a ``ErrorKind/sizeRefusal`` error:

| Setting | Bounds |
|---|---|
| ``InterpreterSettings/maxStackDepth`` | the items on any one stack |
| ``InterpreterSettings/maxStringLength`` | characters in a string |
| ``InterpreterSettings/maxVectorLength`` | elements in a vector |
| ``InterpreterSettings/maxCodePoints`` | the nodes in a block |
| ``InterpreterSettings/maxCodeDepth`` | how deeply blocks nest |
| ``InterpreterSettings/maxItemWeight`` | the total content of one item |

Numbers have no size limit of their own: integer arithmetic refuses rather than
overflowing, and no instruction leaves a NaN or an infinity on `.double`.

Two guards stop a run early, leaving an error marked `RUNAWAY:` or `MEMORY:` and
emptying `.exec`:

- the **runaway guard** (``InterpreterSettings/runawayGuardEnabled``) watches for
  a stack piling up repeats while a loop is still pending on `.exec`;
- the **memory guard** stops a run whose items, summed across all stacks, outweigh
  ``InterpreterSettings/maxLiveWeight``.

Every run therefore ends: by finishing its program, by reaching the step limit, or
by a guard.

## Recording provenance

With ``InterpreterSettings/recordsProvenance`` on, every item remembers how it was
made, and its *crux* is a short program that reproduces it on a fresh interpreter.
Recording is off by default, because it costs time and memory; turn it on for the
runs you want to explain. Turning it on never changes what a program computes.
``RunnerConfiguration/cruxInputTokens`` turns it on for a run and reports, per
recorder, whether each observed result depends on the given inputs
(``CaseResult/cruxMentionsInput``).
