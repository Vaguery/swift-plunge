# Contributing

The library is under intense development, with major architectural changes
planned before version 1.0. Contributions and feedback aren't being sought until
those are finished.

## Working on the code

How to build, test and document changes to the interpreter. Read
[ARCHITECTURE.md](ARCHITECTURE.md) first for how the pieces fit.

## Build and test

```sh
swift build
swift test
```

The suite has about a thousand tests and takes a few minutes. Most of the time is
in `Tests/PlungeTests/Acceptance Tests (Slow)/`: fuzzers that run random
programs and replay every result's history, and stress runs. While working on one
area, run its suites with `swift test --filter`, and run the whole suite before
committing a change to the language.

The tests are grouped by what they cover:

| Folder | Covers |
|---|---|
| `Behaviors/` | instructions, one suite per family |
| `Infrastructure/` | the interpreter, provenance, limits and the language tables |
| `Runner Tests/`, `Public API Tests/` | the public boundary |
| `Generation Tests/` | random code, genomes, backward chaining |
| `Documentation/` | the instruction reference, the article and README examples, and the stated counts |
| `Acceptance Tests (Slow)/` | fuzzing, crux replay, stress and measurements |

Several tests pin counts that describe the whole language: how many
instructions are in each Behavior class and role, and the shape of the
input-output map. Adding instructions changes them on purpose; update them and
say so in the commit. The README and the DocC landing page also state the
instruction and stack counts in prose; `Stated Counts Tests.swift` fails until
they match the language.

## Adding an instruction

1. Add the case to `PushInstruction` in `Instruction Infrastructure.swift`.
2. Write the Behavior in the matching file in `Behaviors/`, preferably with a typed
   constructor (`Typed Operations.swift`), and give it a summary with
   `.described("…")`.
3. Register it in that file's dictionary.
4. Test it in `Tests/PlungeTests/Behaviors/`.
5. Regenerate the instruction reference (below), and update any pinned counts.

The language's conventions:

- **Name an instruction for the stack it works on**: `intAdd`, `codeDo`,
  `bindingDeref`. A verb follows its source stack when it makes something from
  it (`intQuote`, `intRef`).
- **Write arguments in written order**: the order a program pushes them. A search
  takes the container first, then what is sought: `v x .vecIntIndexOf`.
- **Return a result or an error, never nothing**: arguments of the wrong value are
  a `Refusal`, never a silent no-op. A search that finds nothing refuses too.
- **Queries read and leave their arguments**; transforms consume them. A
  non-destructive form of a consuming instruction is a `Peek` form.
- **Block arguments come from `.code`**, never from `.exec`.
- **Clamp indices** into range rather than refusing them.
- **Nothing random**: an instruction's result depends only on its arguments and
  the run's state.
- **Record history** through the typed constructors, or by hand following the
  provenance laws in `Items.swift`. The crux fuzzers (`Crux RoundTrip Tests`) replay
  every result of every instruction and will find a history that doesn't
  reproduce its value.

## Summaries and the instruction reference

Every instruction has a one-sentence summary, declared with `.described(…)`. The
style:

- start with a verb, and keep to one sentence (semicolons allowed);
- when the order of arguments matters, show the written form:
  "Subtracts: `` `a b .intSubtract` `` gives a − b.";
- say what a query leaves ("…, leaving both") and when an instruction refuses
  ("refuses when b is 0");
- don't mention starvation, provenance or implementation details.

The DocC instruction reference is generated from these summaries and the
Behaviors' declarations. After changing the language, regenerate it:

```sh
PUSH_WRITE_REFERENCE=1 swift test --filter InstructionReferenceTests
```

Without the variable, the same test fails if the committed pages are out of date.

## Documentation

The DocC catalog is `Sources/Plunge/Plunge.docc/`. Build or
preview the site with the DocC plugin:

```sh
swift package --disable-sandbox preview-documentation --target Plunge
swift package --disable-sandbox generate-documentation --target Plunge
```

Code in the articles is compiled and run by
`Tests/PlungeTests/Documentation/Documentation Examples Tests.swift`, which
imports the module without `@testable`, so examples can use only the public API.
Change an example in both places.

Public API needs a documentation comment. Explain behavior and intent; don't cite
issue numbers or documents outside this repository.

## Style

- Swift 6 with strict concurrency; the package is `nonisolated` throughout.
- Run [SwiftLint](https://github.com/realm/SwiftLint) on the files you change,
  and add no new violations. `.swiftlint.yml` records the conventions the code
  follows on purpose (short closure names, the `_Behavior` suffix, `as!` on
  planner-checked arguments); keep lines within 120 characters.
- One commit per change, with a message that says why.
