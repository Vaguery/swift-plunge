//
//  Combinator Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/11/26.
//

import DequeModule

nonisolated extension Interpreter {

    /// The twelve stacks that get generated families — the furniture here, and the
    /// `…Eq` comparisons in `Comparison Behaviors.swift`.
    ///
    /// **`.error` is deliberately absent.** It gets no generated family at all,
    /// because a program that could pop or reorder its own errors could hide a
    /// failed instruction from whatever scores it; `errorStackDepth` is the single
    /// read-only exception. See `Introspection Behaviors.swift`.
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
    ]

    static var combinatorBehaviors: [PushInstruction: Behavior] {
        var result: [PushInstruction: Behavior] = [:]

        for s in generatedFamilyStacks {
            result.merge(
                combinators(for: s),
                uniquingKeysWith: { (first, _) in first }
            )
        }

        return result
    }

    static func deepDupCombinator_Behavior(
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
        result[name] = inst
    }

    static func dupCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Dup")!
        inst = Behavior.structural(name, on: stack, needs: 1) { _, _ in .positions(.copy(from: 0, to: 0)) }
        result[name] = inst
    }

    /// Copies the top `n` items of a stack back onto it, **one per pass**.
    ///
    /// It used to push them all at once. Now it takes a copy of the slice, boxes
    /// it in a CodeItem, and walks that — which is to say `execDupItems` is, in
    /// essence, a first `.codeIterate`: the machinery for iterating a block's
    /// contents is exactly the machinery for handing back a stack's top few.
    ///
    /// The box holds the slice **bottom-to-top**, i.e. the order a program would
    /// have written those items in, so walking it front-to-back lands them in
    /// their original order (principle 6).
    ///
    /// Provenance: a dup changes no value, so law 1 applies and the copies keep
    /// their own `call` untouched. That is why this family needs no `Nth` to
    /// explain its copies.
    static func dupItemsCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)DupItems")!
        inst = Behavior.structural(name, on: stack, takes: [.int]) { args, view in
            let number = min(view.count - 1, max((args[0] as! IntItem).value, 0))
            guard view.count > 0, number > 0 else { return .unchanged }
            let box = CodeItem(Array(view.top(number).reversed()))
            return .loop(Interpreter.iteratorLoop(
                kind: .elements(into: stack.isHeterogeneous ? stack : nil),
                origin: box,
                body: nil,
                emits: true, recording: view.recording
            ))
        }
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
    /// disguise (see "Notes on Push/Design Principles.md").
    ///
    /// Provenance: a dup changes no value, so law 1 applies and every copy keeps
    /// the original's `call` untouched.
    static func dupTimesCombinator_Behavior(
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
            // A non-positive count is a clamp to zero copies (Roadmap #42).
            guard howMany > 0, let item = view.item(at: 0) else { return .unchanged }
            return .loop(Interpreter.iteratorLoop(
                kind: .repeating(into: stack.isHeterogeneous ? stack : nil),
                origin: item,
                destination: IntItem(howMany),
                body: nil,
                emits: true, recording: view.recording
            ))
        }
        result[name] = inst
    }

    static func stackIsEmptyCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)StackIsEmpty")!
        inst = Behavior.contextRead(name) { _, context in
                let empty = context.depth(of: stack) == 0
                return [
                    Router(
                        .bool,
                        // Provenance law 4b (Items.swift): this reads transient
                        // execution state, not arguments, so it records a
                        // stand-in (`.boolStackIsEmpty_actuallyWas_true`): the
                        // literal, marked as observed. Naming the instruction
                        // would reconstruct to whatever a *fresh* interpreter's
                        // stack held.
                        BoolItem(empty).observed(by: name, context.recording)
                    )
                ]
        }
        result[name] = inst
    }

    // typeEq creates a new item, and demands multilevel comparison
    // between `Item` instances at all attribute levels (recursively)
    //
    static func eqCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Eq")!
        // Every Eq is a non-destructive query: it reads its two operands and
        // leaves them. (`.execEq`, the one destructive form, was removed; see
        // `comparisonBehaviors`.)
        inst = Behavior(
            name,
            requires: [Requirement.reads(stack), Requirement.reads(stack)],
            fxn: { a, recording in
                let isSame = a[0].isEqual(to: a[1])
                // The crux cleans up the two operands it read, so it reproduces
                // just the bool (`Behavior.reading`).
                return [
                    Router(
                        .bool,
                        BoolItem(
                            isSame,
                            call: recording(Behavior.reading(
                                [stack: 2],
                                producing: .bool,
                                from: [a[1], a[0], InstructionItem(name)]
                            )))
                    )
                ]
            }
        )
        result[name] = inst
    }

    static func flushCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Flush")!
        inst = Behavior.structural(name, on: stack) { _, view in .positions(.delete(top: view.count)) }
        result[name] = inst
    }

    static func popCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Pop")!
        inst = Behavior.structural(name, on: stack, needs: 1) { _, _ in .positions(.delete(top: 1)) }
        result[name] = inst
    }

    //  `PopItems` discards the top N items of its stack, leaving the item that
    //  was N deep on top. This is how a `crux()` selects one result of an
    //  instruction that produced several on the same stack: the selected item's
    //  `index` is exactly the number of pops needed to surface it. See the
    //  provenance law in Items.swift.
    //
    static func popItemsCombinator_Behavior(
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
        result[name] = inst
    }

    static func rotCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Rot")!
        // The third item comes to the top: `x y z` (top first) becomes `z x y`.
        inst = Behavior.structural(name, on: stack, needs: 3) { _, _ in .positions(.move(from: 2, to: 0)) }
        result[name] = inst
    }

    static func shoveCombinator_Behavior(
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
        result[name] = inst
    }

    static func stackDepthCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)StackDepth")!
        inst = Behavior.contextRead(name) { _, context in
                let c = context.depth(of: stack)
                return [
                    Router(
                        .int,
                        // Provenance law 4b (Items.swift): a reading of
                        // transient execution state records a stand-in
                        // (`.intStackDepth_actuallyWas_4`), the literal count
                        // marked as observed. The instruction name would
                        // reconstruct to whatever a fresh interpreter held.
                        IntItem(c).observed(by: name, context.recording)
                    )
                ]
        }
        result[name] = inst
    }

    // swap restructures the `type` stack, but does not affect argument state
    // and therefore has no effect on `call`.
    //
    static func swapCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Swap")!
        inst = Behavior.structural(name, on: stack, needs: 2) { _, _ in .positions(.move(from: 1, to: 0)) }
        result[name] = inst
    }

    static func yankCombinator_Behavior(
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
        result[name] = inst
    }

    static func yankDupCombinator_Behavior(
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
        result[name] = inst
    }

    static func combinators(for stack: PushStack) -> [PushInstruction: Behavior]
    {
        var result: [PushInstruction: Behavior] = [:]

        deepDupCombinator_Behavior(for: stack, into: &result)
        dupCombinator_Behavior(for: stack, into: &result)
        dupItemsCombinator_Behavior(for: stack, into: &result)
        dupTimesCombinator_Behavior(for: stack, into: &result)
        stackIsEmptyCombinator_Behavior(for: stack, into: &result)
        // `eqCombinator_Behavior` is NOT called here. Equality is not furniture,
        // and being generated beside dup/pop/swap is the only reason it was ever
        // roled as such. `Comparison Behaviors.swift` calls the same factory.
        flushCombinator_Behavior(for: stack, into: &result)
        popCombinator_Behavior(for: stack, into: &result)
        popItemsCombinator_Behavior(for: stack, into: &result)
        rotCombinator_Behavior(for: stack, into: &result)
        shoveCombinator_Behavior(for: stack, into: &result)
        stackDepthCombinator_Behavior(for: stack, into: &result)
        swapCombinator_Behavior(for: stack, into: &result)
        yankCombinator_Behavior(for: stack, into: &result)
        yankDupCombinator_Behavior(for: stack, into: &result)

        return result
    }
}
