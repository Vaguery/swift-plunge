# PushInterpreter

A self-contained interpreter for the [Push](https://faculty.hampshire.edu/lspector/push.html)
programming language, written in Swift.

Extracted from the *PropellerWithStructs* project into its own package so it can
be maintained independently and reused — in that app, in a server-side run
service, and in a federated mesh.

## Design

- **Dependency-light** — only `DequeModule` from
  [swift-collections](https://github.com/apple/swift-collections).
- **Concurrency-ready** — the language table is built once and shared; `Behavior`s
  hold no per-invocation mutable state, and the core is `nonisolated` + `Sendable`
  where it must be, so one shared language can drive many interpreters
  concurrently (each interpreter is its own single-task mutable island).
- **Linux-buildable** — pure logic plus stdlib/`DequeModule`; no platform-only APIs.

## Usage

Add the package as a dependency, then:

```swift
import PushInterpreter
```

## Testing

```sh
swift test
```
