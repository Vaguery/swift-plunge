//
//  Behavior.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/30/26.
//

import DequeModule
import Foundation


nonisolated class Behavior: @unchecked Sendable {
    // @unchecked: Behavior is non-final (BehaviorWithSideEffects subclasses it),
    // so Sendable cannot be checked automatically. All stored state is immutable
    // (`let`) and Sendable and the stored closures are `@Sendable`, so a single
    // shared instance is safe to run from many interpreters/tasks at once.
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

    let transformer: @Sendable ([any Item]) -> [Router]


    /// The common form: consume one item from each of `takes`, and require —
    /// without consuming — `alsoNeeds` more.
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
        fxn: @escaping @Sendable ([any Item]) -> [Router]
    ) {
        // `takes` first: an index is popped before the stack it indexes into is
        // measured, so `intYank`'s index is `.int[0]` and its targets are `[1]`,`[2]`.
        // Sorted so the ordering does not depend on Dictionary's iteration order.
        self.init(
            label,
            requires: takes.map { Requirement.takes($0) }
                + alsoNeeds.sorted { "\($0.key)" < "\($1.key)" }
                    .map { Requirement.needs($0.key, count: $0.value) },
            fxn: fxn
        )
    }

    /// The non-destructive query form: **read** one item from each of `reads`,
    /// examine it, leave it on the stack. The transformer receives the read items
    /// (in order) exactly as `takes:` would hand over consumed ones — the only
    /// difference is that they survive.
    ///
    /// A query result must record its cleanup with `Behavior.reading(_:from:)` so
    /// its crux reproduces only the fact; the read itself leaves no provenance on
    /// the argument (law 1b — reading does not change it).
    convenience init(
        _ label: PushInstruction,
        reads: [PushStack],
        fxn: @escaping @Sendable ([any Item]) -> [Router]
    ) {
        self.init(label, requires: reads.map { Requirement.reads($0) }, fxn: fxn)
    }

    /// The general form, for a Behavior whose requirements are not all static.
    init(
        _ label: PushInstruction,
        requires: [Requirement],
        fxn: @escaping @Sendable ([any Item]) -> [Router]
    ) {
        self.name = label
        self.requirements = requires
        self.transformer = fxn
    }


    /// What this Behavior would need of an interpreter, resolved against its
    /// actual state. The `Planner` is the thing that knows how to look; this just
    /// asks.
    func plan(on interpreter: Interpreter) -> GatherPlan {
        Planner(for: interpreter).plan(requirements)
    }


    func isSatisfied(by interpreter: Interpreter) -> Bool {
        if case .ready = plan(on: interpreter) { true } else { false }
    }


    func distribute(to interpreter: Interpreter, items: [Router]) {
        for i in items {
            interpreter.push(i.item, to: i.stack)
        }
    }


    /// The single seam subclasses vary: pure behaviors run their `transformer`,
    /// while `BehaviorWithSideEffects` mutates the interpreter directly. Keeping
    /// this apart from `act` lets the surrounding pipeline — arg-gathering,
    /// distribution, and future Interpreter-mode hooks — be written just once.
    func computeResults(from arguments: [any Item], on interpreter: Interpreter) -> [Router] {
        self.transformer(arguments)
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
    final func act(on interpreter: Interpreter) {
        let planner = Planner(for: interpreter)
        switch planner.plan(requirements) {
        case .short(let stack):
            self.distribute(
                to: interpreter,
                items: [Router(.error, ErrorItem("\(self.name) missing args: .\(stack)"))]
            )
        case .ready(let arguments, let claims):
            planner.commit(claims)
            self.distribute(
                to: interpreter,
                items: self.computeResults(from: arguments, on: interpreter)
            )
        }
    }
}


// subclass for behaviors that manipulate the Interpreter state more than pop/push
nonisolated class BehaviorWithSideEffects : Behavior, @unchecked Sendable {
    // restated from Behavior: this subclass adds a stored `let directModifier`,
    // which is itself `@Sendable` and immutable, so the type stays safe to share.
    let directModifier: @Sendable (inout Interpreter, [any Item]) -> [Router]

    /// `alsoNeeds` matters most here: reaching into a stack without popping it is
    /// exactly what a `BehaviorWithSideEffects` is *for*, so it is these that could
    /// need something they never declared.
    convenience init(
        _ label: PushInstruction,
        takes: [PushStack],
        alsoNeeds: [PushStack: Int] = [:],
        modifier: @escaping @Sendable (inout Interpreter, [any Item]) -> [Router]
    ) {
        self.init(
            label,
            requires: takes.map { Requirement.takes($0) }
                + alsoNeeds.sorted { "\($0.key)" < "\($1.key)" }
                    .map { Requirement.needs($0.key, count: $0.value) },
            modifier: modifier
        )
    }

    init(
        _ label: PushInstruction,
        requires: [Requirement],
        modifier: @escaping @Sendable (inout Interpreter, [any Item]) -> [Router]
    ) {
        self.directModifier = modifier
        super.init(label, requires: requires, fxn: {_ in return []})
    }

    override func computeResults(from arguments: [any Item], on interpreter: Interpreter) -> [Router] {
        var mutableInterpreter = interpreter
        return directModifier(&mutableInterpreter, arguments)
    }
}


nonisolated extension Behavior {
    static func netContingency(of items:(any Item)...) -> Bool {
        return items.map({$0.isContingent}).contains(true)
    }


    /// The `call` for one of several results a Behavior puts on a single stack —
    /// provenance law 5 (Items.swift).
    ///
    /// `producedAt` is the result's position in the Router order, `of` is how
    /// many of this Behavior's results land on `stack`, and `from` is the source
    /// that produces them all. Because `distribute` prepends Routers one at a
    /// time, the first produced ends up deepest, so surfacing it takes
    /// `total - 1 - producedAt` pops — counted from the END of the results, not
    /// from the production order.
    ///
    /// The pops are recorded as ordinary items in the returned `call`, which is
    /// why `crux()` needs no special case for multi-result instructions: it
    /// walks the array and each element speaks for itself. The topmost result
    /// needs no discard and gets `source` unchanged.
    static func selecting(
        _ producedAt: Int,
        of total: Int,
        on stack: PushStack,
        from source: [any Item]
    ) -> [any Item] {
        let pops = total - 1 - producedAt
        guard pops > 0 else { return source }
        return source + [
            IntItem(pops),
            InstructionItem(stack.popItemsInstruction),
        ]
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
    /// without recording contingency, so the result survives untouched. Elsewhere
    /// the arguments are on top and a plain `PopItems` is enough.
    ///
    /// Live execution never runs any of this (the arguments were never removed);
    /// it exists only in the recorded `call`, so re-running the crux on a fresh
    /// interpreter leaves the fact and nothing else. Stacks are sorted for a
    /// deterministic, reproducible crux.
    static func reading(
        _ reads: [PushStack: Int],
        producing resultStack: PushStack,
        from source: [any Item]
    ) -> [any Item] {
        var result = source
        for (stack, count) in reads.sorted(by: { "\($0.key)" < "\($1.key)" }) where count > 0 {
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
