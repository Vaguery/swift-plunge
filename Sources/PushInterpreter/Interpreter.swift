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
    // value — `crux()` returns `[self]` for an empty call, and a bare literal is
    // already a runnable program producing that value. So being wrong in either
    // direction is cheap, which is exactly why the budget can afford to be
    // aggressive. See `Interpreter.elidingOverBudgetProvenance`.
    //
    // Total provenance (Item.callWeight) allowed on a single pushed item: the caps
    // above bound an item's *content*, this bounds its *history*. That used to be
    // the last unbounded dimension in the system; `maxIterations` below now holds
    // that title, since nothing bounded what a loop CLAIMS.
    public var maxCallWeight   : Int = 10_000
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

    // Whether pushed items keep their `call` provenance (the source of `crux()`).
    // Default true — the current behavior. When false, `push` strips every item's
    // `call`, so the deep provenance tree never accumulates: this is the memory/time
    // saving for a run that does not need crux for the whole population (crux is then
    // something to invoke for a *special* individual — e.g. by re-running the best
    // genome with this on). A call-less item's crux is `[self]`, a runnable literal
    // producing the same value, so turning this off never changes what a program
    // computes — only whether it can explain itself. A behavior that *reads* a crux
    // to do its work must guard with `Interpreter.requiresProvenance(_:)`.
    public var recordsProvenance = true


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
        relaxed.maxCodeDepth    = maxCodeDepth    * 1_000
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
        integrateBehaviors(fromThese: codeBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: constantBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: execBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: doubleBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: inputBehaviors, intoLanguage: &starter)
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
    
    var behaviors: [PushInstruction: Behavior] = Interpreter.language
    var stacks: [PushStack: Deque<any Item>]
    /// Running total of `Item.weight` (content) live across all stacks — maintained
    /// incrementally by the mutation helpers (`place`/`take…`/`clear`), and re-anchored
    /// by `recomputeLiveWeight()` at every run start. Lets `enforceMemoryGuard` be O(1)
    /// per step instead of re-summing all stacks; see `RunawayGuard`.
    private(set) var liveWeight: Int = 0
    var counter: Int = 0
    // Step at which the runaway guard last examined the stacks; -1 means never.
    // Throttles the (only-when-a-stack-is-deep) examination. See enforceRunawayGuard.
    var lastRunawayCheck = -1
    var inputs: [PushInstruction:any Item] = [:]
    // Bound constant values, keyed by their constant instruction (e.g. `.int3`),
    // symmetric with `inputs`. A missing key means the constant is unassigned;
    // the constant behavior emits an ErrorItem for that case at runtime, so no
    // pre-seeding of nil slots is needed.
    var constants: [PushInstruction: any Item] = [:]
    var config: InterpreterSettings = Interpreter.defaultSettings
    var program: [any Item] = []
    var printout: String = ""
    // Use AnyRecorder for type erasure of Recorder generic type
    var recorders: [String: AnyRecorder] = [:]
    var recorderNames: [String] {
        recorders.keys.sorted()
    }
    
    init(stacks: [PushStack : Deque<any Item>] = PushStack.emptyStacks()) {
        self.stacks = stacks
        self.recomputeLiveWeight()
    }

    /// The single validated entry point for pushing an item onto a stack.
    /// Every stack except `.exec` is homogeneous, so pushing an item a stack
    /// does not accept can only mean a mis-tagged `Router` (a programming bug).
    /// Trap immediately rather than corrupt the stack and defer the failure to
    /// some later `as!` in an unrelated Behavior.
    func push(_ item: any Item, to stack: PushStack) {
        // Refuse an oversized push at the boundary: an item too large by itself,
        // or one that would exceed the stack's depth, is replaced by an
        // ErrorItem on .error while the surrounding instruction's other results
        // push normally. .error (and the planned .memory) are exempt so overflow
        // reports can always land.
        if stack.enforcesSizeLimits {
            if let message = self.overflow(of: item) {
                self.place(ErrorItem(message), on: .error)
                return
            }
            if (self.stacks[stack]?.count ?? 0) >= config.maxStackDepth {
                self.place(ErrorItem(".\(stack) is full at maxStackDepth \(config.maxStackDepth)"), on: .error)
                return
            }
        }
        guard self.requireAccepts(item, on: stack) else { return }
        self.place(
            self.strippingProvenanceIfDisabled(
                self.elidingOverBudgetProvenance(self.clampingIterations(item))
            ),
            on: stack
        )
    }


    /// Drops an item's `call` when provenance recording is off (see
    /// `InterpreterSettings.recordsProvenance`). A no-op when on, or when the call is
    /// already empty. Runs last in the push pipeline, so it dominates: `clampingIterations`
    /// still bounds a loop's *state* and `elidingOverBudgetProvenance` still applies when
    /// on; when off, the history is simply gone. Value reproduction is untouched —
    /// `crux()` of a call-less item is `[self]`, and iteration is driven by an iterator's
    /// state fields, not its `call`.
    func strippingProvenanceIfDisabled(_ item: any Item) -> any Item {
        guard !config.recordsProvenance, !item.call.isEmpty else { return item }
        var stripped = item
        stripped.call = []
        return stripped
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


    /// Drops an item's `call` once its provenance exceeds `maxCallWeight`,
    /// returning the item otherwise untouched.
    ///
    /// Deliberately not an error, and deliberately not a refusal — unlike
    /// `overflow(of:)`, which rejects the push. The item is still perfectly
    /// good; only its history is too expensive to keep. Forgetting that history
    /// cannot break the reconstruction, because `crux()` returns `[self]` for an
    /// empty `call` and a bare literal already reproduces the value. So the item
    /// stops explaining where it came from and becomes a constant instead.
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
        guard item.callWeight > config.maxCallWeight else { return item }
        var lightened = item
        lightened.call = []
        return lightened
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
            let iterator = item as? IteratorItem,
            let held = iterator.clamped(toPasses: config.maxIterations)
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
            self.place(ErrorItem("\(Interpreter.invariantMarker) \(type(of: item)) rejected by .\(stack) stack"), on: .error)
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

    /// Prepend one item to a stack.
    func place(_ item: any Item, on stack: PushStack) {
        guard stacks[stack] != nil else { return }
        stacks[stack]!.prepend(item)
        liveWeight = liveWeight.addingReportingOverflow(item.weight).0
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
        guard let deque = stacks[stack] else { return }
        let count = Swift.min(Swift.max(0, n), deque.count)
        for i in 0..<count { liveWeight = liveWeight.subtractingReportingOverflow(deque[i].weight).0 }
        stacks[stack]!.removeFirst(count)
    }

    /// Remove and return the item at `index` within a stack, or nil if out of range.
    @discardableResult
    func take(at index: Int, from stack: PushStack) -> (any Item)? {
        guard let deque = stacks[stack], deque.indices.contains(index) else { return nil }
        let item = deque[index]
        liveWeight = liveWeight.subtractingReportingOverflow(item.weight).0
        stacks[stack]!.remove(at: index)
        return item
    }

    /// Remove every item from a stack.
    func clear(_ stack: PushStack) {
        guard let deque = stacks[stack] else { return }
        for item in deque { liveWeight = liveWeight.subtractingReportingOverflow(item.weight).0 }
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

        // initial stack items if any
        self.stacks = PushStack.emptyStacks()
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
        for recorder in recorders.values {
            recorder.record(interpreter: self)
        }
    }

    func step() {
        if counter < config.stepLimit && !stacks[.exec]!.isEmpty {
            let nextItem = self.takeFirst(from: .exec)
            if nextItem is CodeItem {
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
            } else if nextItem is InstructionItem {
                let action = (nextItem as! InstructionItem).value
                if let behavior = self.behaviors[action] {
                    behavior.act(on: self)
                } else {
                    // an enumerated instruction with no registered behavior
                    // (e.g. planned-but-unimplemented) must not crash the loop
                    self.push(
                        ErrorItem("\(action) is an unknown instruction"),
                        to: .error
                    )
                }
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
        while counter < config.stepLimit && !stacks[.exec]!.isEmpty {
            // Bail promptly when the evaluating task is cancelled (e.g. the search was
            // paused), rather than draining the whole step budget. `Task.isCancelled` is
            // a cheap atomic read; the run is nonisolated and runs inside the fan-out's
            // child task, so this reflects that task's cancellation.
            if Task.isCancelled { break }
            self.step()
        }
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

