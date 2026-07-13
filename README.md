# PushInterpreter

A self-contained interpreter for the [Push](https://faculty.hampshire.edu/lspector/push.html)
programming language, written in Swift.

This independednt package can produce and exercise an interpreter instance,
suitable for the mdoern version of the Push language defined here,
and is intended to be semi-independent from any particular search frameworks.

## Design

- **Dependency-light** — only `DequeModule` from
  [swift-collections](https://github.com/apple/swift-collections).
- **Robustly tested and guarded** — Genetic programming languages, because they
  juxtapose arbitrary inputs and outputs so diversely, tend to discover runtime
  errors of arithmetic and data structure manipulation. This version has been
  carefully corralled to avoid traps as much as possible.
- **Concurrency-ready** — the language table is built once and shared; `Behavior`s
  hold no per-invocation mutable state, and the core is `nonisolated` + `Sendable`
  where it must be, so one shared language can drive many interpreters
  concurrently (each interpreter is its own single-task mutable island).
- **Linux-buildable** — pure logic plus stdlib/`DequeModule`; no platform-only APIs.
- comprehensive unit testing, as well as some brute-force fuzz testing to ensure
  edge cases of the language don't cause problems as the language develops and expands

## Usage

Add the package as a dependency, then:

```swift
import PushInterpreter
```

## Testing

```sh
swift test
```
