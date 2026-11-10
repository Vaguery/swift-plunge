# Getting Started

Add the package, write a small Push program, and run it against some inputs.

## Add the package

Plunge is a Swift package. Add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Vaguery/swift-plunge.git", branch: "main"),
],
targets: [
    .target(name: "MySearch", dependencies: [
        .product(name: "Plunge", package: "swift-plunge"),
    ]),
]
```

The library needs Swift 6.2 and macOS or iOS 26, and it builds on Linux. Its one
runtime dependency is `DequeModule` from
[swift-collections](https://github.com/apple/swift-collections).

## Run a program

You hand the library *programs* and *inputs*, and it hands back what you asked to
observe. Four types carry that conversation:

- ``Individual``: a program to run, with an identifier (and, optionally, the
  values of its constants).
- ``TrainingCase``: the inputs for one run, with an identifier.
- ``Pairing``: "run this individual on that training case".
- ``RecorderSpec``: what to observe while it runs, such as the top of a stack.

A ``Runner`` holds individuals and training cases, evaluates pairings of them
concurrently, and returns one ``CaseResult`` per pairing.

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

`program { … }` is a result builder (``PushProgram``) that turns instructions and
Swift literals into Push items. The recorder named `answer` watches the top of the
int stack and keeps only its final value; a recorder can also keep every step,
for tracing.

## Where to go next

- <doc:ThePushLanguage> explains what a Push program is and how it computes.
- <doc:HowTheInterpreterRuns> describes the interpreter's loop, its limits, and
  what happens when a program misbehaves.
- <doc:InstructionReference> lists every instruction.
