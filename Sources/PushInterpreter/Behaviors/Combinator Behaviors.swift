//
//  Combinator Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/11/26.
//

import DequeModule

nonisolated extension Interpreter {
    static var combinatorBehaviors: [PushInstruction: Behavior] {
        let theseStacks: [PushStack] = [
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
        ]

        var result: [PushInstruction: Behavior] = [:]

        for s in theseStacks {
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
        inst = BehaviorWithSideEffects(
            name,
            takes: [.int],
            modifier: { (interpreter, collectedItems) in
                let rawIndex = collectedItems[0] as! IntItem
                let range = interpreter.stacks[stack]!.count - 1
                let idx = range - max(0, min(rawIndex.value, range))
                // from the "bottom"

                guard range > 0 else {
                    return [
                        Router(
                            .error,
                            ErrorItem("\(name) on empty stack")
                        )
                    ]
                }
                let oldItem = interpreter.stacks[stack]![idx]
                var newItem = oldItem
                newItem.call = [oldItem, InstructionItem(name)]
                newItem.isContingent = true
                interpreter.requireAccepts(newItem, on: stack)
                interpreter.stacks[stack]!.insert(newItem, at: idx)
                return []
            }
        )
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
        inst = Behavior(
            name,
            takes: [stack],
            fxn: { a in
                return [Router(stack, a[0]), Router(stack, a[0])]
            }
        )
        result[name] = inst
    }

    //  'DupItems` introduces some tacit contingency into execution,
    //  but it's not entirely clear if it is making these results
    //  contingent in themselves?
    //
    static func dupItemsCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)DupItems")!
        inst = BehaviorWithSideEffects(
            name,
            takes: [.int],
            modifier: { (interpreter, collectedItems) in
                let range = interpreter.stacks[stack]!.count - 1
                let rawIndex = collectedItems[0] as! IntItem
                let number = min(range, max(rawIndex.value, 0))
                if interpreter.stacks[stack]!.isEmpty == true {
                    return []
                } else {
                    let duplicates = interpreter.stacks[stack]!.prefix(number)
                    var result = [Router]()
                    for d in duplicates {
                        result.append(Router(stack, d))
                    }
                    return result.reversed()
                }
            }
        )
        result[name] = inst
    }

    //
    // \(type)DupTimes consumes an .int and tries to make that many
    // copies of the top .type item and push them _all at once_ to the
    // stack, which is ridiculous for large counts. Now it will read
    // Interpreter.config.stackCapacity and fail entirely if its action
    // would overflow the stack.
    //  'DupTimes` introduces some tacit contingency into execution,
    //  but it's not entirely clear if it is making these results
    //  contingent in themselves?
    //  TODO: work out details of this contingency definition
    //

    static func dupTimesCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)DupTimes")!
        inst = BehaviorWithSideEffects(
            name,
            takes: [.int],
            modifier: { (interpreter, collectedItems) in

                let allowedMax = interpreter.config.stackCapacity
                let howMany = (collectedItems[0] as! IntItem).value
                let rawNumber = max(howMany, 0)
                let allowed = min(rawNumber, allowedMax)
                let overflow = (rawNumber - allowed)

                var result = [Router]()

                if let item = interpreter.stacks[stack]!.first {
                    if overflow > 0 {
                        result.append(
                            Router(
                                .error,
                                ErrorItem(
                                    "\(type)DupTimes overflow: \(rawNumber) items attempted"
                                )
                            )
                        )
                    } else {
                        for _ in 0..<allowed {
                            result.append(Router(stack, item))
                        }
                    }

                    return result
                } else {
                    return [
                        Router(
                            .error,
                            ErrorItem("\(name) on empty stack")
                        )
                    ]
                }
            }
        )
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
        inst = BehaviorWithSideEffects(
            name,
            takes: [],
            modifier: { (interpreter, collectedItems) in
                let empty = interpreter.stacks[stack]!.isEmpty
                return [
                    Router(
                        .bool,
                        BoolItem(
                            empty,
                            call: [InstructionItem(name)],
                            isContingent: true
                        )
                    )
                ]
            }
        )
        result[name] = inst
    }

    // typeEq creates a new item which may be contingent, and
    // demands multilevel comparison between `Item` instances at
    // all attribute levels (recursively)
    //
    static func eqCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Eq")!
        inst = Behavior(
            name,
            takes: [stack, stack],
            fxn: { a in
                let isSame = a[0].isEqual(to: a[1])
                return [
                    Router(
                        .bool,
                        BoolItem(
                            isSame,
                            call: [a[1], a[0], InstructionItem(name)],
                            isContingent: Behavior.netContingency(
                                of: a[0],
                                a[1]
                            )
                        )
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
        inst = BehaviorWithSideEffects(
            name,
            takes: [],
            modifier: { (interpreter, collectedItems) in
                interpreter.stacks[stack]!.removeAll()
                return []
            }
        )
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
        inst = Behavior(
            name,
            takes: [stack],
            fxn: { _ in return [] }
        )
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
        inst = Behavior(
            name,
            takes: [stack, stack, stack],
            fxn: { a in
                let (x, y, z) = (a[0], a[1], a[2])
                return [
                    Router(stack, y),
                    Router(stack, x),
                    Router(stack, z),
                ]
            }
        )
        result[name] = inst
    }

    //  'shove` produces a result with `isContingent = true`
    //  because the item moved is in a new location that's contingent
    //
    static func shoveCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Shove")!
        inst = BehaviorWithSideEffects(
            name,
            takes: [.int],
            modifier: { (interpreter, collectedItems) in
                guard let oldItem = interpreter.stacks[stack]!.popFirst() else {
                    return [
                        Router(
                            .error,
                            ErrorItem("\(name) on empty stack")
                        )
                    ]
                }

                let indexRaw = collectedItems[0] as! IntItem
                let range = interpreter.stacks[stack]!.count - 1
                let idx = max(0, min(indexRaw.value, range))
                var newItem = oldItem
                newItem.call = [oldItem, InstructionItem(name)]
                newItem.isContingent = true
                interpreter.requireAccepts(newItem, on: stack)
                interpreter.stacks[stack]!.insert(newItem, at: idx)
                return []
            }
        )
        result[name] = inst
    }

    //  'stackDepth` produces a result with `isContingent = true`
    //
    static func stackDepthCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)StackDepth")!
        inst = BehaviorWithSideEffects(
            name,
            takes: [],
            modifier: { (interpreter, collectedItems) in
                let c = interpreter.stacks[stack]!.count
                return [
                    Router(
                        .int,
                        IntItem(
                            c,
                            call: [InstructionItem(name)],
                            isContingent: true
                        )
                    )
                ]
            }
        )
        result[name] = inst
    }

    // swap restructures the `type` stack, but does not affect argument state
    // and therefore has no effect on `call` or `isContingent` _unless the instruction itself_
    // is contingent.
    //
    static func swapCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Swap")!
        inst = Behavior(
            name,
            takes: [stack, stack],
            fxn: { a in
                return [
                    Router(stack, a[0]), Router(stack, a[1]),
                ]
            }
        )
        result[name] = inst
    }

    //  'yank` produces a result with `isContingent = true`
    //  because the item moved is in a new location that's contingent
    //
    static func yankCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Yank")!
        inst = BehaviorWithSideEffects(
            name,
            takes: [.int],
            modifier: { (interpreter, collectedItems) in
                let rawIndex = collectedItems[0] as! IntItem
                let range = interpreter.stacks[stack]!.count - 1
                let idx = max(0, min(rawIndex.value, range))

                guard range > 0 else {
                    return [Router(.error, ErrorItem("\(name) on empty stack"))]
                }

                let oldItem = interpreter.stacks[stack]!.remove(at: idx)
                var newItem = oldItem
                newItem.call = [oldItem, InstructionItem(name)]
                newItem.isContingent = true
                return [Router(stack, newItem)]
            }
        )
        result[name] = inst
    }

    //  'yankdup` produces a result with `isContingent = true`
    //  because the item moved is in a new location that's contingent

    static func yankDupCombinator_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)YankDup")!
        inst = BehaviorWithSideEffects(
            name,
            takes: [.int],
            modifier: { (interpreter, collectedItems) in
                let rawIndex = collectedItems[0] as! IntItem
                let range = interpreter.stacks[stack]!.count - 1
                let idx = max(0, min(rawIndex.value, range))

                guard range > 0 else {
                    return [
                        Router(
                            .error,
                            ErrorItem("\(name) on empty stack")
                        )
                    ]
                }
                let oldItem = interpreter.stacks[stack]![idx]
                var newItem = oldItem
                newItem.call = [oldItem, InstructionItem(name)]
                newItem.isContingent = true
                return [Router(stack, newItem)]
            }
        )
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
        eqCombinator_Behavior(for: stack, into: &result)
        flushCombinator_Behavior(for: stack, into: &result)
        popCombinator_Behavior(for: stack, into: &result)
        rotCombinator_Behavior(for: stack, into: &result)
        shoveCombinator_Behavior(for: stack, into: &result)
        stackDepthCombinator_Behavior(for: stack, into: &result)
        swapCombinator_Behavior(for: stack, into: &result)
        yankCombinator_Behavior(for: stack, into: &result)
        yankDupCombinator_Behavior(for: stack, into: &result)

        return result
    }
}
