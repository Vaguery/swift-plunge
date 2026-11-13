# Evaluating Programs

Run many programs on many inputs: with a runner that remembers them, with a
single self-contained request, or as a stream of results.

## Overview

Evaluating is the one thing the library does for a search, and it comes in
three forms that share everything but how the work is handed over:

| | Holds programs and cases | Results arrive |
|---|---|---|
| ``Runner/evaluate(pairings:)`` | in the ``Runner``, registered beforehand | all together, in the order asked |
| ``evaluate(request:)`` | in the request itself | all together, in the order asked |
| ``evaluate(streaming:)`` | in the request itself | one at a time, as each finishes |

In every form, each ``Pairing`` is run on a new interpreter of its own, so no
run can affect another, and many run at once.

## Pairings

A ``Pairing`` names one ``Individual`` and one ``TrainingCase`` by their
identifiers. The library never decides which pairings to run, and never runs
every individual on every case unless you ask for exactly that. Which programs
meet which cases is a decision the search makes: methods such as lexicase
selection and down-sampling depend on evaluating deliberately chosen, often
sparse, subsets.

To run everything on everything, say so:

```swift
let pairings = individuals.flatMap { individual in
    trainingCases.map { Pairing(individual: individual.id, trainingCase: $0.id) }
}
```

## With a runner

A ``Runner`` is an actor that keeps a configuration, a pool of individuals and
a pool of training cases. Register what you have, then evaluate pairings as
often as you like:

```swift
let runner = Runner(configuration: configuration)
await runner.register(trainingCases: trainingCases)
await runner.register(individuals: individuals)
let results = await runner.evaluate(pairings: pairings)
```

- Registering an identifier a second time replaces what was there.
- Results come back in the order of the pairings, one ``CaseResult`` each.
- A pairing that names an identifier the runner doesn't have gives a result
  with ``CaseResult/unresolved`` set, and the others are unaffected. One bad
  reference doesn't fail a batch.
- ``Runner/configure(_:)`` replaces the configuration for later evaluations.

A runner suits a search that evaluates the same training cases over and over
and wants to send them once. It keeps everything registered with it and has no
call to remove an individual, so over a long search either use a new runner for
each generation or use a request.

## With a request

An ``EvaluationRequest`` carries everything one batch needs: the individuals,
the training cases, the pairings and the configuration. ``evaluate(request:)``
runs it and remembers nothing:

```swift
let request = EvaluationRequest(
    individuals: individuals,
    trainingCases: trainingCases,
    pairings: pairings,
    configuration: configuration)
let results = await evaluate(request: request)
```

Every type involved is `Codable`, so a request can be encoded, sent to another
process or another machine, and evaluated there:

```swift
let data = try JSONEncoder().encode(request)
// … elsewhere …
let received = try JSONDecoder().decode(EvaluationRequest.self, from: data)
let answers = await evaluate(request: received)
let reply = try JSONEncoder().encode(answers)
```

The library has no network code of its own. It provides the request, the
function and the result, and leaves the transport to you.

## As a stream

``evaluate(streaming:)`` takes the same request and returns an `AsyncStream`
that yields each result as soon as its run finishes:

```swift
for await result in evaluate(streaming: request) {
    show(result)
}
```

Results arrive in the order they finish, not the order they were asked for;
each one carries its ``CaseResult/individual`` and ``CaseResult/trainingCase``
so you can tell which it is. Use a stream to show progress, or to stop early:
when you stop reading the stream, the runs still in progress are canceled.

## Concurrency

Every pairing runs in a task of its own. The instructions' definitions are
built once and shared, and hold no state that a run can change; each
interpreter is used by one task and then discarded. Nothing that can change is
shared between runs, so no locking is involved.

``RunnerConfiguration/maxConcurrentEvaluations`` caps how many runs are in
progress at once. The default is one for each processor core. Lower it to
bound peak memory, since every run in progress holds its own stacks, or to
keep a batch from claiming every core.

Canceling the task that is waiting on an evaluation stops the runs in progress
at their next check, which comes every few hundred steps. A run stopped that
way reports whatever it had when it stopped, so discard the results of an
evaluation you canceled.

## The same answer every time

Nothing in the language is random, and no run can see another. So the same
program, inputs, constants and settings give the same result on every run and
in any order, however many run at once. Only ``CaseResult/duration`` varies.
The one caveat is across platforms: the last digit of some floating-point
functions can differ between one system's math library and another's.

## Choosing the instructions

``RunnerConfiguration/disabledBehaviors`` names instructions to leave out of
the language for an evaluation. A program that contains one still runs: the
instruction leaves an *unknown instruction* error and does nothing else. Most
searches should leave this empty and run with the whole language; see
<doc:TaggingInstructions> for when to exclude and how to choose what.

## See Also

- <doc:ObservingARun>
- <doc:InputsAndConstants>
- <doc:LimitsAndGuards>
- ``Runner``
- ``RunnerConfiguration``
- ``EvaluationRequest``
