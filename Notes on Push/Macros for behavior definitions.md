# Macros for behavior definitions

*A design proposal. Nothing here is built. Branch: `macroExploration`.*
*(Correction, 2026-11-06: Stage 0 and the Stage 1c tag work are built: `InstructionTag` as an open struct
with `TagProvenance`, `InstructionRole`, and `InstructionSets.iterators` derived from `.reEntrant`. Roadmap
#17's tags are applied, and the four gap instructions are built, so the "enum↔registry diff" below is now
empty. `Tags.swift` became `Roles.swift`, `InstructionTag.swift` and `Traits.swift`. Stages 1a/1b, 2 and 3
are not built.)*

> **Status, 2026-11-05.** Phase 2 of the speed-up separated calculation from provenance *without*
> macros: every transformer now receives a `ProvenanceRecording`, and every `call` is written inside
> `recording(…)` (an unevaluated `@autoclosure` when recording is off). See *Provenance and the crux.md*,
> "Recording only when asked". A macro was weighed and deferred. It would help only the ~170
> hand-written simple Behaviors. The hard cases (exec continuations record nothing; iterator provenance
> lives in `IteratorItem`; 442 of 608 Behaviors come from runtime factories; `reading`/`selecting`
> depend on routing) are out of a per-Behavior macro's reach. And swift-syntax costs build time,
> toolchain coupling and consumer-side macro trust. Stage 1 below would now derive `recording([...])`
> rather than a bare `call`; the counts in "The case" predate it (now 7,353 lines, 200 `call:` sites,
> 608 instructions).

## The case

`Sources/PushInterpreter/Behaviors/` is 7,342 of the library's 12,918 lines, and most of it is not
logic. Five axes vary across ~330 hand-written behaviors — instruction case, argument stacks, the
`as!` casts, one Swift expression, and the result stack — while everything around them
(`Router(…)`, `call: [y, x, InstructionItem(.name)]`, `isContingent: Behavior.netContingency(…)`)
is fully determined by the declaration and typed out by hand anyway. There are **191 literal
`call:` sites**, and the round-trip sweep has already caught four of them naming the wrong
instruction (`charGTE` recording `.charGT`), plus 22 unreproducible `StackDepth` records.

Three facts make this the right moment:

1. **We already asked for the prerequisite.** `Tags.swift:24-31` records the gap: *"a Behavior
   declares what it takes and nothing about its results… a `.converter` tag, or a computed
   producers/consumers ratio, would need Behaviors to declare their result stacks. Worth doing one
   day: the robustness sweep already drives every behavior, so a declaration that lied about its
   Routers could be caught there."* Declaring outflow is what makes `call` **derivable** rather than
   transcribed — and it is wanted independently.
2. **The specification is declaration-agnostic.** Per §16, the tests that matter sweep
   `Interpreter.language` (`Crux RoundTrip Tests`, `Planner Tests`, `Composition Invariant Tests`).
   They cannot be fooled by a change in how a behavior is *written*, which is exactly what makes
   this migration verifiable at every step.
3. **Adding a type costs ~28 edits across ~20 files**, four of which fail *silently*: `AnyItem`'s
   encode switch has a `default:`; `ConstantSlots` duplicates `Constant Behaviors`' stack list;
   `Traits` name-prefix families; the `PushStack Type Tests` sample map. Structured types (`point`,
   `circle`, `line`) and domain types are on the roadmap, so this cost is about to be paid
   repeatedly.

The intended outcome: one declaration site per behavior, provenance derived from it, registration
that cannot drift, and a type-addition cost of one descriptor instead of twenty files — with the
runtime registry shaped so a future extension-file-loaded type is a second client rather than a
rewrite.

**Guiding constraint, stated up front:** *use a macro only where a function or a loop cannot
reach* — generating declarations, generating names, and compile-time validation. Everything else
stays ordinary Swift. `Combinator Behaviors.swift` already produces 180 behaviors from a `for`
loop; that pattern needs no macro, only compile-checked names.

---

## Open questions

**Unresolved. Recorded rather than decided** — the rest of this document proceeds as if these were
settled, and they are not. Anyone returning to it should read these first, because two of them change
what the later stages are.

### Q1. Should the family macros generate instruction cases, or only check them?

Stage 3c and 3d as drafted **generate** the mechanical enum cases — 195 combinators, 80 constants,
~220 vector names. That would leave 275 of 603 tokens appearing as text nowhere: `.vecIntButLast`
and `.intDup` become ungreppable, discoverable only through Xcode's *Expand Macro* or the pinned
expansion test.

The alternative is a **checker**: keep every case hand-written in the enum, and have the macro emit a
compile-time existence proof — expanding to `[.intDup, .intSwap, .intRot, …]` in dot-syntax, so a
name the runtime loop will construct but the enum lacks fails to compile. That kills the
`PushInstruction(rawValue: "\(type)Dup")!` trap (including the `.error` case that traps today)
without hiding a single token, and it composes with `reportBehaviorCoverage()` promoted to an
assertion, which catches the opposite direction — a case with no behavior.

The trade is compile-checked names either way; the difference is only whether the names stay
readable in source. **Open.** The checker looks better on present evidence, and Stage 3d's ~770-line
win is unaffected either way (it comes from the behavior bindings, not the names).

### Q2. Does `PushInstruction` become a `RawRepresentable` struct — and is that a stage or a note?

Stage 2 files this as a Roadmap note. That may be underplaying it: **as drafted, the plan does not
let a loaded extension file add instructions.** The type registry lets a new type register its stack,
encoding and weight; its instructions still need enum cases, and enum cases are compile-time. If
extension-defined types are genuinely coming, the plan as written delivers half the feature.

What the swap costs is smaller than it looks. Traced through the token path:

- `.intQuot` dot-syntax survives with static members — **including typo protection**, since
  `.intQout` is still a member lookup that fails to compile
- `pretty()`, the genome JSON envelope, and crux rendering are **unchanged**: all three already carry
  the raw string, never a case identity or an ordinal
- `PushInstruction.allCases` is used in **exactly one place** — `Interpreter.swift:550-552`, inside
  `reportBehaviorCoverage()` — and what that caller wants is "every declared name", which a registry
  answers more honestly than the enum does today
- exhaustive `switch` over `PushInstruction` is lost, and there are essentially none

So the distinctive-token property is a property of the **raw string**, not of the enum, and it
survives either way. What the enum actually buys is `allCases` and exhaustiveness, and this codebase
uses almost neither. **Open** — the question is not whether it works but whether it is wanted now,
and it interacts with Q1 (a checker macro assumes an enum; a generator does not).

### Also unresolved, flagged in place

- **`reading` composed with `selecting`** (Stage 1d) — the document picks an order. Nothing
  exercises it today, so the choice is unforced and should be reviewed when something does.
- **Whether `accepts` stays a switch** for hot-path reasons (Stage 2) — to be settled by
  measurement, not argument.
- **The swift-syntax build cost** — stated from general SPM experience, not measured on this package.

---

## Stage 0 — Delete `isContingent` (Roadmap #23a)

**Do this before anything else.** It is a wide mechanical sweep with no semantic risk, and every
later stage is simpler for its absence.

> **Status: DONE.** The sweep landed on branch `removeIsContingent`. This section records the
> reasoning that justified it; see "Outcome" at the end for what actually happened.

### Why it goes, stated accurately

The two existing descriptions of the flag disagree, and only one of them is served by the crux:

- **Roadmap #23a** says it tracks whether an item's crux depends on the input variables. That *is*
  fully replaced. `.inputN` records `call = [InstructionItem(.inputN)]` (law 4b: environment state
  records, because a re-run finds the same binding), and `Runner.cruxMentions` — surfaced as
  `CaseResult.cruxMentionsInput`, driven by `RunnerConfiguration.cruxInputTokens` — reads it
  directly from the crux.
- **Design Principles §15** says it marks "a value whose presence depended on something the crux
  does **not** capture — a stack-depth read, a yank from an arbitrary position." That is **not**
  replaced, and it is important not to pretend otherwise.
  `stackDepthCombinator_Behavior` (`Combinator Behaviors.swift:450-482`) records `call: []` with
  `isContingent: true`; the crux is the bare literal `4`. Law 4b discards that provenance on
  purpose, so the flag really does carry something the crux does not.

So the deletion does not rest on "the crux covers it." It rests on a stronger test:

**Nothing consumes it.** Every read of `isContingent` anywhere in `Sources/` is either
`Behavior.netContingency` (`Behavior Infrastructure.swift:249`) propagating it into the next item's
flag, or a comment. The only two other reads — `Exec Behaviors.swift:204` and
`Vector Behaviors.swift:927` — are also propagation. No behavior branches on it. There is no guard,
no error, no routing decision, no search filter anywhere that asks.

**And it cannot reach the one candidate consumer.** `AnyItem` deliberately drops it on encode
(`AnyItem.swift:36-45`, alongside `call` and `index`), so `CaseResult`, `RecordedTrace` and
`Individual` never carry it. The Runner and the search — the only things that might plausibly want
to know a result depended on a stack accident — are already architecturally cut off from it.

It is a closed loop: computed from arguments, stored, propagated, serialized away, never consulted.

**What would revive the need**, so a later reader knows what they are looking at: *stochastic
Behaviors*, where input-dependence could not be read off a deterministic crux. There are none and
none planned. A second, weaker candidate would be a search that wanted to select on
provenance-invisible dependence — but law 4b means that would have to be designed properly rather
than inherited from a flag that was never read.

### Why it must go *first*

- **It removes an axis from the Stage 1 design.** Otherwise `Outcome` needs a `contingencySource:`
  declaration on every behavior plus a propagation rule in the derivation, and the macros in Stage 3
  have to carry it. Without it, `derive`/`pass`/`observe` are purely about `call`.
- **Two roadmap items evaporate rather than needing answers.** #18 (`contingencySources`, and its
  long-unresolved "do `DupItems`/`DupTimes` make their results contingent in themselves?"
  sub-question) has nothing left to enumerate, as does the contingency-visibility angle of #11/Q5.
  Roadmap #23a already anticipates this.
- **Scale.** ~288 occurrences across 16 source files and ~560 test assertions. Doing it after the
  migration means touching every site twice.

### Scope

| Where | What |
|---|---|
| `Items.swift` | the protocol requirement and the stored property on all 13 structs; the `init` parameter |
| `IteratorItem.swift` | stored property, `init`, `clamped`/`stepped` propagation |
| every `Behaviors/*.swift` | the `isContingent:` argument at ~190 construction sites |
| `Behavior Infrastructure.swift` | `Behavior.netContingency(of:)` — deleted outright |
| `AnyItem.swift` | the doc comment listing the dropped fields |
| `InstructionSets.swift` | the `contingencySources` TODO block |
| `Design Principles.md` §15, `Roadmap.md` #18/#23a | struck, with the reasoning above folded in |
| test helpers | `loadInts(_:ints:contingent:)` and siblings lose the `contingent:` parameter |
| behavior tests | ~560 standalone `#expect(…isContingent == …)` lines |

### Verification

Deleting an unused stored property cannot change what a program computes, and the safety net is
already in place:

- The full suite stays green. The `#expect(…isContingent == …)` lines are standalone — the stack
  shape and `callString` assertions beside them are untouched, so value and provenance coverage is
  unaffected.
- `Crux RoundTrip Tests` is unaffected by construction: it compares `pretty()`, never contingency.
- **No serialization break** — `AnyItem` never encoded it, so no stored genome, case, or trace
  changes shape.

### Outcome

Landed as planned. 41 files, **−1656/+485**. The full suite is green at 742 tests, and the build has
no warnings.

Where reality differed from the estimate:

- **Scale was larger than stated.** 930 total references, not ~288 source + ~560 test. The extra was
  boilerplate the table did not count separately — 13 stored-property declarations, 13 `init`
  parameters, and 13 `self.isContingent =` assignments each counted once per struct.
- **Six dead `let contingent = …` bindings** were left behind once the argument sites went (in
  `Exec`, `Vector` ×2, `String`, `Code` Behaviors), plus **eight `var`s that existed only to be
  mutated** by a contingency assignment and became `let`. Neither was in the plan; both were caught
  by the compiler.
- **Nine tests were removed, not just assertion lines.** Six `loadX sets contingency` tests became
  byte-identical duplicates of the `loadX loads X` tests beside them once the `contingent:` parameter
  went, and three (`contingency propagates to both pieces`, `…from the tree or the index`, `…from
  either operand`) had nothing left in the body. Three more still asserted real things and were
  renamed rather than deleted (`input records its history`, `constantRecordsItsHistory`, `crux can
  work through conditional code`).

**The evidence that the flag was inert.** The prediction was "`Crux RoundTrip Tests` is unaffected by
construction." Stronger than that held: the crux fuzzer's output before and after removal is
byte-identical — 7163 claims across 60 programs, same single pre-existing failure, same crux text.
Nothing about any crux moved.

**Unrelated finding, filed separately and since fixed.** Running the normally-`.disabled`
`CruxFuzzTests` to get that before/after comparison surfaced a real bug that has nothing to do with
contingency: multi-result Behaviors strand their unused sibling result on the stack, so their cruxes do
not compose as arguments — a violation of the composition invariant (Design Principles §1). Chasing it
turned up two more instances of the same rule-break (the iterator collectors, the recording peek
getters), all three now fixed, plus the missing language-wide test that should have caught them. →
issue #26. A long multi-seed fuzz then left a residual 0.05% of claims failing for a different,
pre-existing reason → issue #27.

**Bearing on Stage 1.** `Behavior.selecting` and `Behavior.reading` are exactly the helpers the
`derive`/`pass`/`observe` vocabulary has to wrap, and the lesson from #26 is that their contract is not
"record what produced this" but **"record what produced this *and* leave the stack as you found it."**
Whatever Stage 1 declares, the cleanup obligation has to be derived rather than left to each author to
remember — that is precisely the class of thing three families got wrong by hand.

---

## Stage 1 — Declared outflow and derived provenance (no macros)

The load-bearing change. Ships and is verified on its own.

### 1a. Declare the outflow

`Sources/PushInterpreter/Behavior Infrastructure.swift` — new types beside `Router`:

```swift
/// Which provenance law a result records under (Items.swift, "The provenance law").
nonisolated enum Recording: Sendable {
    case derived          // laws 2 & 3: new or relocated value → [args…, InstructionItem(name)]
    case derivedFromExec  // law 3b: args came from `.exec` → [InstructionItem(name), args…]
    case passed           // laws 1 & 1b: rearrangement/containment — keeps the argument's own `call`
    case observed         // laws 4 & 4b: fresh token, or read from transient execution state
}

nonisolated struct Emission: Sendable {
    let stack: PushStack
    let recording: Recording
}
```

`Behavior` gains `let produces: [Emission]` — the *possible* outflow, not the per-run one
(`intAdd` declares `[.int(derived), .error(derived)]`; it emits one). Possible-outflow is precisely
what `Tags`/`Traits` want.

### 1b. Derive the `call`

The transformer stops returning `[Router]` and returns an `Outcome`:

```swift
nonisolated struct Outcome: Sendable {
    mutating func derive(_ item: any Item, onto stack: PushStack)   // laws 2/3 (3b when exec-sourced)
    mutating func pass(_ item: any Item, onto stack: PushStack)     // laws 1/1b
    mutating func observe(_ item: any Item, onto stack: PushStack)  // laws 4/4b
}
```

`Behavior.act(on:)` resolves it into `[Router]`, attaching provenance by assigning `item.call`
after construction (`call` is `var` with a `didSet` maintaining `callWeight` — `intQuote` already
does exactly this at `Code Behaviors.swift:524-535`). One place now knows all four rules:

- **argument order** — reverse the popped order into source order (§2);
- **`.exec` prefix** — instruction first for `.derivedFromExec` (law 3b: `execQuote`, `execEq`);
- **query cleanup** — apply the existing `Behavior.reading(_:producing:from:)` using the behavior's
  own `readStacks`, which it already computes (`Behavior Infrastructure.swift:77-83`);
- **multi-result discards** — apply the existing `Behavior.selecting(_:of:on:from:)` with `total`
  taken from the *actual* same-stack derived results this run.

Reuse `reading` and `selecting` verbatim; they are correct and documented. This step only removes
the obligation to call them by hand. With Stage 0 done, `Outcome` is about `call` and nothing else.

### 1c. Declared tags — the judgment that cannot be derived

The same declaration should carry the instruction's **tags**, for the same reason it now carries
its outflow: it is the one place that knows.

**Why the existing machinery cannot absorb this.** There are three named-subset mechanisms today and
all three are *derived*:

| | Shape | Source |
|---|---|---|
| `InstructionTag` (`Tags.swift`) | strict **partition** | membership in the behavior dictionaries |
| `InstructionTrait` (`Traits.swift`) | **overlapping**, advisory | naming conventions + declared `requirements` |
| `InstructionSets.iterators` | a hand-written `Set` | typed out by hand, far from any definition |

`InstructionTrait` already has exactly the right *shape* — overlapping, advisory, some instructions
carry none. It has the wrong *provenance*: `Traits.swift:32-84` computes all of it. That
`.execY` is risky is knowledge from **other Push implementations**; it is not derivable from
anything in this codebase, so its only home today is `InstructionSets.swift` — a hand-maintained set
living far from the definition, which is the drift problem the rest of this document exists to kill.

This is what has **Roadmap #17 stuck**: *"the ~12 `iteratorFromX` constructors want ~7 arguments and
starve ~100% of the time, so they are dead weight in an evolvable genome. `InstructionTag` now
exists; tagging this set is the remaining step."* It is blocked because there is nowhere to declare
it. `InstructionSets.iterators` is the same shape and should become a tag too.

**Keep derived and declared in separate channels.** This is the load-bearing constraint. A derived
trait *cannot lie* — `.query` is read off `Behavior.readStacks`, so it is true by construction. A
declared tag *can*. Merging them into one vocabulary means someone eventually hand-declares
`.query` on something and it silently disagrees with the truth. So:

- **`InstructionTrait` stays closed and stays derived.** No declaration hook. Its honesty is the
  whole point.
- **`InstructionTag` becomes the declared, overlapping, judgment-carrying one.**

**The name is already taken, and freeing it is cheap.** Today's `InstructionTag` is the partition —
which this codebase already calls *"the role partition"* in prose, twice (`Tags.swift:58`,
`Traits.swift:9`). Rename it `InstructionRole` to match how it is already described. The raw values
(`constant`/`input`/`combinator`/`other`) do **not** change, so persisted PlungeGP configuration JSON
stays valid; this is a source break only. Carry a `@available(*, deprecated, renamed:)` typealias and
a deprecated `instructions(tagged:)` shim on `Runner` for one release.

**Tags must be open, not a closed enum.** If the Language tab is to let you mint a tag without a
library release, a `String`-raw enum cannot serve. Same problem and same answer as Stage 2's type
registry — a `RawRepresentable` struct with static members, so `.risky` dot-syntax survives while the
vocabulary stays extensible:

```swift
public nonisolated struct InstructionTag: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public static let risky        = InstructionTag("risky")
    public static let cruxOnly     = InstructionTag("cruxOnly")     // Roadmap #17
    public static let reEntrant    = InstructionTag("reEntrant")    // was InstructionSets.iterators
    public static let transcendental = InstructionTag("transcendental")
}
```

**A tag must say where its judgment came from.** §13 requires a limit to record whether its number is
free, inherited, or derived, *"because a number with no stated reason is indistinguishable from
cargo."* A judgment tag is the same object and needs the same discipline — `.risky` on `.execY` is
**inherited** (Clojush and Push3 experience), not measured here. So a tag declaration carries a
rationale alongside the `summary` that `InstructionTrait.summary` already sets the precedent for, and
the Language tab can show *why* rather than just *that*.

**Where it attaches.** The same initializer Stage 1a is already changing:

```swift
Behavior(
    .execY,
    takes: [.exec],
    produces: [.exec(.passed)],
    tags: [.risky, .reEntrant],
    fxn: …
)
```

The factory-generated families tag in the factory, which is *better* than per-instruction: one line
in `combinators(for:)` tags all 12 `Yank`s, one line in the `iteratorFrom…` group tags the whole
`.cruxOnly` set that Roadmap #17 wants.

**Runtime overlay, for the tags you edit in the app.** Declared tags are the baseline shipped with
the language; they are not the last word. `RunnerConfiguration` already carries
`disabledBehaviors: Set<PushInstruction>` and `cruxInputTokens`, so it is the right home for a
per-experiment overlay — additive and subtractive sets over the declared baseline, so an experiment
can mark something risky without editing the library, and the library's own judgment stays visible
underneath rather than being overwritten.

**Honesty guard.** A tag that *is* checkable must be checked against the derived truth rather than
trusted — if a tag ever duplicates something `requirements` or `produces` already knows, a sweep
should assert they agree. A tag like `.risky` is a judgment and unfalsifiable by construction; its
guard is the recorded rationale, not a test.

**Why it belongs in Stage 1 rather than after it.** It attaches to the same initializer, and the
macros in Stage 3 must carry it. Landing it separately means a second pass over all ~330 declaration
sites — the same argument that puts Stage 0 first.

### 1d. Two defects to fix here, because this code will now depend on them

- **`.error` has no combinator instructions.** `PushStack.popItemsInstruction` / `swapInstruction` /
  `popInstruction` (`Stacks.swift:98-115`) force-unwrap a name built by interpolation, and
  `Combinator Behaviors.swift:12-25` omits `.error` from `theseStacks`. So `PushStack.error` traps —
  reachable from `selecting`/`reading` the moment any behavior puts two results on `.error`. The doc
  comment asserts an invariant the code does not hold. Make the three properties `Optional`-returning
  and have `selecting`/`reading` degrade to "record nothing extra", with a test.
- **`reading` composed with `selecting` is undefined.** No behavior does both today (queries produce
  one result). Define the order — discard siblings first, then clean up read arguments so the
  fragment ends clean — and pin it with a test before anything can hit it.

### 1e. Migration

Keep the existing `[Router]` initializers alongside the new one and migrate **one behavior file per
commit**, easiest first (`Bool` → `Char` → `Int` → `Double` → `String` → `Vector` factories →
`Code` → `Iterator` → `Exec`). The `.exec` control-flow family (`Exec Behaviors.swift:221-386`)
records nothing and migrates last or not at all. Delete the old initializers when the last file lands.

### Verification for Stage 1

- **`Crux RoundTrip Tests.swift` green at every commit.** It sweeps every registered behavior and
  re-runs each recorded crux on a fresh interpreter; it is the authority and it is enabled by default.
- **The 569 `callString(…) == "( … )"` assertions must be unchanged.** These transcribe what each
  behavior *says*, so an unchanged suite is strong evidence the derivation reproduces the
  hand-written records exactly. Any diff is either a bug found or a deliberate correction — record
  which, the same way the previous sweep's findings are recorded in *Provenance and the crux.md*.
- **New: an outflow-honesty test.** Drive every behavior on the round-trip sweep's seeded
  interpreter and assert every emitted Router's stack appears in `produces`. This is the test
  `Tags.swift:29-31` predicted.
- **New: a tag-agreement test.** For every tag that duplicates something derivable, assert the
  declared set equals the computed one. Judgment tags (`.risky`) are exempt by construction and are
  covered by their recorded rationale instead.
- **Run the crux fuzzer once per family migrated** — `swift test --filter CruxFuzzTests` with
  `disabledTests = false`, run *alone* (it shares the `nonisolated(unsafe)` `fuzzRNG`). It is the
  only thing that catches a fixed-point violation, which is how the `stringNth` argument-order bug
  was found (§2).

### Payoff, before any macro exists

191 hand-written `call:` sites collapse; the wrong-instruction bug class becomes unrepresentable;
`InstructionTrait.converter` and the producers/consumers ratio for *Stack economics.md* become
computable. Roadmap #17 (the `.cruxOnly` set) unblocks, and `InstructionSets.iterators` stops being
a hand-maintained list.

---

## Stage 2 — The runtime type registry

Shape the mechanism the macros will feed, so a future extension-file type is a second client.
Macros are compile-time only; a runtime-loaded type can never be macro-generated. So the macro must
emit *values registered at startup*, not switch cases.

New `Sources/PushInterpreter/TypeRegistry.swift`:

```swift
public nonisolated struct PushTypeDescriptor: Sendable {
    public let stack: PushStack
    public let accepts:  @Sendable (any Item) -> Bool
    public let encode:   @Sendable (any Item) -> AnyItem.Payload?
    public let decode:   @Sendable (AnyItem.Payload) -> (any Item)?
    public let contentWeight: @Sendable (any Item) -> Int   // SizeLimits
    public let literal:  @Sendable (Any) -> (any Item)?     // Builders.pushItem
    public let random:   @Sendable (inout RandomNumberGenerator) -> any Item  // RandomCode
}
```

Rewrite as registry lookups the switches that must currently agree by hand:

| File | What changes |
|---|---|
| `Stacks.swift:55-71`, `:80-96` | `accepts` / `defaultStack(for:)` |
| `AnyItem.swift:66-120`, `:125-184` | encode/decode — removes the `default:` that fails at *runtime* |
| `SizeLimits.swift:25-59` | `vectorLength(of:)` / `overflow(of:)` |
| `Builders.swift:17-32` | `pushItem(_:)` |
| `Search/RandomCode.swift:247-282` | `randomPushItem()` and its magic `0..<30` denominator |
| `IteratorItem.swift:661`, `:700`, `:771` | walking constructor / `sourceCount` / `element(at:)` |
| `Runner/ConstantSlots.swift:12-13` | derive from the registry instead of duplicating the stack list |

**Hot path.** `accepts` and `defaultStack` run on every push. Key the registry by
`ObjectIdentifier(type(of: item))` for O(1) type→descriptor, and benchmark against
`Acceptance Tests (Slow)/Provenance Cost Benchmark.swift` before and after. If the closure
indirection costs measurably, keep `accepts` as a generated switch and route only the cold paths
through the registry — and record the reason, per §13.

**The remaining barrier.** `PushInstruction` is a `String` enum, so a runtime-loaded type cannot
name its instructions. Route every name construction through one `InstructionNaming` helper so the
eventual `RawRepresentable`-struct swap is a single file, and add the decision to the Roadmap rather
than taking it now. (`.intAdd` dot-syntax survives a struct with static members; exhaustive `switch`
and `CaseIterable` do not, and `CaseIterable` is load-bearing in several places.)

Stage 1c's `InstructionTag` takes exactly this shape already, on a much smaller surface — so it
doubles as a rehearsal. If the open-struct pattern proves comfortable there, the `PushInstruction`
swap is a known quantity rather than a leap.

---

## Stage 3 — The macro target

`Package.swift` gains swift-syntax (pin to the range matching the Swift 6.2 toolchain — verify
before committing; a mismatch is the usual first failure), a `.macro` plugin target
`PushInterpreterMacros`, and a `PushInterpreterMacroTests` target using
`SwiftSyntaxMacrosTestSupport`. Library consumers still depend only on `PushInterpreter`.

**Macros emit declarations and calls into Stage 1/2 mechanisms. No macro contains semantics.** That
is what keeps the hidden structure testable: the logic stays in ordinary generic functions that
already have unit tests, and the macro is checked by pinning its expanded source.

### 3a. `@PushItem` — the 13 item structs

```swift
@PushItem(comparable: true)
public struct IntItem { public var value: Int; public func pretty() -> String { "\(value)" } }
```

Emits `call` + `didSet`, `callWeight`, `init(_:call:)`, `==`, optional `<`, the
`Item, Equatable, Pretty` conformance, and the `PushTypeDescriptor`. `pretty()` stays hand-written —
it genuinely varies.

**One trap to get right:** `crux()` and `weight` are declared on the protocol *deliberately*, so
they dispatch dynamically through `any Item` (`Items.swift:110-128`). A generated conformance must
put them in the type or a non-retroactive extension; relying on the protocol extension compiles,
looks right, and silently ignores overrides — exactly the failure that comment exists to prevent.
Pin it with an expansion test.

Erases ~350 lines from `Items.swift` (on top of Stage 0's) and makes a new type's struct one
declaration.

### 3b. `@BehaviorTable` — kill the three-point sync

Attached member macro on each behavior extension. It walks the members, finds every
`static let <name>_Behavior`, and emits `static let <family>Behaviors: [PushInstruction: Behavior]`
keyed by the derived name.

This is the one that catches **omission**, not just mis-keying: today adding a behavior and
forgetting the dictionary entry (`Int Behaviors.swift:505-524` and 13 siblings) leaves it silently
absent from the language. `Vector Behaviors.swift` declares four families in one extension, so
either split it into four or give the macro a `prefix:` filter.

### 3c. `#combinatorInstructions` / `#constantInstructions` — compile-checked names

Freestanding declaration macros inside `PushInstruction` (`Instruction Infrastructure.swift`),
generating the 15 × 13 combinator cases and the 8 × 10 constant cases from the same stack list the
loops in `Combinator Behaviors.swift:12-25` and `Constant Behaviors.swift:19` iterate. Both sides
then read one list, which makes `PushInstruction(rawValue: "\(type)Dup")!` provably total instead of
a latent trap — and generating `.error`'s family closes Stage 1c's defect properly.

The behaviors themselves stay as the existing `for`-loop factories. They need no macro.

### 3d. `#vectorFamily(VecIntItem.self, comparable: true)`

Freestanding declaration macro emitting the ~35 `static let vecIntX_Behavior = xBehavior(.vecIntX,
making: VecIntItem.self)` bindings — `Vector Behaviors.swift:1075-1847`, ~770 lines and the single
largest mechanical block in the repo. A companion `#vectorInstructions("vecInt", comparable: true)`
inside the enum emits the matching cases. `comparable: false` drops `LT/LTE/GT/GTE`, which is how
`vecBool`'s 52-vs-56 asymmetry becomes a parameter instead of four quietly absent lines.

The ~30 generic factories at `Vector Behaviors.swift:69-1077` are untouched — the macro generates
only the wiring.

Family macros carry Stage 1c's tags as a parameter, so a whole generated family can be tagged in one
place — `#vectorFamily(VecIntItem.self, comparable: true, tags: [.collection])`. This is where
declared tags pay off most: 137 vector behaviors and 180 combinators get their judgment from one
line each rather than 317.

### 3e. Loop-generated, not macro-generated

`Output Behaviors.swift` (13 print clones, 175 lines) and the quote family
(`Code Behaviors.swift:510-587`) become `for stack in stacks` loops in the style of
`Constant Behaviors.swift:16-47`, once 3c makes the names compile-checked. Note `execQuote`'s prefix
`call` (law 3b) is a real exception, not a slip.

### 3f. The one remaining manual list

Swift has no cross-file static-init hook, so the descriptor list lives in one place:
`#pushTypes(BoolItem.self, IntItem.self, …)` in `TypeRegistry.swift`. A test asserts
`PushTypeRegistry.all` covers every `PushStack` except `.exec`, so an omission fails loudly.

---

## Testability

The direct answer to *"the explicit structure will be more hidden"*:

1. **Expansion tests are the structure, checked in.** `assertMacroExpansion` in
   `PushInterpreterMacroTests` pins generated source verbatim; the expansion is a reviewable
   artifact, and Xcode's *Expand Macro* shows it in place.
2. **The specification does not move.** `Crux RoundTrip Tests`, `Planner Tests` (the
   starved-interpreter bargain, tested once for the whole language) and `Composition Invariant Tests`
   all sweep `Interpreter.language` and are indifferent to how a behavior was declared. Per §16 these
   are the tests that matter, and a macro cannot fool them.
3. **A parity harness for the migration itself — the most important de-risker.** Before deleting a
   hand-written family, instantiate both versions and assert they are observationally identical over
   the round-trip sweep's seeded interpreter: same `requirements`, same Routers (stack, `pretty()`,
   `callString`). Cheap, temporary, deleted with the old code.
4. **New sweeps** that only become possible now: outflow honesty (§1), registry completeness (§3f),
   naming totality (every stack's `Pop`/`Swap`/`PopItems` resolves).
5. **Promote `Interpreter.reportBehaviorCoverage()`** (`Interpreter.swift:547-556`) from a print to
   an assertion — the enum↔registry diff should be exactly the four unbuilt gap instructions named at
   `Code Behaviors.swift:10-11`.
6. **The 569 `callString` assertions stay.** They pin what a behavior *says*; round-trip pins that it
   is *true*. The two catch different things and neither replaces the other
   (`Behavior Tests Helper.swift:39-51` says so).

---

## Where the prose goes

This codebase's value is disproportionately in its recorded rationale, and a macro that swallows doc
comments would be a real loss. Two rules:

- The **declaration site keeps its doc comment**; the macro generates only mechanism. A behavior
  that has something to say still says it where a reader looks.
- Add a *Generated declarations.md* note — what each macro generates, why, and what it is allowed to
  assume — and index it in *Design Principles.md* beside the other notes. §13 requires a limit to say
  where its number came from; generated code should say where it came from for the same reason.

---

## Risks

- **swift-syntax roughly doubles clean-build time** and the plugin builds for the host, not the
  deployment target. Worth confirming the actual number early.
- **Debugging inside generated closures is worse** — breakpoints land in expansion buffers. This
  argues for 3a–3d generating *calls to* named functions rather than inlining bodies, which the
  design already does.
- **Version coupling.** A toolchain bump can break the plugin. Pin narrowly and treat
  `PushInterpreterMacroTests` as the canary.
- **Stage 1c breaks PlungeGP's source**, via the `InstructionTag` → `InstructionRole` rename and the
  `instructions(tagged:)` signature. Persisted configuration JSON is unaffected (the raw values do
  not change), and the deprecated typealias and shim cover a release, but the app needs a
  coordinated update. It is the only outward-facing break in the whole document.
- **Stage 1 is the only stage that changes behavior.** Stage 0 is a deletion of dead weight; Stages
  2–3 are mechanical. If the round-trip sweep or the fuzzer goes red, it is Stage 1, and the per-file
  commits make it bisectable.

---

## Verification, end to end

```bash
swift build
swift test                                     # 756 @Test across 80 files; round-trip sweep included
swift test --filter CruxRoundTripTests         # the authority for Stage 1
swift test --filter CruxFuzzTests              # ALONE, with disabledTests = false — fixed-point check
swift test --filter PushInterpreterMacroTests  # expansion pinning, Stage 3
swift test --filter ProvenanceCostBenchmark    # registry hot-path regression, Stage 2
```

Done when: the sweep and the fuzzer are green, `callString` assertions are unchanged (or every diff
is recorded as a deliberate correction), the parity harnesses have been deleted along with the code
they guarded, and adding a hypothetical `PointItem` requires one `@PushItem` struct, one `#pushTypes`
entry, one line in `theseStacks`, and its own behaviors — instead of twenty files.
