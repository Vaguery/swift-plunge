//
//  Interpreter.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/30/26.
//

import DequeModule
import Foundation


public nonisolated struct InterpreterSettings: Sendable, Codable {
    public init() {}

    // Numeric magnitude caps are intentionally omitted: Int behaviors use
    // checked (…ReportingOverflow) arithmetic and Double behaviors reject
    // non-finite results, so neither can trap or grow memory unbounded.
    //
    // EVERY NUMBER BELOW SAYS WHERE IT CAME FROM, because none of them is
    // self-evident and an unexplained limit is indistinguishable from cargo (see
    // Design Principles §13). Three kinds, and the kind says what you may do to it:
    //
    //   INHERITED — taken from another implementation for comparability, not
    //               correctness. Change it freely; the only cost is that runs stop
    //               being comparable with theirs. Most of these were never examined
    //               on their own merits, and saying so is better than implying a
    //               rationale nobody had.
    //   CHOSEN    — a policy of ours. Change it at will; nothing else moves.
    //   DERIVED   — fixed by another limit here. Looks free and is not: changing
    //               the other one silently makes this one wrong.
    //
    // **A relation nothing enforces**: `stepLimit` must exceed `maxVectorLength`
    // and `maxStringLength`, or the largest collection the interpreter will ACCEPT
    // cannot be walked to completion. At these defaults it does not — a
    // 1,000-element walk emits 997 and dies three short, missing by the setup cost.
    // Left alone rather than papered over, because raising `stepLimit` changes
    // every run; but it is a genuine incoherence and worth knowing.

    // INHERITED, loosely after propeller's limits.cljc:
    //   https://github.com/lspector/propeller/blob/master/src/propeller/push/limits.cljc
    // None of these six was chosen here on its own merits. `maxIterations` below is
    // derived from `stepLimit`, so moving that one moves this one too.
    public var stepLimit       : Int = 1_000
    public var maxStackDepth   : Int = 10_000
    public var maxStringLength : Int = 1_000
    public var maxVectorLength : Int = 1_000
    public var maxCodePoints   : Int = 1_000
    public var maxCodeDepth    : Int = 1_000
    // CHOSEN. Total recursive content (Item.weight) allowed in a single pushed
    // item. Supplements the per-dimension caps above to bound nested content — a
    // vector of long strings, or code whose leaves are large — that the
    // count-only caps cannot see. The number is a policy: large enough not to
    // refuse anything the per-dimension caps already allow, small enough to catch
    // their product. Nothing else depends on it.
    public var maxItemWeight   : Int = 100_000
    // CHOSEN, and the most forgiving number here: over-budget provenance is
    // ELIDED rather than refused, and eliding costs the explanation but never the
    // value — the elided history is replaced by a stand-in (`StandInItem`), a
    // marked literal that is already a runnable program producing that value and
    // that says it is one. So being wrong in either
    // direction is cheap, which is exactly why the budget can afford to be
    // aggressive. See `Interpreter.elidingOverBudgetProvenance`.
    //
    // Total provenance (Item.callWeight) allowed on a single pushed item: the caps
    // above bound an item's *content*, this bounds its *history*. A history is
    // over it only if its crux is: one that is over as a tree is measured again
    // as the crux, which builds each shared node once (`CruxSharing`), and kept
    // if that fits. That used to be
    // the last unbounded dimension in the system; `maxIterations` below now holds
    // that title, since nothing bounded what a loop CLAIMS.
    public var maxCallWeight   : Int = 10_000
    // DERIVED from the stack a concurrency worker thread gets (512 KB), and NOT a
    // preference. The deepest provenance a pushed item may keep, elided like
    // `maxCallWeight`. Weight bounds a call tree's size, not its depth (a chain
    // grows ~2 per level), and every walk *and every release* of a tree costs a
    // stack frame per level: the dual-mode stress run killed the process
    // releasing a 2,463-deep tree on a worker thread, and dropping a 5,000-deep
    // chain there crashes outright (2,000 does not). 1,000 leaves room for frames
    // larger than that measurement's. Raise it only for runs on big-stack threads.
    public var maxCallDepth    : Int = 1_000
    // DERIVED from `stepLimit`, and NOT a preference. The most passes any single
    // COUNTED loop may promise — the last unbounded dimension there was:
    // `stepLimit` bounds the work a loop does, but nothing bounded what one loop
    // *claims* it will do — so `0 999999
    // .execDoRange` did not run a million times, it ran a few hundred and died
    // half-finished, leaving debris instead of an answer. Clamping does not buy
    // safety (stepLimit had that); it buys COMPLETION, and a program whose loops
    // finish is one a human can read.
    //
    // Applied by clamping a loop's span at construction — never by modulo, which
    // is chaotic (100 % 100 = 0 passes) and so cannot be climbed by a search or
    // followed by a reader. Clamping is monotone: counts under the limit pass
    // through untouched, counts over it saturate.
    //
    // WHY 100: at `stepLimit` 1_000 and roughly 1-4 steps per pass, ~100 is the
    // largest loop that can FINISH, and finishing is the entire point of it. It
    // looks inconsistent beside the 1_000s above and that inconsistency is
    // information — this one is derived and they are not. **Raise `stepLimit` and
    // this is needlessly small; lower it and this becomes a lie.** A test that
    // wants a longer loop raises both, which is the pattern.
    //
    // Counted loops only. A collection's length is a fact rather than a claim, so
    // `.elements` walks are bounded by maxVectorLength/maxStringLength instead —
    // and NOTE those must stay below `stepLimit`, or the largest legal collection
    // cannot be walked to completion. See "Notes on Push/Keeping loops
    // human-sized.md" and Design Principles §12.
    public var maxIterations   : Int = 100
    // When a stack fills faster than the size caps would catch, watch for the
    // signature of a runaway loop (a stack piling repeats or cycling a short
    // period, *and* a looping instruction pending on `.exec`) and stop the run
    // early with a `RUNAWAY:` marker. Diagnoses the cause rather than blindly
    // truncating; see `Interpreter.enforceRunawayGuard`.
    public var runawayGuardEnabled = true

    // The one GLOBAL memory bound. Every other cap is local — a single item's
    // content (`maxItemWeight`), a single stack's depth (`maxStackDepth`), one
    // collection's length — and their sum is bounded by nothing, which is how a
    // loop piling few-but-large items (each legal, the stack never deep enough to
    // trip the count-based runaway guard) reaches tens of GB. This caps the SUM:
    // the total `Item.weight` live across all stacks. A run that would exceed it is
    // stopped with a `MEMORY:` marker, exactly as the runaway guard stops a piling
    // loop — so `stepLimit` can rise freely for real algorithms without memory
    // following it. `Int.max` disables the guard.
    public var maxLiveWeight = 50_000_000

    // Whether Behaviors record `call` provenance (the source of `crux()`).
    //
    // **Default false.** Off, no Behavior builds a `call` at all: every provenance
    // expression is written inside `recording(…)` (see `ProvenanceRecording`), which
    // is never evaluated, so the run pays nothing for explanations it does not want —
    // neither the time to build the call tree nor the memory a loop would accumulate.
    // Crux is something to ask for when a task needs it: re-running a *special*
    // individual (the best genome) with this on, a crux-reading search operator, a
    // Runner asked for `cruxInputTokens` (which turns it on for that run).
    //
    // A call-less item's crux is `[self]`, a runnable literal producing the same value,
    // so this never changes what a program computes — only whether it can explain
    // itself. `Provenance Off Parity Tests` holds the whole language to that. A
    // behavior that *reads* a crux to do its work must guard with
    // `Interpreter.requiresProvenance(_:)`.
    public var recordsProvenance = false


    /// The same policy, relaxed for **reconstruction** — re-running one item's
    /// crux rather than running a population.
    ///
    /// The size caps above are a *throughput* compromise, not a semantic one:
    /// they exist so a whole population evaluates in reasonable time and space.
    /// A single individual, re-run on its own to explain itself, is not competing
    /// for that budget and can afford far more.
    ///
    /// Without this the interpreter can refuse its own reconstruction. A walking
    /// `IteratorItem` may hold a 2,432-point origin block and rest on `.iterator`
    /// quite legally — `SizeLimits.overflow(of:)` only measures `flatSize` when
    /// the item *is* a `CodeItem`, and an iterator is not. But
    /// `IteratorItem.reconstruction()` re-pushes that origin **through `.code`**,
    /// where the cap does apply, so the constructor loses its argument and the
    /// crux rebuilds nothing. The record was honest; only the replay budget was
    /// wrong. (Reachable the same way through `maxVectorLength` and
    /// `maxStringLength`, via an iterator walking an oversized collection.)
    ///
    /// **Three things deliberately do not move**, because each would change what
    /// the replay computes rather than what it is allowed to hold:
    ///
    ///  - `maxIterations` — a counted loop's span is clamped at construction, and
    ///    the crux records the clamped bounds. Allowing more passes here would run
    ///    a *different* loop than the one that produced the value.
    ///  - `maxCallWeight` — provenance elided in the original run must elide the
    ///    same way in the replay, or the reproduced item carries more history than
    ///    the original and the fixed-point check fails on a difference this policy
    ///    introduced.
    ///  - `maxCallDepth` and `maxCodeDepth` — not budgets but stack safety: a
    ///    replay runs on the same kind of thread, so it can afford no more depth
    ///    than the original, and an original item never needed more than its run
    ///    allowed.
    ///  - `stepLimit` — a crux flattens a call DAG per path and is routinely far
    ///    longer than the run that built it, so its budget belongs to whoever
    ///    knows the crux's length. Size it there.
    ///
    /// `maxLiveWeight` rises but stays finite: it is the one global memory bound,
    /// and the point of relaxing is to survive a large *legitimate* value, not to
    /// remove the backstop that stops a runaway from taking the process down.
    public var reconstructing: InterpreterSettings {
        var relaxed = self
        relaxed.maxStringLength = maxStringLength * 1_000
        relaxed.maxVectorLength = maxVectorLength * 1_000
        relaxed.maxCodePoints   = maxCodePoints   * 1_000
        relaxed.maxItemWeight   = maxItemWeight   * 1_000
        relaxed.maxStackDepth   = maxStackDepth   * 100
        relaxed.maxLiveWeight   = maxLiveWeight   * 20
        return relaxed
    }
}


nonisolated final class Interpreter {
    
    static func integrateBehaviors(
        fromThese: [PushInstruction:Behavior],
        intoLanguage: inout [PushInstruction:Behavior]) {
        intoLanguage.merge(fromThese, uniquingKeysWith: { (first, _) in first })
    }
        
    /// Built exactly once, on first access, and shared by every `Interpreter`.
    /// Safe to share because `Behavior`s hold no per-invocation mutable state
    /// (see `Behavior.act`); this replaces the former per-instance rebuild.
    static let language: [PushInstruction: Behavior] = {
        var starter:[PushInstruction: Behavior] = [:]

        integrateBehaviors(fromThese: boolBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: charBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: combinatorBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: comparisonBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: codeBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: constantBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: execBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: doubleBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: inputBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: introspectionBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: outputBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: intBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: iteratorBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: stringBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: vecBoolBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: vecDoubleBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: vecIntBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: vecStringBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: vectorSharedBehaviors, intoLanguage: &starter)
        return starter
    }()
    
    
    static let defaultSettings = InterpreterSettings()

    /// `language` as an array-backed table, built once and shared by every
    /// interpreter (copies share storage until one disables something).
    static let languageTable = BehaviorTable(language)

    // MARK: Per-run state, without dynamic exclusivity checks
    //
    // `@exclusivity(unchecked)` drops the runtime check (`swift_beginAccess` /
    // `swift_endAccess`) Swift makes on every access to a class's stored property it
    // can't prove exclusive, which is nearly every access from a Behavior. Those
    // checks were about a tenth of all step time (Phase 4 profile). It is safe because
    // an `Interpreter` is confined to one task for a run, and no Behavior holds an
    // `inout` access to one of these across a call that reaches the same property.
    // The debug test suite still runs with the checks for every other property, and
    // the parity snapshots confirm unchanged results.

    @exclusivity(unchecked) var behaviors: BehaviorTable = Interpreter.languageTable
    @exclusivity(unchecked) var stacks: StackSet
    /// Running total of `Item.weight` (content) live across all stacks — maintained
    /// incrementally by the mutation helpers (`place`/`take…`/`clear`), and re-anchored
    /// by `recomputeLiveWeight()` at every run start. Lets `enforceMemoryGuard` be O(1)
    /// per step instead of re-summing all stacks; see `RunawayGuard`.
    @exclusivity(unchecked) private(set) var liveWeight: Int = 0
    @exclusivity(unchecked) var counter: Int = 0
    // Step at which the runaway guard last examined the stacks; -1 means never.
    // Throttles the (only-when-a-stack-is-deep) examination. See enforceRunawayGuard.
    @exclusivity(unchecked) var lastRunawayCheck = -1
    var inputs: [PushInstruction:any Item] = [:]
    // Bound constant values, keyed by their constant instruction (e.g. `.int3`),
    // symmetric with `inputs`. A missing key means the constant is unassigned;
    // the constant behavior emits an ErrorItem for that case at runtime, so no
    // pre-seeding of nil slots is needed.
    var constants: [PushInstruction: any Item] = [:]
    @exclusivity(unchecked) var config: InterpreterSettings = Interpreter.defaultSettings

    /// Whether this run records provenance, as Behaviors receive it: pure ones as
    /// their transformer's second argument, side-effecting ones by asking the
    /// interpreter they are handed.
    var recording: ProvenanceRecording { ProvenanceRecording(isOn: config.recordsProvenance) }
    var program: [any Item] = []
    /// Everything the print instructions have written, as text.
    ///
    /// **Rendered when read.** A print instruction records the item it prints
    /// (`printItem(_:)`), which shares the item's storage, and the text is made when
    /// someone reads `printout`, each item once. The search never reads it, and
    /// rendering eagerly was most of a print's cost: up to 0.4 ms for a vector at
    /// `maxVectorLength` (Instruction Scaling Probe). The text is the same either way.
    var printout: String {
        get {
            if !pendingPrints.isEmpty {
                for item in pendingPrints { renderedPrintout.append("\(item.pretty())\n") }
                pendingPrints.removeAll()
            }
            return renderedPrintout
        }
        set {
            renderedPrintout = newValue
            pendingPrints.removeAll()
        }
    }
    private var renderedPrintout = ""
    private var pendingPrints: [any Item] = []

    /// Print an item: its `pretty()` text and a newline, rendered when `printout` is
    /// read.
    func printItem(_ item: any Item) { pendingPrints.append(item) }

    /// Print raw text (`.printNewline`), after anything already printed.
    func printText(_ text: String) {
        if pendingPrints.isEmpty { renderedPrintout.append(text) } else { printout.append(text) }
    }
    // Use AnyRecorder for type erasure of Recorder generic type
    var recorders: [String: AnyRecorder] = [:] {
        didSet {
            everyStepRecorders = recorders.values.filter { $0.policy == .everyStep }
            finalOnlyRecorders = recorders.values.filter { $0.policy == .finalOnly }
        }
    }
    /// `recorders` split by policy, as arrays, for the step loop. A `.finalOnly`
    /// recorder keeps only its last reading, and nothing changes between a run's
    /// last step and its end, so `run` takes that reading once, at the end, rather
    /// than after every step (`deferringFinalOnly`). Called directly, `step` still
    /// records both kinds.
    private var everyStepRecorders: [AnyRecorder] = []
    private var finalOnlyRecorders: [AnyRecorder] = []
    private var deferringFinalOnly = false
    var recorderNames: [String] {
        recorders.keys.sorted()
    }
    
    init(stacks: StackSet = PushStack.emptyStacks()) {
        self.stacks = stacks
        self.recomputeLiveWeight()
    }

    /// The single validated entry point for pushing an item onto a stack.
    /// Every stack except `.exec` is homogeneous, so pushing an item a stack
    /// does not accept can only mean a mis-tagged `Router` (a programming bug).
    /// Trap immediately rather than corrupt the stack and defer the failure to
    /// some later `as!` in an unrelated Behavior.
    @inline(__always)
    func push(_ item: any Item, to stack: PushStack) {
        push(BoxedItem(item: item), to: stack)
    }

    /// An `any Item` carried in a struct, so the optimizer leaves `push`'s body alone.
    ///
    /// Given a bare `any Item` parameter, the optimizer rewrites `push` into a generic
    /// function specialized for each caller's concrete type (`push(ErrorItem(…),
    /// to: .error)`; the `Tf4e` symbols). The specialized body then has to make a
    /// fresh `any Item` for every helper it hands the item to (`requireAccepts`,
    /// `overflow`, `place`, …), and an item too big for an existential's three inline
    /// words (a block, an error, an iterator) gets a new heap box each time: several
    /// allocations per push, which the Phase 4 profile found. Through the struct, a
    /// concrete caller boxes the item once, at the call, and the box is passed along.
    struct BoxedItem { let item: any Item }

    private func push(_ boxed: BoxedItem, to stack: PushStack) {
        let item = boxed.item
        // Refuse an oversized push at the boundary: an item too large by itself,
        // or one that would exceed the stack's depth, is replaced by an
        // ErrorItem on .error while the surrounding instruction's other results
        // push normally. .error (and the planned .memory) are exempt so overflow
        // reports can always land.
        if stack.enforcesSizeLimits {
            if let message = self.overflow(of: item) {
                self.place(ErrorItem(message, kind: .sizeRefusal).observed(by: nil, recording), on: .error)
                return
            }
            if (self.stacks[stack]?.count ?? 0) >= config.maxStackDepth {
                self.place(ErrorItem(".\(stack) is full at maxStackDepth \(config.maxStackDepth)",
                                     kind: .sizeRefusal).observed(by: nil, recording), on: .error)
                return
            }
        }
        guard self.requireAccepts(item, on: stack) else { return }
        // No provenance stripping here: with `recordsProvenance` off, Behaviors never
        // build a `call` in the first place (every provenance expression is written
        // inside `recording(…)`; see `ProvenanceRecording`), so there is nothing to
        // strip. `Provenance Off Parity Tests` holds the whole language to that.
        // An item loaded from outside keeps whatever `call` it was handed.
        self.place(self.elidingOverBudgetProvenance(self.clampingIterations(item)), on: stack)
    }


    /// Guard for a behavior that *reads* an item's `crux()` (its call tree) to do its
    /// work — e.g. the planned `codeFuncFrom_Crux` (Roadmap #23), which turns a stack
    /// item's crux into a runnable function. Such a behavior is only meaningful in a
    /// call-active interpreter; if it runs with `recordsProvenance` off, every crux it
    /// could read is trivial (`[self]`), so it cannot do its job. This records a
    /// `PROVENANCE:` warning on `.error` and returns `false`, so the caller can no-op
    /// instead of silently producing a wrong result. No behavior needs it yet; it is the
    /// contract the first crux-consuming behavior will use:
    ///
    ///     guard requiresProvenance(name) else { return [] }
    func requiresProvenance(_ name: PushInstruction) -> Bool {
        guard !config.recordsProvenance else { return true }
        stacks[.error]?.prepend(ErrorItem(
            "\(Interpreter.provenanceMarker) \(name.rawValue) needs call-tree provenance, which is disabled (recordsProvenance = false)"))
        return false
    }


    /// Drops an item's `call` once its crux would be longer than `maxCallWeight`
    /// (or its history deeper than `maxCallDepth`), returning the item otherwise
    /// untouched, or, if only its tree was over, weighed as its crux.
    ///
    /// `callWeight` sums the tree, which counts a shared node once per use, so a
    /// history built by non-destructive reads (each value from the two before it)
    /// weighs fib(N) after N steps. Over budget as a tree, it is measured as the
    /// crux, which builds each shared node once (`CruxSharing`): if that fits, the
    /// item is kept and weighed by its crux's length, so its descendants sum real
    /// lengths and the walk is repeated only near the real budget. The measure is
    /// a function of the history alone, so a replay decides the same way.
    ///
    /// Deliberately not an error, and deliberately not a refusal — unlike
    /// `overflow(of:)`, which rejects the push. The item is still perfectly
    /// good; only its history is too expensive to keep. The history is replaced by
    /// a single **elided stand-in** (`StandInItem`, `.intAdd_elidedAs_4537`): a
    /// literal that reproduces the value, names the instruction that produced it,
    /// and says the history was dropped, so the loss is visible and countable
    /// rather than indistinguishable from a literal in the program. Weight 2 and
    /// depth 1, so it never trips the budget again.
    ///
    /// The last resort, not the plan: every elision the round-trip fuzz used to
    /// see was a shared history, and sharing removed them all (Roadmap §P, step 3).
    ///
    /// This is the honest-growth backstop: the provenance law removes the
    /// spurious growth and `IteratorItem` folds loop counters, but a value that
    /// genuinely accumulates (`x 1 .intAdd` in a loop body that is not the loop's
    /// own counter) has a truthfully linear history that no rule can shrink.
    ///
    /// `BehaviorWithSideEffects` writes some stacks directly and bypasses this,
    /// which is acceptable: those behaviors (`deepDup`, `shove`) are
    /// provenance-transparent under law 1, so they cannot grow a `call`.
    func elidingOverBudgetProvenance(_ item: any Item) -> any Item {
        if item.callDepth <= config.maxCallDepth {
            guard item.callWeight > config.maxCallWeight else { return item }
            // The tree is over budget, but the crux builds each shared node once
            // (`CruxSharing`), so it can be far shorter. Measured only now, and at
            // a cost of at most the budget.
            if let program = CruxSharing.crux(of: item, limit: config.maxCallWeight) {
                // Kept, and weighed as what it is: a crux this long. Its
                // descendants then sum real lengths, not the tree's, so the walk
                // is repeated only near the real budget.
                return (item as? any HoldsCall)?.remeasured(weight: program.count) ?? item
            }
        }
        var lightened = item
        lightened.call = [StandInItem(standingInFor: item, source: Self.producer(in: item.call), reason: .elided)]
        return lightened
    }

    /// The instruction that produced an item, read off its `call`: the last
    /// element when it is an instruction (postfix, provenance law 3), else the
    /// first (prefix, law 3b), else `nil`. Names the cause on an elided stand-in.
    static func producer(in call: [any Item]) -> PushInstruction? {
        if let last = call.last?.exactly(InstructionItem.self) { return last.value }
        return call.first?.exactly(InstructionItem.self)?.value
    }

    /// Holds a loop to `maxIterations` passes, the third budget beside
    /// `maxItemWeight` and `maxCallWeight` and enforced in the same place.
    ///
    /// **Clamped, not refused, and not moduloed.** Refusing would be the
    /// `overflow(of:)` treatment, but nothing here is impossible — the loop can
    /// run, just not as far as it claimed. And modulo, the old `.execDoFew` trick,
    /// is chaotic: it maps 100 passes to 0. Clamping is monotone, so a search can
    /// still climb toward the loop it wants (Design Principles §12).
    ///
    /// This works at the push boundary only because the clamp is **idempotent**: a
    /// clamped iterator is a fixed point, so `crux()` reconstructs one and pushing
    /// it again changes nothing.
    ///
    /// Counted and repeating loops only. A collection's length is a fact rather
    /// than a claim; `maxVectorLength`/`maxStringLength` bound those.
    func clampingIterations(_ item: any Item) -> any Item {
        guard
            let iterator = item.exactly(IteratorItem.self),
            let held = iterator.clamped(toPasses: config.maxIterations, recording: recording)
        else { return item }
        return held
    }

    /// Enforces the homogeneity invariant for any stack write. Every stack
    /// except `.exec` accepts a single Item type, so a rejected item can only
    /// mean a mis-tagged `Router` or mis-typed setup — a bug, not normal input.
    ///
    /// Rather than trap (which would abort the whole process — a DoS for a Runner
    /// on untrusted programs, and impossible to attribute while fuzzing), it
    /// records a distinctive `INVARIANT:` ErrorItem and returns `false` so the
    /// caller skips the bad push. Refusing the push *preserves* the homogeneity
    /// invariant, so the `as!` casts throughout the Behaviors stay safe. Fuzzers
    /// and regression tests assert no `INVARIANT:` marker ever appears.
    static let invariantMarker = "INVARIANT:"

    @discardableResult
    func requireAccepts(_ item: any Item, on stack: PushStack) -> Bool {
        guard stack.accepts(item) else {
            self.place(ErrorItem("\(Interpreter.invariantMarker) \(type(of: item)) rejected by .\(stack) stack",
                                 kind: .invariant).observed(by: nil, recording), on: .error)
            return false
        }
        return true
    }

    func pushItem(_ item: Router) {
        self.push(item.item, to: item.stack)
    }

    // MARK: - Weight-accounted stack mutation
    //
    // Every path that adds or removes stack items goes through one of these, so the
    // running `liveWeight` total stays exact without re-summing. `Item.weight` is
    // content (never `call`), fixed for an item's stack lifetime, so the per-item delta
    // is exact. `recomputeLiveWeight()` re-anchors the total at run start and after any
    // bulk stack replacement, so an unaccounted poke (e.g. a test assigning a stack
    // directly) is corrected before the next run rather than drifting.

    /// Full O(all items) recomputation of `liveWeight`. Cheap because it runs once at
    /// run start, not per step.
    func recomputeLiveWeight() {
        var total = 0
        for stack in PushStack.allStacks {
            for item in stacks[stack] ?? [] { total = total.addingReportingOverflow(item.weight).0 }
        }
        liveWeight = total
    }

    /// Prepend one item to a stack. Through a `BoxedItem`, for the reason given
    /// there: specialized on a bare `any Item`, the body re-boxed every boxed item.
    @inline(__always)
    func place(_ item: any Item, on stack: PushStack) {
        place(BoxedItem(item: item), on: stack)
    }

    private func place(_ boxed: BoxedItem, on stack: PushStack) {
        guard stacks[stack] != nil else { return }
        liveWeight = liveWeight.addingReportingOverflow(boxed.item.weight).0
        stacks[stack]!.prepend(boxed.item)
    }

    /// Prepend several items to a stack, front-to-back (as `prepend(contentsOf:)`).
    func place(contentsOf items: [any Item], on stack: PushStack) {
        guard stacks[stack] != nil else { return }
        stacks[stack]!.prepend(contentsOf: items)
        for item in items { liveWeight = liveWeight.addingReportingOverflow(item.weight).0 }
    }

    /// Insert one item at `index` within a stack.
    func insert(_ item: any Item, at index: Int, on stack: PushStack) {
        guard stacks[stack] != nil else { return }
        stacks[stack]!.insert(item, at: index)
        liveWeight = liveWeight.addingReportingOverflow(item.weight).0
    }

    /// Remove and return the top item of a stack, or nil if empty.
    @discardableResult
    func takeFirst(from stack: PushStack) -> (any Item)? {
        guard let item = stacks[stack]?.popFirst() else { return nil }
        liveWeight = liveWeight.subtractingReportingOverflow(item.weight).0
        return item
    }

    /// Remove the top `n` items of a stack (clamped to its count).
    func takeFirst(_ n: Int, from stack: PushStack) {
        // Reads and removal both go through the subscript, never through a local
        // copy of the deque: a second reference alive at the mutation would force
        // copy-on-write to duplicate the whole stack.
        let count = Swift.min(Swift.max(0, n), stacks[stack]?.count ?? 0)
        guard count > 0 else { return }
        liveWeight = liveWeight.subtractingReportingOverflow(stacks.weight(ofTop: count, on: stack)).0
        stacks[stack]!.removeFirst(count)
    }

    /// Take the top `count` items of a stack off `liveWeight` without removing them:
    /// the first half of `takeFirst(_:from:)`, for `Behavior.act`, which removes them
    /// itself once it has read them. `count` must not exceed the stack's depth.
    func unweigh(top count: Int, of stack: PushStack) {
        liveWeight = liveWeight.subtractingReportingOverflow(stacks.weight(ofTop: count, on: stack)).0
    }

    /// Remove and return the item at `index` within a stack, or nil if out of range.
    @discardableResult
    func take(at index: Int, from stack: PushStack) -> (any Item)? {
        // In place, for the reason given at `takeFirst(_:from:)`.
        guard index >= 0, index < stacks[stack]?.count ?? 0 else { return nil }
        let item = stacks[stack]!.remove(at: index)
        liveWeight = liveWeight.subtractingReportingOverflow(item.weight).0
        return item
    }

    /// Remove every item from a stack.
    func clear(_ stack: PushStack) {
        guard let count = stacks[stack]?.count, count > 0 else { return }
        liveWeight = liveWeight.subtractingReportingOverflow(stacks.weight(ofTop: count, on: stack)).0
        stacks[stack]!.removeAll()
    }

    func load(inputs: [PushInstruction:any Item] = [:],
              constants: [PushInstruction:any Item] = [:],
              stacks initial: [PushStack: [any Item]] = [:],
              program: [any Item] = [],
              recorders: [AnyRecorder] = []) {
        // settings reset
        self.counter = 0
        self.lastRunawayCheck = -1

        // inputs and constants (both keyed by instruction token)
        for (key,value) in inputs {
            self.inputs[key] = value
        }
        loadConstants(constants)

        // initial stack items if any — starting from empty stacks. A fresh
        // interpreter already has them, so only a reused one pays for new ones.
        if PushStack.allCases.contains(where: { !(self.stacks[$0]?.isEmpty ?? true) }) {
            self.stacks = PushStack.emptyStacks()
        }
        for (stack, items) in initial {
            let accepted = items.filter { self.requireAccepts($0, on: stack) }
            self.stacks[stack]!.prepend(contentsOf: accepted)
        }
        
        // program to run
        self.program = program
        self.stacks[.exec]!.prepend(contentsOf: program)

        for r in recorders {
            self.recorders[r.name] = r
        }
        // Anchor the incremental total to the freshly-loaded stacks.
        self.recomputeLiveWeight()
    }
    
    func record() {
        // Iterate values, not keys: `recorders[key]?.record` would mark the dictionary
        // as mutated and COW-copy its storage every step. `record` is non-mutating (the
        // recorder's state is in a class box), so reading each value and recording
        // through it copies nothing. See `AnyRecorder`.
        for recorder in everyStepRecorders {
            recorder.record(interpreter: self)
        }
        if !deferringFinalOnly { recordFinalOnly() }
    }

    private func recordFinalOnly() {
        for recorder in finalOnlyRecorders {
            recorder.record(interpreter: self)
        }
    }

    func step() {
        if counter < config.stepLimit && !stacks[.exec]!.isEmpty {
            let nextItem = self.takeFirst(from: .exec)
            // Exact-type tests rather than `is` casts: see `PushStack.accepts`.
            let nextType = nextItem.map { type(of: $0) }
            if nextType == CodeItem.self {
                // Code is data until a program asks for it: a block met on
                // `.exec` comes to rest on `.code` intact, rather than having its
                // contents scattered back onto `.exec` to run. `.codeDo` is the
                // only thing that unwraps one now — that used to happen here, on
                // sight (see `codeDo_Behavior`, which is the old `unwrapCodeItem`).
                //
                // Keeping the block whole is also what lets its `call` survive:
                // unwrapping here used to discard it, so an `.input` bound to a
                // block lost its provenance the moment it scattered.
                self.push(nextItem!, to: .code)
            } else if let action = nextItem?.exactly(InstructionItem.self)?.value {
                if let behavior = self.behaviors[action] {
                    behavior.act(on: self)
                } else {
                    // an enumerated instruction with no registered behavior
                    // (e.g. planned-but-unimplemented) must not crash the loop
                    self.push(
                        ErrorItem("\(action) is an unknown instruction").observed(by: action, recording),
                        to: .error
                    )
                }
            } else if let standIn = nextItem?.exactly(StandInItem.self) {
                // A stand-in runs as the literal it replaces, and that literal's
                // history is the stand-in, so a replay reproduces the original
                // item exactly. See `StandInItem`.
                self.pushDefault(standIn.released(recording))
            } else {
                self.pushDefault(nextItem!)
            }
        }
        self.record()
        self.counter += 1
        self.enforceRunawayGuard()   // stop early on a confirmed runaway loop
        self.enforceMemoryGuard()    // stop early on total live weight, however few the items
        // catch thrown errors from instructions
        // enforce config size limits
    }

    func run(inputs: [PushInstruction:any Item],
             stacks initial: [PushStack: [any Item]],
             program: [any Item],
             stepLimit: Int? = nil) {

        load(inputs: inputs, stacks: initial, program: program)
        self.run(stepLimit: stepLimit)
    }

    /// Runs until `.exec` empties or the step limit is reached.
    ///
    /// Passing `stepLimit` **rewrites this interpreter's `config`**, and it stays
    /// rewritten: it is this instance's limit from here on, not a loan for the
    /// duration of one call. Omitting it leaves `config.stepLimit` alone, which is
    /// what a caller that configured the interpreter up front (`Runner`, say, from
    /// its `RunnerConfiguration`) wants — an unasked-for argument must not
    /// silently overwrite a setting someone else chose.
    ///
    /// That is why the parameter is optional rather than defaulting to
    /// `defaultSettings.stepLimit`: "not given" and "given the default value" are
    /// different instructions, and only the second should touch `config`.
    func run(stepLimit: Int? = nil) {
        if let stepLimit { self.config.stepLimit = stepLimit }
        // Anchor to the current stacks: a caller may have set them up directly (many
        // tests do) since the last load, so the incremental total starts exact here.
        self.recomputeLiveWeight()
        let firstStep = counter
        deferringFinalOnly = true
        defer { deferringFinalOnly = false }
        while counter < config.stepLimit && !stacks[.exec]!.isEmpty {
            // Bail promptly when the evaluating task is cancelled (e.g. the search was
            // paused), rather than draining the whole step budget. The run is
            // nonisolated and runs inside the fan-out's child task, so this reflects
            // that task's cancellation. Asked every 256 steps rather than every step,
            // where it was about 3% of step time; a cancelled run is abandoned, so
            // when it stops changes no result.
            if counter & 0xFF == 0, Task.isCancelled { break }
            self.step()
        }
        // The reading each `.finalOnly` recorder would have taken after the last
        // step, taken once. No step, no reading, exactly as when each step recorded.
        if counter > firstStep { recordFinalOnly() }
    }

    func reset() {
        self.counter = 0
        self.lastRunawayCheck = -1
        self.stacks = PushStack.emptyStacks()
        self.liveWeight = 0
        for recorder in self.recorders.values {
            recorder.reset()
        }
    }
    
}


nonisolated extension Interpreter {
    
    /// Routes a literal popped off `.exec` to its own stack. `step` intercepts
    /// `CodeItem` and `InstructionItem` before this is reached, so the `.error`
    /// fallback catches only items that rest nowhere — which reaching here at
    /// all would mean a mis-tagged Router.
    func pushDefault(_ it: any Item) {
        self.push(it, to: PushStack.defaultStack(for: it) ?? .error)
    }
}


nonisolated extension Interpreter {
    static func reportBehaviorCoverage() -> String {
        var result = "Behavior Coverage:\n"
        result += "Defined: \(Interpreter.language.keys.count)\n"
        result += "Planned: \(PushInstruction.allCases.count)\n"
        let done = Set(Interpreter.language.keys)
        let needed = Set(PushInstruction.allCases)
        let missing = needed.subtracting(done)
        result += "Missing:\n\(missing)\n"
        return result
    }
}

