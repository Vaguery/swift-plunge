# PushInterpreter

An interpreter for the [Push](https://faculty.hampshire.edu/lspector/push.html)
programming language, written in Swift, for genetic programming.

Push is a stack-based language designed to be written by evolution: every program
runs, however it was assembled. An instruction that can't do its job leaves an
error behind and the program carries on. This package is the interpreter alone,
independent of any search. You give it programs and inputs; it runs them,
concurrently and within strict limits, and reports what you asked to observe.

## Features

- **A large, modern Push dialect**: 845 instructions over 13 typed stacks: bools,
  ints, doubles, chars, strings, four vector types, code, first-class loops
  (iterators) and keyed variables (bindings).
- **Every program runs.** Missing arguments, bad values and size limits produce
  error items, never crashes. Integer arithmetic refuses rather than overflowing.
- **Bounded.** Steps, stack depths, collection sizes, code size and total memory
  are all limited, so every run ends.
- **Results explain themselves.** With provenance recording on, every item carries
  a *crux*: a short program that reproduces it.
- **Concurrent.** A `Runner` evaluates many program and input pairings at once,
  each on its own interpreter.
- **Light.** Its only dependency is `DequeModule` from
  [swift-collections](https://github.com/apple/swift-collections), and it builds
  on Linux.

## Quick start

```swift
import PushInterpreter

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
.package(url: "https://github.com/Vaguery/swift-push-interpreter.git", branch: "main")
```

It needs Swift 6.2 and, on Apple platforms, macOS or iOS 26.

## Documentation

The documentation is a DocC catalog in `Sources/PushInterpreter/PushInterpreter.docc/`:
getting started, an introduction to the language, how the interpreter runs,
articles on its features, the full API, and a reference page for every
instruction. To read it locally:

```sh
swift package --disable-sandbox preview-documentation --target PushInterpreter
```

To work on the code, see [ARCHITECTURE.md](ARCHITECTURE.md) and
[CONTRIBUTING.md](CONTRIBUTING.md).

## Testing

```sh
swift test
```

## License

MIT. See [LICENSE](LICENSE).
