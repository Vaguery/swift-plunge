//
//  Stack Family Behaviors.swift
//  Plunge
//
//  Created by Bill Tozier on 6/11/26.
//
//  The family generated for every stack from one template: copying (`Dup`,
//  `DupItems`, `DupTimes`, `DeepDup`, `YankDup`), deleting (`Pop`, `PopItems`,
//  `Flush`, `DeleteAtDepth`), reordering (`Swap`, `Rot`, `Yank`, `Shove`), and
//  the two measurements `StackDepth` and `StackIsEmpty`. Earlier Push
//  implementations called this whole loop "combinators"; here the word belongs
//  to the `stackCombinator` tag, which counts only the rearrangements.
//

import DequeModule

nonisolated extension Interpreter {

    /// The fourteen stacks that get generated families — the furniture here, and the
    /// `…Eq` comparisons in `Comparison Behaviors.swift`.
    ///
    /// **The channels, `.error` and `.print`, are deliberately absent.** They get no
    /// generated family at all, because a program that could pop or reorder what it
    /// has emitted could hide a failed instruction, or edit its answer, out of sight
    /// of whatever scores it. `.error`'s counting instructions are the only read-only
    /// exceptions (see `Introspection Behaviors.swift`); `.print` has none.
    ///
    /// Shared rather than written twice, so the two factories cannot drift apart
    /// about which stacks exist.
    static let generatedFamilyStacks: [PushStack] = [
        .bool,
        .int,
        .double,
        .char,
        .string,
        .code,
        .exec,
        .vecInt,
        .vecBool,
        .vecDouble,
        .vecString,
        .iterator,
        .binding,
        .function
    ]

    static var stackFamilyBehaviors: [PushInstruction: Behavior] {
        var result: [PushInstruction: Behavior] = [:]

        for s in generatedFamilyStacks {
            result.merge(
                stackFamily(for: s),
                uniquingKeysWith: { (first, _) in first }
            )
        }

        return result
    }

    static func deepDupFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)DeepDup")!
        /// Copies the item `n` up from the bottom and puts the copy beside it.
        /// It reorders and copies `stack` without popping it, so it needs two items
        /// there (with one, there is nothing to reach past) and takes only its index.
        inst = Behavior.structural(name, on: stack, takes: [.int], needs: 2) { args, view in
            let range = view.count - 1
            let idx = range - Position.item((args[0] as! IntItem).value, count: view.count)
            return .positions(.copy(from: idx, to: idx))
        }
        .described(
            "Copies the \(stack.noun) i up from the bottom (0 is the bottom) and puts the copy just above it;"
            + " i is clamped into the stack."
        )
        result[name] = inst
    }

    static func dupFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Dup")!
        inst = Behavior.structural(name, on: stack, needs: 1) { _, _ in .positions(.copy(from: 0, to: 0)) }
        .described("Copies the top \(stack.noun).")
        result[name] = inst
    }

    /// Copies the top `n` items of a stack back onto it, **one per pass**.
    ///
    /// It used to push them all at once. Now it takes a copy of the slice, boxes
    /// it in a CodeItem, and walks that — which is to say `.execDupItems` is, in
    /// essence, a first `.codeIterate`: the machinery for iterating a code block's
    /// contents is exactly the machinery for handing back a stack's top few.
    ///
    /// The box holds the slice **bottom-to-top**, i.e. the order a program would
    /// have written those items in, so walking it front-to-back lands them in
    /// their original order.
    ///
    /// Provenance: a dup changes no value, so law 1 applies and the copies keep
    /// their own `call` untouched. That is why this family needs no `Nth` to
    /// explain its copies.
    static func dupItemsFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)DupItems")!
        // n clamped to the whole stack, as `PopItems` clamps it. (Until
        // 2026-11-09 it stopped one short, so a whole stack could not be copied.)
        inst = Behavior.structural(name, on: stack, takes: [.int]) { args, view in
            let number = min(view.count, max((args[0] as! IntItem).value, 0))
            guard view.count > 0, number > 0 else { return .unchanged }
            let box = CodeItem(Array(view.top(number).reversed()))
            return .loop(Interpreter.iteratorLoop(
                kind: .elements(into: stack.isHeterogeneous ? stack : nil),
                origin: box,
                body: nil,
                emits: true, recording: view.recording
            ))
        }
        .described(
            "Copies the top n \(stack.plural), keeping their order;"
            + " n is clamped between 0 and the depth."
        )
        result[name] = inst
    }

    /// Copies the top item of a stack `count` times, **one per pass**.
    ///
    /// This is the instruction that made the case for the whole "nothing explodes"
    /// principle. It used to push all `count` copies at once, which is ridiculous
    /// for large counts — so ridiculous it grew **its own `maxStackDepth` check**,
    /// the only bespoke size guard in the language, and refused outright rather
    /// than doing any of the work.
    ///
    /// **That guard is gone.** A repeating iterator does the copying over `count`
    /// passes, so `stepLimit`, `maxStackDepth` at the push boundary, and the
    /// runaway guard govern it exactly as they govern any other loop, with no
    /// special pleading. `10_000` copies is now a long loop rather than an error —
    /// it fills the stack and reports *that*, which is the truth. If you find
    /// yourself writing a size check for one instruction, you have found a loop in
    /// disguise.
    ///
    /// Provenance: a dup changes no value, so law 1 applies and every copy keeps
    /// the original's `call` untouched.
    static func dupTimesFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)DupTimes")!
        // It copies `stack` without popping it, so it needs one item there.
        inst = Behavior.structural(name, on: stack, takes: [.int], needs: 1) { args, view in
            let howMany = (args[0] as! IntItem).value
            // A non-positive count is a clamp to zero copies.
            guard howMany > 0, let item = view.item(at: 0) else { return .unchanged }
            return .loop(Interpreter.iteratorLoop(
                kind: .repeating(into: stack.isHeterogeneous ? stack : nil),
                origin: item,
                destination: IntItem(howMany),
                body: nil,
                emits: true, recording: view.recording
            ))
        }
        .described("Pushes n more copies of the top \(stack.noun); n ≤ 0 copies nothing.")
        result[name] = inst
    }

    static func stackIsEmptyFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)StackIsEmpty")!
        inst = Behavior.contextRead(name, observes: [stack], produces: .results([.bool])) { _, context in
                let empty = context.depth(of: stack) == 0
                return [
                    Router(
                        .bool,
                        // Provenance law 4b (Items.swift): this reads transient
                        // execution state, not arguments, so it records a
                        // stand-in (`«observed .boolStackIsEmpty: true»`): the
                        // literal, marked as observed. Naming the instruction
                        // would reconstruct to whatever a *fresh* interpreter's
                        // stack held.
                        BoolItem(empty).observed(by: name, context.recording)
                    )
                ]
        }
        .described("Pushes true when there are no \(stack.plural), false otherwise.")
        result[name] = inst
    }

    static func flushFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Flush")!
        inst = Behavior.structural(name, on: stack) { _, view in .positions(.delete(top: view.count)) }
        .described("Discards every \(stack.noun).")
        result[name] = inst
    }

    static func popFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Pop")!
        inst = Behavior.structural(name, on: stack, needs: 1) { _, _ in .positions(.delete(top: 1)) }
        .described("Discards the top \(stack.noun).")
        result[name] = inst
    }

    //  `PopItems` discards the top N items of its stack, leaving the item that
    //  was N deep on top. This is how a `crux()` selects one result of an
    //  instruction that produced several on the same stack: the selected item's
    //  `index` is exactly the number of pops needed to surface it. See the
    //  provenance law in Items.swift.
    //
    static func popItemsFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)PopItems")!
        // Clamped rather than an error, like its `DupItems`/`Yank` siblings: a
        // count past the bottom empties the stack.
        inst = Behavior.structural(name, on: stack, takes: [.int]) { args, view in
            .positions(.delete(top: Position.gap((args[0] as! IntItem).value, count: view.count)))
        }
        .described("Discards the top n \(stack.plural); n is clamped between 0 and the depth.")
        result[name] = inst
    }

    static func rotFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Rot")!
        // The third item comes to the top: `x y z` (top first) becomes `z x y`.
        inst = Behavior.structural(name, on: stack, needs: 3) { _, _ in .positions(.move(from: 2, to: 0)) }
        .described("Moves the third \(stack.noun) from the top up to the top, above the other two.")
        result[name] = inst
    }

    static func shoveFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Shove")!
        // With the top item taken, `c` remain and there are c+1 places to put it
        // back, 0 (the top) to c (the bottom): a gap, clamped. So `n .xShove`
        // undoes `n .xYank`. (It used to clamp to 0…c−1, which never reached the
        // bottom and made it a no-op on two items.)
        inst = Behavior.structural(name, on: stack, takes: [.int], needs: 1) { args, view in
            .positions(.move(from: 0, to: Position.gap((args[0] as! IntItem).value, count: view.count - 1)))
        }
        .described(
            "Moves the top \(stack.noun) down to depth i"
            + (stack == .int ? " (counted once i is popped)" : "")
            + ", clamped into the stack; undoes `i .\(type)Yank`."
        )
        result[name] = inst
    }

    static func stackDepthFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)StackDepth")!
        inst = Behavior.contextRead(name, observes: [stack], produces: .results([.int])) { _, context in
                let c = context.depth(of: stack)
                return [
                    Router(
                        .int,
                        // Provenance law 4b (Items.swift): a reading of
                        // transient execution state records a stand-in
                        // (`«observed .intStackDepth: 4»`), the literal count
                        // marked as observed. The instruction name would
                        // reconstruct to whatever a fresh interpreter held.
                        IntItem(c).observed(by: name, context.recording)
                    )
                ]
        }
        .described("Pushes how many \(stack.plural) there are.")
        result[name] = inst
    }

    // swap restructures the `type` stack, but does not affect argument state
    // and therefore has no effect on `call`.
    //
    static func swapFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Swap")!
        inst = Behavior.structural(name, on: stack, needs: 2) { _, _ in .positions(.move(from: 1, to: 0)) }
        .described("Swaps the top two \(stack.plural).")
        result[name] = inst
    }

    static func yankFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Yank")!
        // It reorders `stack` without popping it, so it takes only its index and
        // needs two items there: with one, there is nothing to reach past.
        inst = Behavior.structural(name, on: stack, takes: [.int], needs: 2) { args, view in
            .positions(.move(from: Position.item((args[0] as! IntItem).value, count: view.count), to: 0))
        }
        .described(
            "Moves the \(stack.noun) at depth i"
            + (stack == .int ? " (counted once i is popped)" : "")
            + " to the top; i is clamped into the stack."
        )
        result[name] = inst
    }

    /// Deletes the item at a depth, the index clamped as `Yank`'s is: weakening
    /// anywhere in the stack, where `Pop` is weakening at the top.
    static func deleteAtDepthFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let name = PushInstruction(rawValue: "\(stack.rawValue)DeleteAtDepth")!
        result[name] = Behavior.structural(name, on: stack, takes: [.int], needs: 1) { args, view in
            .positions(.remove(at: Position.item((args[0] as! IntItem).value, count: view.count)))
        }
        .described(
            "Deletes the \(stack.noun) at depth i"
            + (stack == .int ? " (counted once i is popped)" : "")
            + "; i is clamped into the stack."
        )
    }

    static func yankDupFamily_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)YankDup")!
        inst = Behavior.structural(name, on: stack, takes: [.int], needs: 2) { args, view in
            .positions(.copy(from: Position.item((args[0] as! IntItem).value, count: view.count), to: 0))
        }
        .described(
            "Copies the \(stack.noun) at depth i"
            + (stack == .int ? " (counted once i is popped)" : "")
            + " onto the top; i is clamped into the stack."
        )
        result[name] = inst
    }

    static func stackFamily(for stack: PushStack) -> [PushInstruction: Behavior] {
        var result: [PushInstruction: Behavior] = [:]

        deepDupFamily_Behavior(for: stack, into: &result)
        dupFamily_Behavior(for: stack, into: &result)
        dupItemsFamily_Behavior(for: stack, into: &result)
        dupTimesFamily_Behavior(for: stack, into: &result)
        stackIsEmptyFamily_Behavior(for: stack, into: &result)
        // `…Eq` is generated per stack too, but it is a comparison, not part of the
        // family: `eqComparison_Behavior` in `Comparison Behaviors.swift`.
        flushFamily_Behavior(for: stack, into: &result)
        popFamily_Behavior(for: stack, into: &result)
        popItemsFamily_Behavior(for: stack, into: &result)
        rotFamily_Behavior(for: stack, into: &result)
        shoveFamily_Behavior(for: stack, into: &result)
        stackDepthFamily_Behavior(for: stack, into: &result)
        swapFamily_Behavior(for: stack, into: &result)
        yankFamily_Behavior(for: stack, into: &result)
        yankDupFamily_Behavior(for: stack, into: &result)
        deleteAtDepthFamily_Behavior(for: stack, into: &result)

        return result
    }
}
