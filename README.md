# The Plunge Push Interpreter

A Swift package containing the infrastructure to build and run an interpreter for
a new dialect (called Plunge) of the [Push](https://faculty.hampshire.edu/lspector/push.html) programming language for genetic programming (GP).

Push is a stack-based language designed to be written by evolution and related
metaheuristics. Any arbitrary sequence of Push tokens can be run,
however it was assembled. An instruction that can't do its job leaves an
error behind on a stack, and the program carries on.

This package includes the source for the interpreter and some related utilities only.
You can give it programs and inputs; it runs them,
concurrently and within strict memory and step limits, and reports the resulting values you
asked it to report. It contains no search; that will come in a macOS app.
Programs are built in Swift, not parsed from text.

The library should be runnable under macOS/iOS 26 or Linux, on desktop or server.

The Plunge dialect of Push is designed to add functionality in support of improved
flexibility and problem-solving, to rationalize Push's instruction and type coverage
somewhat, and to permit some useful new features.

## Features

- **A large, modern Push dialect**: 1,051 instructions over 14 typed stacks: bools,
  ints, doubles, chars, strings, four vector types, code, exec (the program being
  run), first-class loops (iterators), keyed variables (bindings) and functions. A
  fifteenth stack collects errors.
- **Every program runs.** Missing arguments, bad values and size limits produce
  error items, never runtime crashes. Integer arithmetic refuses rather than overflowing.
- **Bounded.** Steps, stack depths, collection sizes, code size and total memory
  are all limited, so every run ends.
- **Results explain themselves.** With provenance recording on, every item carries
  a *crux*: a short runnable Push program that reproduces that exact result
  when run in a new interpreter, given the same inputs and constants.
- **Concurrent.** A `Runner` evaluates many program and input pairings at once,
  each on its own interpreter.
- **Light.** Its only runtime dependency is `DequeModule` from
  [swift-collections](https://github.com/apple/swift-collections), and it builds
  on Linux.

## Quick start

```swift
import Plunge

let square = Individual(id: "square", program: program {
    PushInstruction.input0
    PushInstruction.input0
    PushInstruction.intMultiply
})
let cases = [TrainingCase(id: "three", inputs: [.input0: IntItem(3)])]

let runner = Runner(configuration: RunnerConfiguration(recorders: [
    RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly)
]))
await runner.register(individuals: [square])
await runner.register(trainingCases: cases)
let results = await runner.evaluate(pairings: [Pairing(individual: "square", trainingCase: "three")])
// results[0].traces["answer"] holds 9
```

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Vaguery/swift-plunge.git", from: "0.7.0"),
],
targets: [
    .target(name: "MySearch", dependencies: [
        .product(name: "Plunge", package: "swift-plunge"),
    ]),
]
```

It needs Swift 6.2 and, on Apple platforms, macOS or iOS 26.

## Documentation

The documentation is a DocC catalog in `Sources/Plunge/Plunge.docc/`:
getting started, an introduction to the language, how the interpreter runs,
articles on its features, the full API, and a reference page for every
instruction. To read it locally:

```sh
swift package --disable-sandbox preview-documentation --target Plunge
```

To work on the code, see [ARCHITECTURE.md](ARCHITECTURE.md) and
[CONTRIBUTING.md](CONTRIBUTING.md).

## Testing

```sh
swift test
```

## License

MIT. See [LICENSE](LICENSE).
