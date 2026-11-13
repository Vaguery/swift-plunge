# Limits and Guards

Why every run is bounded, what each limit bounds, where its number came from,
and what happens when a program reaches it.

## Overview

A search writes programs that loop forever, double a string until memory runs
out, and nest code blocks a million deep. None of that is a mistake on the
search's part; it is what unguided variation produces. So the interpreter bounds
everything that can grow: the steps a run takes, the depth of every stack, the
size of every item, and the total held at once. Every run ends, in bounded
memory, whatever the program.

The limits are a compromise for throughput, not part of the language's meaning.
They exist so that a whole population can be evaluated in predictable time and
space. All of them are properties of ``InterpreterSettings``, which you pass in
a ``RunnerConfiguration``:

```swift
var settings = InterpreterSettings()
settings.stepLimit = 2_000
settings.maxVectorLength = 200
let configuration = RunnerConfiguration(settings: settings)
```

## The limits

| Setting | Default | Bounds | The number is |
|---|---|---|---|
| ``InterpreterSettings/stepLimit`` | 10,000 | steps in one run | chosen |
| ``InterpreterSettings/maxStackDepth`` | 10,000 | items on any one stack | inherited |
| ``InterpreterSettings/maxStringLength`` | 1,000 | characters in a string | inherited |
| ``InterpreterSettings/maxVectorLength`` | 1,000 | elements in a vector | inherited |
| ``InterpreterSettings/maxCodePoints`` | 1,000 | items in a code block, at every level | inherited |
| ``InterpreterSettings/maxCodeDepth`` | 1,000 | how deeply code blocks and iterators nest | inherited |
| ``InterpreterSettings/maxItemWeight`` | 100,000 | the total content of one item | chosen |
| ``InterpreterSettings/maxLiveWeight`` | 50,000,000 | the total content of all stacks together | chosen |
| ``InterpreterSettings/maxCallWeight`` | 10,000 | the history one item may keep | chosen |
| ``InterpreterSettings/maxCallDepth`` | 1,000 | how deeply one item's history nests | derived |

The last column says how free you are to change the number:

- **Inherited** numbers follow [Propeller's
  limits](https://github.com/lspector/propeller/blob/master/src/propeller/push/limits.cljc),
  loosely, so that runs are comparable with other Push systems. They were not
  chosen on their own merits. Change them freely; the cost is that
  comparability.
- **Chosen** numbers are this library's own policy. Change them at will.
- **Derived** numbers follow from something else, and changing them without
  changing that is unsafe. The one here, ``InterpreterSettings/maxCallDepth``,
  follows from the size of the stack a concurrency thread gets: walking or
  freeing a history costs stack frames for every level. Raise it only if your
  runs are on threads with larger stacks.

One relation between the limits is not enforced: the step limit must be larger
than the largest collection, or a program can hold a vector it can't walk to the
end. With the defaults, a 1,000-element vector fits easily in 10,000 steps.

*Weight* is the measure of an item's content: 1 for a bool, a number or a char,
the number of bytes of UTF-8 for a string, the number of elements for a vector
of numbers, the total length of the strings for a vector of strings, and the sum
of the contents for a code block. ``InterpreterSettings/maxItemWeight`` catches
what the other limits can't see one at a time, such as a vector of a thousand
strings of a thousand characters each.

Numbers have no size limit of their own, and need none: integer arithmetic
refuses instead of overflowing, and no instruction leaves an infinity or a
not-a-number on `.double`.

## Reaching a size limit

Every result is checked before it is pushed. One that is over a limit, or that
would make its stack too deep, is dropped, and a
``ErrorKind/sizeRefusal`` error is pushed in its place. The run continues.
Instructions that build something large from small arguments (a range, a
repeat) check the size first and refuse before building anything.

History is treated differently. A history over
``InterpreterSettings/maxCallWeight`` or ``InterpreterSettings/maxCallDepth`` is
not refused but *elided*: the item keeps its value, and its history is replaced
by a stand-in that says so. That costs the explanation and never the value,
which is why those two limits can be strict. See <doc:Provenance>.

## Reaching the step limit

A run that reaches ``InterpreterSettings/stepLimit`` stops where it is. Nothing
is pushed onto `.error`, and whatever the program had computed so far is still
on the stacks, so a recorder still reports an answer. To tell a run that
finished from one that was cut short, record the step count or whether `.exec`
was emptied:

```swift
RecorderSpec("steps", observing: .counter, keeping: .finalOnly)
RecorderSpec("finished", observing: .isEmpty(.exec), keeping: .finalOnly)
```

The default of 10,000 was raised from the 1,000 that other Push systems use.
Measured on random programs, the share of runs cut short fell from 12.7% to
7.8%. Functions spend from the same budget (below), and 1,000 steps left them
too little.

## Sandboxes

Some instructions run code apart from the program's own stacks, in a *sandbox*:
map, filter, reduce and their relatives for each application of a function,
`.vecFromIterator` for an iterator's body, and `.codePushAllFunctions` for the
code block it converts. A sandbox is not a way around the limits:

- every step a sandbox takes counts against the run's own step limit;
- sandboxes nest at most 50 deep, and one that would start deeper is refused
  with a ``ErrorKind/sizeRefusal`` error, because each level uses the thread's
  stack.

## The guards

The size limits each bound one thing. Two guards watch the whole run, and stop
it early by pushing an error of kind ``ErrorKind/guardStop`` and emptying
`.exec`:

- The **runaway guard** looks for the signature of a loop that will never do
  anything else: a stack that is deep and piling up repeats, a short cycle or a
  steady count, while a looping instruction is still pending on `.exec`. Both
  signs must be present, so a large computation that is going to finish isn't
  stopped. Its error begins `RUNAWAY:`. Turn it off with
  ``InterpreterSettings/runawayGuardEnabled`` to let such loops run until the
  ordinary limits stop them.
- The **memory guard** stops a run when the weight of everything on all its
  stacks passes ``InterpreterSettings/maxLiveWeight``. Each of the other limits
  is local, and their product is far more memory than a machine has; this is
  the one global bound. Its error begins `MEMORY:`. Setting the limit to
  `Int.max` turns the guard off.

Without the guards such a program would still be stopped, by the size limits
and the step limit, but only after a slow crawl toward them that costs time and
memory on every run. With them, the search gets a prompt result that says what
went wrong.

## Replaying a crux

Running an item's crux (<doc:Provenance>) is a different job from evaluating a
population: one program, run once, to rebuild one value. It can afford far
more room, and sometimes needs it, because a crux may have to push as one item
something the original run only ever held inside a loop.
``InterpreterSettings/reconstructing``
gives a copy of your settings with the size limits relaxed for that job.

It leaves three things alone on purpose. The history limits stay, so the replay
elides exactly what the original did. The depth limits stay, because they
protect the thread's stack. And the step limit stays, because only you know how
long the crux is: ``CruxCompression/replaySteps(_:)`` estimates it.

## See Also

- <doc:HowTheInterpreterRuns>
- <doc:ErrorsAndRefusals>
- ``InterpreterSettings``
