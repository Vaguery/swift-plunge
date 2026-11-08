//
//  Behavior.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/30/26.
//

import DequeModule
import Foundation


nonisolated final class Behavior: Sendable {
    // Every stored property is an immutable `let` of a Sendable type, and the
    // closures in `body` are `@Sendable`, so one shared instance is safe to run
    // from many interpreters and tasks at once.
    let name: PushInstruction

    /// Everything this Behavior must find, **in order**. Order matters: each
    /// requirement claims the topmost item its predecessors have not, so
    /// `takes(.int), takes(.int)` claims index 0 then index 1 — the same two items
    /// a pair of pops would have taken.
    let requirements: [Requirement]

    /// The stacks this Behavior consumes one item from, in order. Kept because most
    /// of the language reads better as a list of stacks than a list of cases, and
    /// because a great deal of code asks for it.
    var parameters: [PushStack] {
        requirements.compactMap { if case .takes(let s) = $0 { s } else { nil } }
    }

    /// The stacks this Behavior draws on and the least it can want from each —
    /// **a lower bound, not the truth.** A `.takesMany` requirement's count depends
    /// on an argument, so no constant can state it; it contributes its stack with a
    /// count of zero.
    ///
    /// For the truth, ask `plan(on:)`, which is the only thing that knows. This
    /// exists for documentation and for analysis that wants to know *which* stacks
    /// an instruction touches without caring how many.
    var staticNeeds: [PushStack: Int] {
        var result = [PushStack: Int]()
        for requirement in requirements {
            switch requirement {
            case .takes(let s):        result[s, default: 0] += 1
            case .needs(let s, let n): result[s, default: 0] += n
            case .takesMany(let s, _): result[s, default: 0] += 0
            case .reads(let s):        result[s, default: 0] += 1
            }
        }
        return result
    }

    /// The stacks this Behavior truly **consumes** (removes items from), and the
    /// least from each. `.takes` contributes one; `.takesMany` its stack with a
    /// lower bound of zero (its count is dynamic). **Excludes `.reads`** (examined
    /// and left) and `.needs` (required and left) — neither removes anything.
    ///
    /// This is what "does instruction X consume stack S?" should mean, and it is
    /// what `Interpreter.instructions(consuming:)` is built on. `staticNeeds`
    /// answers the different question "which stacks does X draw on at all", and
    /// counts every requirement kind.
    var consumedStacks: [PushStack: Int] {
        var result = [PushStack: Int]()
        for requirement in requirements {
            switch requirement {
            case .takes(let s):        result[s, default: 0] += 1
            case .takesMany(let s, _): result[s, default: 0] += 0
            case .needs, .reads:       break
            }
        }
        return result
    }

    /// The stacks this Behavior **reads without consuming** (`.reads`) — the
    /// non-destructive queries. The complement of `consumedStacks` among the
    /// stacks an instruction actually hands to its transformer.
    var readStacks: [PushStack: Int] {
        var result = [PushStack: Int]()
        for requirement in requirements {
            if case .reads(let s) = requirement { result[s, default: 0] += 1 }
        }
        return result
    }

    /// What this Behavior's code may see and what it returns — see
    /// `BehaviorBody`. No body mutates the interpreter; `act` applies what it
    /// returns.
    let body: BehaviorBody

    /// Declared judgment about this instruction — see `InstructionTag`.
    ///
    /// **The one channel here that can be wrong**, and deliberately so: it carries
    /// what `requirements` cannot know. Empty for most instructions; a factory that
    /// generates a family tags the whole family in one line, which is better than
    /// per-instruction because there is then no way to tag eleven of twelve.
    let tags: Set<InstructionTag>

    /// What this Behavior does to the interpreter's state — see `BehaviorClass`.
    /// Declared, because mechanism does not decide it, and kept consistent with
    /// `body` by the constructors: each form fixes its class except `values`,
    /// which is an operation unless built with `Behavior.control`.
    let behaviorClass: BehaviorClass


    /// The common form: consume one item from each of `takes`, and require —
    /// without consuming — `alsoNeeds` more. An operation.
    ///
    /// `alsoNeeds` exists because `takes:` alone conflated *what I consume* with
    /// *what I need*. `doubleYank` takes an `.int` index and *reorders* `.double`;
    /// declaring `.double` in `takes:` would pop the very item it means to move. So
    /// it declared only the int — and then **60 behaviors across five families
    /// popped their index, found an empty stack, and errored having already eaten
    /// the argument** (Design Principles §14).
    ///
    /// A stack may appear in both and the counts add: `intYank` takes one `.int` as
    /// its index **and** needs two more to work on, so it wants three.
    convenience init(
        _ label: PushInstruction,
        takes: [PushStack],
        alsoNeeds: [PushStack: Int] = [:],
        tags: Set<InstructionTag> = [],
        fxn: @escaping @Sendable ([any Item], ProvenanceRecording) -> [Router]
    ) {
        self.init(label, requires: Behavior.requirements(takes: takes, alsoNeeds: alsoNeeds),
                  tags: tags, behaviorClass: .operation, body: .values(fxn))
    }

    /// The non-destructive query form: **read** one item from each of `reads`,
    /// examine it, leave it on the stack. The transformer receives the read items
    /// (in order) exactly as `takes:` would hand over consumed ones — the only
    /// difference is that they survive. An operation.
    ///
    /// A query result must record its cleanup with `Behavior.reading(_:from:)` so
    /// its crux reproduces only the fact; the read itself leaves no provenance on
    /// the argument (law 1b — reading does not change it).
    convenience init(
        _ label: PushInstruction,
        reads: [PushStack],
        tags: Set<InstructionTag> = [],
        fxn: @escaping @Sendable ([any Item], ProvenanceRecording) -> [Router]
    ) {
        self.init(label, requires: reads.map { Requirement.reads($0) },
                  tags: tags, behaviorClass: .operation, body: .values(fxn))
    }

    /// The general form, for an operation whose requirements are not all static.
    convenience init(
        _ label: PushInstruction,
        requires: [Requirement],
        tags: Set<InstructionTag> = [],
        fxn: @escaping @Sendable ([any Item], ProvenanceRecording) -> [Router]
    ) {
        self.init(label, requires: requires, tags: tags, behaviorClass: .operation, body: .values(fxn))
    }

    /// Every constructor ends here.
    init(
        _ label: PushInstruction,
        requires: [Requirement],
        tags: Set<InstructionTag>,
        behaviorClass: BehaviorClass,
        body: BehaviorBody
    ) {
        self.name = label
        self.requirements = requires
        self.tags = tags
        self.behaviorClass = behaviorClass
        self.body = body
        let plan = Behavior.directPlan(for: requires)
        self.directChecks = plan.checks
        self.directTakes = plan.takes
        self.directTakeCounts = plan.counts
    }

    /// `takes` first: an index is popped before the stack it indexes into is
    /// measured, so `intYank`'s index is `.int[0]` and its targets are `[1]`,`[2]`.
    /// Sorted so the ordering does not depend on Dictionary's iteration order.
    static func requirements(takes: [PushStack], alsoNeeds: [PushStack: Int]) -> [Requirement] {
        takes.map { Requirement.takes($0) }
            + alsoNeeds.sorted { "\($0.key)" < "\($1.key)" }
                .map { Requirement.needs($0.key, count: $0.value) }
    }

    /// The depth each requirement must find, in requirement order, for a Behavior
    /// whose requirements are all plain `.takes` and `.needs` — most of the
    /// language. `nil` otherwise. A check names its stack, so a refusal names the
    /// same stack the `Planner` would.
    ///
    /// Such a plan never depends on the stacks' contents: the k-th claim on a
    /// stack is always that stack's index k, exactly as the `Planner` would claim
    /// it. So it is worked out once here, and `act` can check depths, read the
    /// arguments, and drop them without building a plan per instruction (which
    /// profiling found was an eighth of all interpreter time).
    let directChecks: [DirectTake]?
    /// Where each consumed argument sits, for the direct path.
    let directTakes: [DirectTake]
    /// How many items each stack gives up, for the direct path.
    let directTakeCounts: [(stack: PushStack, count: Int)]


    /// What this Behavior would need of an interpreter, resolved against its
    /// actual state. The `Planner` is the thing that knows how to look; this just
    /// asks.
    func plan(on interpreter: Interpreter) -> GatherPlan {
        Planner(for: interpreter).plan(requirements)
    }


    func isSatisfied(by interpreter: Interpreter) -> Bool {
        if case .ready = plan(on: interpreter) { true } else { false }
    }


    /// The refusal for an instruction that came up short on `stack`.
    /// Recorded as observed by the instruction (a stand-in): it depends on transient
    /// stack state, so re-running the instruction on a fresh interpreter would not
    /// reproduce it (provenance law 4b).
    func missingArguments(on stack: PushStack, _ recording: ProvenanceRecording) -> Router {
        Router(.error, ErrorItem(missingArgumentsFor: self.name, on: stack).observed(by: self.name, recording))
    }

    func distribute(to interpreter: Interpreter, items: [Router]) {
        for i in items {
            interpreter.push(i.item, to: i.stack)
        }
    }


    /// Runs the body on `arguments` (already gathered and removed) and performs
    /// every effect it asks for except pushing its results, which it returns for
    /// `distribute`. Kept apart from `act` so that diagnostics can drive a
    /// Behavior's body directly.
    func computeResults(from arguments: [any Item], on interpreter: Interpreter) -> [Router] {
        switch body {
        case .values(let fxn):
            return fxn(arguments, interpreter.recording)

        case .structural(let stack, let step):
            let view = StackView(interpreter.stacks[stack] ?? [], recording: interpreter.recording)
            switch step(arguments, view) {
            case .positions(let effect): Behavior.apply(effect, to: stack, in: interpreter); return []
            case .loop(let routers):     return routers
            case .unchanged:             return []
            }

        case .contextRead(let read):
            return read(arguments, ReadContext(interpreter))

        case .control(let fxn):
            var results: [Router] = []
            for effect in fxn(arguments, interpreter.recording) {
                switch effect {
                case .result(let router):
                    results.append(router)
                case .place(let items):
                    interpreter.place(contentsOf: items, on: .exec)
                case .bury(let token, let depth, let payload):
                    Interpreter.bury(token, depth, under: payload, in: interpreter)
                }
            }
            return results

        case .channel(let write):
            switch write(arguments) {
            case .item(let item): interpreter.printItem(item)
            case .text(let text): interpreter.printText(text)
            }
            return []
        }
    }


    /// Plan; run only if the plan is `.ready`; otherwise report the refusal and
    /// take nothing.
    ///
    /// The error **names the stack that came up short** — `intAdd missing args:
    /// .int` — which is a thing it could not say until the Planner existed to be
    /// asked. Before, an error said only that something was missing, and finding
    /// out what meant reading the instruction's source. The stack the plan stopped
    /// at is the one an argument was wanted from and not found, so it is the
    /// honest answer even when several stacks are short: it is the first the
    /// Behavior would have reached for.
    ///
    /// The prefix is unchanged, so anything matching on `"missing args"` still
    /// matches.
    func act(on interpreter: Interpreter) {
        if let directChecks {
            // The same outcome the Planner reaches, without planning: refuse on the
            // first requirement that is not met, naming its stack; otherwise read
            // every argument, then take them all (each stack's claims are its top
            // n items, so dropping n is exactly what `commit` would remove).
            for check in directChecks where check.index >= interpreter.stacks[check.stack]?.count ?? 0 {
                self.distribute(to: interpreter, items: [missingArguments(on: check.stack, interpreter.recording)])
                return
            }
            // The arguments' weight is taken off `liveWeight` *before* they are
            // copied out. Reading `weight` from a stack item makes Swift project its
            // box mutably, which copies the whole item if the box is shared, as it
            // is once `arguments` holds it: a copy of every boxed argument on every
            // step (Phase 4 profile). Read first, the stack is the only owner.
            for (stack, count) in directTakeCounts { interpreter.unweigh(top: count, of: stack) }
            // Present: every index was just checked against its stack's depth.
            let arguments = ItemArray.make(count: directTakes.count) {
                interpreter.stacks.item(at: directTakes[$0].index, on: directTakes[$0].stack)!
            }
            for (stack, count) in directTakeCounts { interpreter.stacks[stack]!.removeFirst(count) }
            self.distribute(to: interpreter, items: self.computeResults(from: arguments, on: interpreter))
            return
        }

        let planner = Planner(for: interpreter)
        switch planner.plan(requirements) {
        case .short(let stack):
            self.distribute(to: interpreter, items: [missingArguments(on: stack, interpreter.recording)])
        case .ready(let arguments, let claims):
            planner.commit(claims)
            self.distribute(
                to: interpreter,
                items: self.computeResults(from: arguments, on: interpreter)
            )
        }
    }
}


nonisolated extension Behavior {
    /// The result of a Behavior that cannot produce its intended output from the
    /// arguments it was given (Roadmap #42: every Behavior returns its output or
    /// an error). `call` is recorded like a result's: the arguments and the
    /// instruction (law 3), or for a query the `reading(_:producing: .error, …)`
    /// form, so re-running it reproduces the error.
    static func refusal(_ message: String, kind: ErrorKind, call: [any Item]) -> Router {
        Router(.error, ErrorItem(message, kind: kind, call: call))
    }

    /// The `call` for one of several results a Behavior puts on a single stack —
    /// provenance law 5 (Items.swift).
    ///
    /// `producedAt` is the result's position in the Router order, `of` is how
    /// many of this Behavior's results land on `stack`, and `from` is the source
    /// that produces them all. Because `distribute` prepends Routers one at a
    /// time, the first produced ends up deepest.
    ///
    /// Running `source` puts **every** sibling on the stack, so selecting one
    /// means clearing the other `total - 1` — in both directions:
    ///
    ///  - the `total - 1 - producedAt` siblings produced *after* this one sit
    ///    above it, and a plain `PopItems` takes them;
    ///  - the `producedAt` siblings produced *before* it sit **below** it, where
    ///    a pop cannot reach without taking the result first. Each is lifted past
    ///    the result by a `swap` and then popped — the same idiom `reading` uses
    ///    to clear a read argument out from under its own result.
    ///
    /// Clearing downward is what makes the fragment composable. Without it the
    /// topmost result reproduced its own value correctly but left its siblings as
    /// debris, so the fragment was only usable in isolation: embedded as an
    /// argument, the stranded siblings shifted every argument position of the
    /// enclosing instruction (the composition invariant, Design Principles §1).
    ///
    /// The cleanup is recorded as ordinary items in the returned `call`, which is
    /// why `crux()` needs no special case for multi-result instructions: it walks
    /// the array and each element speaks for itself.
    static func selecting(
        _ producedAt: Int,
        of total: Int,
        on stack: PushStack,
        from source: [any Item]
    ) -> [any Item] {
        var result = source
        let above = total - 1 - producedAt
        if above > 0 {
            result += [IntItem(above), InstructionItem(stack.popItemsInstruction)]
        }
        for _ in 0..<max(0, producedAt) {
            result += [
                InstructionItem(stack.swapInstruction),
                InstructionItem(stack.popInstruction),
            ]
        }
        return result
    }


    /// The `call` for a **non-destructive query** result — `selecting` generalized
    /// from "several results on one stack" to "arguments read but not consumed."
    ///
    /// A query keeps its argument(s) alive at run time (`.reads`), but its crux
    /// must reproduce only the fact: a fragment that left its argument behind would
    /// be read by a same-stack sibling and corrupt it (Design Principles §6, the
    /// composition invariant). So the crux names how the fact was computed, then
    /// removes what it read. `reads` maps each stack read to how many items came
    /// off it — a comparison reads two from one stack, a search one from each of
    /// two.
    ///
    /// **The `producing` stack is why this is not just `selecting` twice.** When a
    /// read stack is *also* the result's stack (a comparison of two bools lands its
    /// bool back on `.bool`; `vecIntOccurrencesOf` reads an `.int` needle and
    /// returns an `.int`), the result sits on **top** of the arguments it read, so
    /// a plain `PopItems` would discard the result. There the crux instead swaps
    /// each argument up past the single result and pops it — `swap` moves items
    /// without recording anything, so the result survives untouched. Elsewhere
    /// the arguments are on top and a plain `PopItems` is enough.
    ///
    /// Live execution never runs any of this (the arguments were never removed);
    /// it exists only in the recorded `call`, so re-running the crux on a fresh
    /// interpreter leaves the fact and nothing else. Stacks are sorted for a
    /// deterministic, reproducible crux.
    ///
    /// `reads` is written as a dictionary literal (`[.code: 1]`) but taken as
    /// `KeyValuePairs`, which keeps the literal and skips building a hashed
    /// dictionary on every query.
    static func reading(
        _ reads: KeyValuePairs<PushStack, Int>,
        producing resultStack: PushStack,
        from source: [any Item]
    ) -> [any Item] {
        var result = source
        for (stack, count) in reads.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where count > 0 {
            if stack == resultStack {
                // The result is on top, the `count` arguments just beneath it.
                // Lift each argument past the result and pop it.
                for _ in 0..<count {
                    result += [
                        InstructionItem(stack.swapInstruction),
                        InstructionItem(stack.popInstruction),
                    ]
                }
            } else {
                // The arguments are on top of a stack the result did not touch.
                result += [IntItem(count), InstructionItem(stack.popItemsInstruction)]
            }
        }
        return result
    }
}
