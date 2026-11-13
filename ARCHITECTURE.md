# Architecture

How the interpreter is put together, for people changing it. For what the
language does, see the DocC documentation (`Sources/Plunge/Plunge.docc/`);
for how to work on the code, see [CONTRIBUTING.md](CONTRIBUTING.md).

## The public boundary

A library user sees a small surface:

- **`Runner`** (an actor) and the stateless `evaluate(request:)` and
  `evaluate(streaming:)`, which run programs;
- **the values they exchange**: `Individual`, `TrainingCase`, `Pairing`,
  `CaseResult`, `RunnerConfiguration`, `InterpreterSettings`, `RecorderSpec`;
- **the items**: `IntItem`, `CodeItem`, `IteratorItem`, `BindingItem` and the rest,
  with `AnyItem` and `ItemArchive` to encode them;
- **the language's vocabulary**: `PushInstruction`, `PushStack`, and the
  introspection on `Runner` (`summary(of:)`, `signature(of:)`, roles, tags).

Everything else is internal, the `Interpreter` class included. That is
deliberate: a search talks to the language through the `Runner`, so the machinery
behind it can change without breaking callers.

## The run

`evaluateOne` (in `Runner/Runner.swift`) is the whole of one evaluation. It makes
a fresh `Interpreter`, applies the settings and the table of enabled behaviors,
loads the training case's inputs, the individual's constants and its program,
runs it, and reads the recorders.

`Interpreter.load` resets the stacks and counters, binds inputs and constants,
binds each input on `.binding` under its slot number, and puts the program on
`.exec`. `Interpreter.run` then calls `step()` until `.exec` is empty or the
step limit is reached. A step takes the top of `.exec` and:

- pushes a `CodeItem` onto `.code` (code is data until an instruction runs it);
- runs an `InstructionItem`'s `Behavior`;
- releases a `StandInItem` as the literal it stands for;
- pushes any other item onto its stack (`PushStack.defaultStack(for:)`).

After each step the recorders observe, and the runaway and memory guards
(`RunawayGuard.swift`) may stop the run.

## Stacks and items

`PushStack` is a plain enum, one case per stack. Every table indexed by stack is
derived from `PushStack.allCases`, so adding a stack means adding a case and
following the compiler. `StackSet` stores one `Deque` per stack in an array
indexed by the case's ordinal; profiling found that hashing a string-backed enum
on every access was a fifth of all run time.

Every value is an `Item` (`Items.swift`, with the item types in `ScalarItems.swift`,
`VectorItems.swift`, `CodeItem.swift` and `ErrorItem.swift`, and history storage in
`CallStorage.swift`). An item has a `value` and a `call`, its
history, and knows its `weight` (content, for size limits) and `nestingDepth`.
Most item types are value types with a `ValueItem` conformance. Containers whose
elements can carry their own history (strings, vectors) are `MemberItem`s, and
`TracingItem`s can hand an element back with its history. `CodeItem` is the one
heterogeneous container; `IteratorItem` and `BindingItem` hold items too.

Each stack holds exactly one Swift type, and `.exec` alone holds anything. That
invariant is what makes the `as!` casts in Behaviors safe; `requireAccepts`
enforces it at every push.

## Behaviors

Each instruction's semantics is a `Behavior` (`Behavior Infrastructure.swift`): an
immutable, shared object holding

- its **requirements**, in order: items it takes, reads, or needs in place
  (`Requirement`);
- its **class** (`BehaviorClass`): operation, structural, context read, control
  or channel;
- its **body** (`BehaviorBody`), whose type limits what it can touch. A `values`
  body sees only its arguments; a `structural` body sees one stack and returns a
  `PositionEffect`; a `contextRead` body gets a read-only `ReadContext`; a
  `control` body returns `ControlEffect`s for `.exec`; a `channel` body returns
  what to print;
- what it **produces** (`Produces`), its **tags**, and its one-line **summary**.

`Behavior.act` is the only place an instruction changes the interpreter. It
checks the requirements (directly for the common static case, through the
`Planner` otherwise). If a stack is short the instruction *starves*: it leaves a
*missing arguments* error, takes nothing, and is put on `.function` as a bare
function. Otherwise `act` removes what the instruction takes, computes, and
routes the results (`Router`). A `Refusal` thrown by a body becomes an
`ErrorItem`.

Most Behaviors are written with the typed constructors in `Typed Operations.swift`:

```swift
static let intAdd_Behavior =
    Behavior.operation(.intAdd, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
        …
    }
    .described("Adds two ints; refuses on overflow.")
```

The argument types are listed in written order, the order a program writes them,
and the constructor writes the casts, the routing and the recorded history.
`operation(reads:)` makes a query, `assembling` builds a collection from its
arguments' elements, `extracting` and `finding` take elements out, `splitting`
returns two results. Families that exist for every stack or every vector type are
generated by helper functions (`Stack Family Behaviors.swift`, `Vector Behaviors.swift`).

The language is assembled once, as `Interpreter.language`, from the per-file
dictionaries (`intBehaviors`, `codeBehaviors`, …) and shared by every interpreter.

## Provenance

With `recordsProvenance` on, every result records its arguments and its
instruction in `call`, so `item.crux()` writes out a program that reproduces it.
The rules are the **provenance laws**, written out at the top of `Items.swift`:
rearranging records nothing, a result records its arguments and instruction, a
value read from the run's state records a stand-in, and so on.

Pieces of the machinery:

- `WrittenCall` and `Behavior.reading`: a query's history removes the arguments it
  read, so a crux leaves only its value (the **composition invariant**: a crux
  used as an argument must not leave debris for its neighbors).
- `Containment`: an element taken out of a container records its address.
- `StandInItem`: a marked literal for a value whose history can't be replayed.
- `CruxSharing`: a crux builds a shared value once and duplicates it.
- `CruxCompression`: a loop's long chain folds into a counted loop.
- `ProvenanceRecording`: every history is built inside `recording(…)`, which
  evaluates nothing when recording is off, so an unrecorded run pays nothing.

Over-large histories are elided at the push boundary and replaced by stand-ins,
never silently dropped.

## Limits

`InterpreterSettings` bounds steps, stack depth, collection sizes, code size and
depth, each item's total weight, the history an item may keep, and the total
weight live across all stacks. Each limit's comment says whether its number was
inherited from another Push implementation, chosen here, or derived from another
limit. Integer arithmetic refuses rather than overflowing, and no instruction
leaves a NaN or an infinity on `.double`, so numbers need no limit of their own.

## Describing the language

Several tables describe the language rather than run it, all derived from the
Behaviors at launch:

- `Interpreter.signatures` (`InstructionSignature`): what each instruction takes
  and gives, the language's input-output map;
- roles (`Roles.swift`): a partition by where an instruction is registered;
- tags (`InstructionTag.swift`, `InstructionTagging.swift`): an open vocabulary of
  overlapping labels. The standard tagging joins the judgments declared at each
  Behavior (`.fallible`, `.reEntrant`, …) with tags derived from the Behaviors'
  declarations (`AutomaticTags.swift`), never from names. Context reads declare
  the stacks they look at (`Behavior.observes`) so the derivation can see them;
  the IO declaration tests check that in debug builds;
- summaries: one sentence per instruction, from which the DocC instruction
  reference is generated.

## Generation

`Generation/` holds ways of making programs that aren't the language itself:
random programs for fuzz and diagnostic tests, drawn by role (`RandomCode`); a
genome encoding that implies code blocks (`FibonacciGenome`, `BlockPacking`);
and a backward chainer that builds programs producing a wanted stack
(`BackwardChaining`). Search itself lives in the app. Genome definitions may
later be shared between search, fuzz testing and instructions that edit genomes,
each with its own translation and manipulation functions.

## Concurrency

Every Behavior is immutable and `Sendable`, and the language table is built once.
An interpreter is a mutable island used by one task. The `Runner` evaluates
pairings in a task group, each on its own interpreter, and returns results in the
order given. The package is `nonisolated` throughout and builds on Linux.
