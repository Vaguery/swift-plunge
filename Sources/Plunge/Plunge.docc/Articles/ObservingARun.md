# Observing a Run

Say what you want to know about a run before it starts, and read it from the
result afterward.

## Overview

A run reports nothing unless it is asked. The interpreter that ran a program is
thrown away when the run ends, so there are no stacks to inspect afterward.
Instead you describe, ahead of time, what to watch: each description is a
*recorder*, and what a recorder collects is a *trace*.

This design is what lets evaluation happen somewhere else. A ``RecorderSpec``
is a plain value with no closure in it, so it can be encoded and sent to
another process along with the programs, and the answer that comes back holds
exactly what was asked for and nothing more.

## Recorders

A ``RecorderSpec`` has a name, a target and a policy. Recorders go in the
``RunnerConfiguration``, and apply to every evaluation made with it:

```swift
let configuration = RunnerConfiguration(recorders: [
    RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly),
    RecorderSpec("errors", observing: .count(.error), keeping: .finalOnly),
    RecorderSpec("steps", observing: .counter, keeping: .finalOnly),
    RecorderSpec("finished", observing: .isEmpty(.exec), keeping: .finalOnly),
])
```

The **target** (``RecorderTarget``) says what to look at:

| Target | Observes | Trace |
|---|---|---|
| `.top(stack)` | the top item of a stack | items |
| `.second(stack)` | the item below the top | items |
| `.nth(stack, depth:)` | the item at a depth, where 0 is the top | items |
| `.count(stack)` | how many items a stack holds | ints |
| `.isEmpty(stack)` | whether a stack is empty | bools |
| `.stack(stack)` | every item on a stack, top first | item lists |
| `.counter` | how many steps the run has taken | ints |

Copying a whole stack after every step is costly, so use `.stack` with
`.finalOnly` unless you want its history.

The **policy** (``RecordingPolicy``) says how much to keep:

- `.everyStep`, the default, keeps one reading after each step: the whole
  history of that target, for tracing and debugging.
- `.finalOnly` keeps only the reading after the last step: the state the run
  ended in. Use it for scoring.

The difference matters at scale. An every-step recorder on a 10,000-step run
holds 10,000 readings, and with provenance recording on, each item among them
holds its own history. Kept for every run of a whole population, those traces
are the dominant cost of an evaluation. Record every step only for the runs you
mean to look at.

## Reading a trace

Each ``CaseResult`` has a dictionary of traces, keyed by recorder name. A
``RecordedTrace`` is an enumeration with one case for each kind of reading, and
each case holds an array of optional readings, one for each step kept:

```swift
let result = await runner.evaluate(pairings: [pairing])[0]

if case .items(let readings)? = result.traces["answer"],
   let answer = readings.last ?? nil {
    print(answer.item.pretty())
}
if case .ints(let counts)? = result.traces["errors"], let errors = counts.last ?? nil {
    print(errors)
}
```

A reading is `nil` when there was nothing to observe: the top of an empty
stack, for example. That is why the code above writes `readings.last ?? nil`:
`last` is optional because the array may be empty, and the reading inside it is
optional too.

An item reading is an ``AnyItem``, a wrapper that makes any item `Codable`. Its
``AnyItem/item`` is the item itself. Cast it to a concrete type to read its
value:

```swift
if let int = answer.item as? IntItem { print(int.value + 1) }
```

Two details are worth knowing:

- With `.everyStep`, the reading at index *i* is the state after step *i* + 1.
  A program of three items that all run gives three readings.
- A run that takes no steps (an empty program) records nothing at all, so its
  traces are empty arrays even with `.finalOnly`.

## What to record

- **The answer.** Usually the top of one stack at the end. A problem with
  several outputs can use `.top` on several stacks, or `.nth` for several
  outputs on one stack.
- **Printed output.** Printing moves an item onto the `.print` stack, so what
  a program printed is a sequence of items, not text. `.stack(.print)` records
  all of them, top first, which is the latest first; reverse the list for the
  order they were printed. `.top(.print)` is the last item printed and
  `.count(.print)` how many there were. Each type has a print instruction
  (`.intPrint`, `.stringPrint`, `.codePrint` and the rest). No instruction can
  read `.print`, so a program can't change what it has printed.
- **Errors.** `.count(.error)` for how many, `.top(.error)` for the last one.
  See <doc:ErrorsAndRefusals>.
- **Whether the run finished.** A run stopped by the step limit leaves items
  on `.exec`, so `.isEmpty(.exec)` is false, and `.counter` equals the limit.
  See <doc:LimitsAndGuards>.

## The rest of a result

Besides its traces, a ``CaseResult`` carries:

- ``CaseResult/individual`` and ``CaseResult/trainingCase``, the identifiers of
  the pairing it answers;
- ``CaseResult/unresolved``, true when the pairing named an individual or a
  training case the runner didn't have, in which case nothing ran;
- ``CaseResult/duration``, the time the run took, for finding the programs
  that are slow;
- ``CaseResult/cruxMentionsInput``, which says for each item recorder whether
  the final item depended on the inputs, when
  ``RunnerConfiguration/cruxInputTokens`` asks for it. See <doc:Provenance>.

## Histories don't travel by default

In memory, a recorded item keeps its history, and you can ask it for its
``Item/crux()``. Encoded, a trace keeps values only: ``AnyItem`` encodes an
item's type and value, and not its history. To save or send items with their
histories, put them in an ``ItemArchive``. See <doc:Provenance>.

## See Also

- <doc:EvaluatingPrograms>
- ``RecorderSpec``
- ``RecorderTarget``
- ``RecordingPolicy``
- ``RecordedTrace``
- ``CaseResult``
