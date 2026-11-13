# Getting Started

Add the package, write a small program, and run it against some inputs.

## Add the package

Plunge is a Swift package. Add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Vaguery/swift-plunge.git", from: "0.8.0"),
],
targets: [
    .target(name: "MySearch", dependencies: [
        .product(name: "Plunge", package: "swift-plunge"),
    ]),
]
```

The library needs Swift 6.2. On Apple platforms it needs macOS 26 or iOS 26,
and it also builds on Linux. Its one runtime dependency is `DequeModule` from
[swift-collections](https://github.com/apple/swift-collections).

## Run a program

You hand the library *programs* and *inputs*, and it hands back what you asked
it to observe. Four types carry that conversation:

- ``Individual``: a program to run, with an identifier (and, optionally, the
  values of its constants).
- ``TrainingCase``: the inputs for one run, with an identifier.
- ``Pairing``: "run this individual on that training case".
- ``RecorderSpec``: what to observe while it runs, such as the top of a stack.

A ``Runner`` holds individuals and training cases, evaluates pairings of them
concurrently, and returns one ``CaseResult`` for each pairing.

This program squares its input: it pushes the input twice and multiplies.

```swift
import Plunge

let square = Individual(id: "square", program: program {
    PushInstruction.input0
    PushInstruction.input0
    PushInstruction.intMultiply
})
let cases = [
    TrainingCase(id: "three", inputs: [.input0: IntItem(3)]),
    TrainingCase(id: "minus five", inputs: [.input0: IntItem(-5)]),
]

let runner = Runner(configuration: RunnerConfiguration(recorders: [
    RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly)
]))
await runner.register(individuals: [square])
await runner.register(trainingCases: cases)

let results = await runner.evaluate(pairings: cases.map {
    Pairing(individual: square.id, trainingCase: $0.id)
})
for result in results {
    if case .items(let answers)? = result.traces["answer"], let answer = answers.last ?? nil {
        print(result.trainingCase, answer.item.pretty())   // three 9, minus five 25
    }
}
```

## What just happened

**The program.** `program { … }` is a result builder (``PushProgram``) that
turns instructions and Swift literals into items. A program is nothing more
than an array of items, and <doc:WritingPrograms> shows the other ways to make
one.

**The inputs.** Each training case binds a value to `.input0`. The same program
ran twice, once for each case, on a new interpreter each time.

**The run.** On the first case the interpreter took the program's items one at
a time. Each `.input0` pushed 3 onto the `.int` stack, and `.intMultiply` took
both and pushed 9. <doc:ThePushLanguage> explains the model, and
<doc:HowTheInterpreterRuns> the machinery.

**The recorder.** A run reports only what it was asked to. The recorder named
`answer` watched the top of the `.int` stack, and `.finalOnly` kept its last
reading. A recorder can also keep a reading for every step, for tracing. See
<doc:ObservingARun>.

**The result.** Each ``CaseResult`` holds one trace for each recorder, under
the recorder's name. A trace of items is an array of optional readings, which
is why the code asks for `answers.last ?? nil`: the array may be empty, and a
reading is `nil` when the stack was.

## When a program goes wrong

Change the program to multiply before it has pushed anything:

```swift
program {
    PushInstruction.intMultiply
    PushInstruction.input0
}
```

Nothing crashes and nothing throws. `.intMultiply` finds no ints, leaves an
error on the `.error` stack, and the run goes on to push the input. The answer
recorded is the input itself. This is the central idea of Push: every program
runs. To see what went wrong, add a recorder for the errors:

```swift
RecorderSpec("errors", observing: .count(.error), keeping: .finalOnly)
```

<doc:ErrorsAndRefusals> describes everything that can land there.

## Where to go next

- <doc:ThePushLanguage> explains what a Push program is and how it computes.
- <doc:InputsAndConstants>, <doc:EvaluatingPrograms> and <doc:ObservingARun>
  cover the rest of the conversation between a search and the library.
- <doc:LimitsAndGuards> describes what keeps every run finite.
- <doc:InstructionReference> lists every instruction.
