//
//  Function Behaviors.swift
//  PushInterpreter
//
//  Map, filter and reduce over vectors and strings.
//
//  **A function is a block with `.inputN` holes.** There is no function type:
//  `( .input0 2 .intMultiply )` doubles its argument. Applying it runs the block
//  in a fresh sub-interpreter whose environment is this one's, with `.input0`
//  (and, for reduce, `.input1`) rebound. A block harvested from a crux already
//  has its holes, so it applies as it is.
//
//  The rules that shape them:
//  - **The result is the last value the function pushed**, on whatever stack;
//    so the result type follows the data, and `( .input0 .doubleFromInt )`
//    maps a vecInt to a vecDouble.
//  - **Uniform or refuse.** A map's results must be one type: bools, ints,
//    doubles or strings make that vector; chars make a string.
//  - **No result passes the element through**: the element stands for
//    itself. For filter, no result (or anything but a bool) counts as false.
//  - **Reduce folds from the first element**, with `.input0` the accumulator and
//    `.input1` the element; no seed is drawn, and an empty collection is refused.
//  - **Sub-run steps are charged to this run's budget** (`ReadContext.charge`),
//    and an application that would exceed what is left is refused. Every other
//    limit is the language's default, whatever the run's, so the result never
//    depends on configuration and the crux replays.
//
//  Provenance: the result records `collection function .xMap`, which re-runs to
//  the same result in the same environment (constants and inputs), the
//  assumption every constant and input already makes.
//

nonisolated extension Interpreter {

    // MARK: - Applying a function

    /// Why an application stopped short of a result for every element.
    enum ApplicationFailure: Error { case outOfSteps }

    /// Runs `function` once with `bindings` over the environment in `context`,
    /// charging its steps; returns the last value it pushed, or nil if it pushed
    /// none that is still there. The input-fed form: the function's argument is
    /// its `.input0` hole.
    static func apply(_ function: CodeItem, binding bindings: [PushInstruction: any Item],
                      in context: ReadContext) throws(ApplicationFailure) -> (any Item)? {
        try run(function.value, binding: bindings, in: context)
    }

    /// The stack-fed form, as an iterator plays its body: `element` is executed
    /// first, so it lands on its stack (or runs, if it is code to run), and then
    /// `body`. A body that pushes nothing leaves the element as the result.
    static func apply(_ body: CodeItem, after element: any Item,
                      in context: ReadContext) throws(ApplicationFailure) -> (any Item)? {
        try run([element] + body.value, binding: [:], in: context)
    }

    /// `program` run in a fresh sub-interpreter over this run's environment, with
    /// `bindings` over its inputs, its steps charged to this run.
    private static func run(_ program: [any Item], binding bindings: [PushInstruction: any Item],
                            in context: ReadContext) throws(ApplicationFailure) -> (any Item)? {
        let budget = context.remainingSteps
        guard budget > 0 else { throw .outOfSteps }
        let sub = Interpreter()
        // The language's default limits, not this run's: a function's result
        // must not depend on how the run was configured, or its crux would not
        // replay under the relaxed limits a reconstruction uses
        // (`InterpreterSettings.reconstructing`). Only the step budget is this
        // run's, and a function that finishes within it finishes the same way
        // with more.
        sub.config = Interpreter.defaultSettings
        sub.config.recordsProvenance = false
        sub.config.stepLimit = budget
        var inputs = context.inputs
        for (slot, value) in bindings { inputs[slot] = value }
        sub.load(inputs: inputs, constants: context.constants, program: program)
        sub.run()
        context.charge(sub.counter)
        guard sub.stacks[.exec]!.isEmpty else { throw .outOfSteps }
        guard let stack = sub.lastPush else { return nil }
        return sub.stacks[stack]?.first
    }

    /// `items` as one collection, if they are all one collectable type: a vector
    /// of bools, ints, doubles or strings, or a string of chars.
    static func collected(_ items: [any Item], call: [any Item]) -> (any Item)? {
        if let values = items as? [BoolItem] { return VecBoolItem(values.map(\.value), call: call) }
        if let values = items as? [IntItem] { return VecIntItem(values.map(\.value), call: call) }
        if let values = items as? [DoubleItem] { return VecDoubleItem(values.map(\.value), call: call) }
        if let values = items as? [StringItem] { return VecStringItem(values.map(\.value), call: call) }
        if let values = items as? [CharItem] { return StringItem(String(values.map(\.value)), call: call) }
        return nil
    }

    /// `item` rebuilt with `call`, when its type can be rebuilt from its value.
    static func rebuilt(_ item: any Item, call: [any Item]) -> any Item {
        func open<T: ValueItem>(_ typed: T) -> any Item { T(typed.value, call: call) }
        if let typed = item as? any ValueItem { return open(typed) }
        return item
    }

    static func refusal(_ instruction: PushInstruction, _ why: String, _ context: ReadContext) -> [Router] {
        [Router(.error, ErrorItem("\(instruction): \(why)").observed(by: instruction, context.recording))]
    }


    // MARK: - The three, over any collection

    /// Map `function` over `elements`; `empty` is the result for no elements.
    static func map(_ instruction: PushInstruction, _ elements: [any Item], _ function: CodeItem,
                    call: [any Item], empty: any Item, _ context: ReadContext) -> [Router] {
        guard !elements.isEmpty else { return [Router(PushStack.defaultStack(for: empty)!, empty)] }
        var results: [any Item] = []
        for element in elements {
            do throws(ApplicationFailure) {
                results.append(try apply(function, binding: [.input0: element], in: context) ?? element)
            } catch {
                return refusal(instruction, "out of steps", context)
            }
        }
        guard let output = collected(results, call: context.recording(call)),
              let stack = PushStack.defaultStack(for: output) else {
            return refusal(instruction, "results are not all one collectable type", context)
        }
        return [Router(stack, output)]
    }

    /// The positions of `elements` whose predicate result is `true`, or nil if
    /// the budget ran out.
    static func kept(_ elements: [any Item], _ function: CodeItem, _ context: ReadContext) -> [Int]? {
        var kept: [Int] = []
        for (index, element) in elements.enumerated() {
            do throws(ApplicationFailure) {
                let result = try apply(function, binding: [.input0: element], in: context)
                if (result as? BoolItem)?.value == true { kept.append(index) }
            } catch {
                return nil
            }
        }
        return kept
    }

    /// Fold `function` over `elements` from the first.
    static func reduce(_ instruction: PushInstruction, _ elements: [any Item], _ function: CodeItem,
                       call: [any Item], _ context: ReadContext) -> [Router] {
        guard var accumulator = elements.first else {
            return refusal(instruction, "an empty collection has nothing to fold", context)
        }
        for element in elements.dropFirst() {
            do throws(ApplicationFailure) {
                accumulator = try apply(function, binding: [.input0: accumulator, .input1: element],
                                        in: context) ?? accumulator
            } catch {
                return refusal(instruction, "out of steps", context)
            }
        }
        let result = rebuilt(accumulator, call: context.recording(call))
        guard let stack = PushStack.defaultStack(for: result) else {
            return refusal(instruction, "the fold produced \(result.pretty()), which rests on no stack", context)
        }
        return [Router(stack, result)]
    }


    // MARK: - Factories

    static let mapResults: Produces =
        .alternatives([[.vecBool], [.vecDouble], [.vecInt], [.vecString], [.string]])

    static let foldResults: Produces =
        .alternatives(PushStack.allCases.filter { ![.exec, .error, .iterator].contains($0) }.map { [$0] })

    static func vectorMapBehavior<V: VectorItem>(_ instruction: PushInstruction, making itemType: V.Type) -> Behavior {
        Behavior.applying(instruction, takes: [V.pushStack, .code], tags: [.fallible],
                          produces: mapResults) { a, context in
            let (vector, function) = (a[0] as! V, a[1] as! CodeItem)
            return map(instruction, vector.value.map { V.Scalar($0, call: []) }, function,
                       call: [vector, function, InstructionItem(instruction)],
                       empty: V([], call: context.recording([vector, function, InstructionItem(instruction)])),
                       context)
        }
        .described(
            "Runs the block on each element of a \(V.pushStack.noun), bound as `.input0`, collecting each run's "
            + "last pushed value (the element if none); refuses mixed types or when steps run out.")
    }

    static func vectorFilterBehavior<V: VectorItem>(
        _ instruction: PushInstruction, making itemType: V.Type
    ) -> Behavior {
        Behavior.applying(instruction, takes: [V.pushStack, .code], tags: [.fallible],
                          produces: .results([V.pushStack])) { a, context in
            let (vector, function) = (a[0] as! V, a[1] as! CodeItem)
            guard let kept = kept(vector.value.map { V.Scalar($0, call: []) }, function, context) else {
                return refusal(instruction, "out of steps", context)
            }
            let origins = vector.origins()
            return [Router(V.pushStack, V(kept.map { vector.value[$0] },
                                          call: context.recording([vector, function, InstructionItem(instruction)]),
                                          members: context.recording.pieces(kept.map { origins[$0] })))]
        }
        .described(
            "Keeps the elements of a \(V.pushStack.noun) for which the block, run with the element as `.input0`, "
            + "last pushes true; refuses when steps run out.")
    }

    static func vectorReduceBehavior<V: VectorItem>(
        _ instruction: PushInstruction, making itemType: V.Type
    ) -> Behavior {
        Behavior.applying(instruction, takes: [V.pushStack, .code], tags: [.fallible],
                          produces: foldResults) { a, context in
            let (vector, function) = (a[0] as! V, a[1] as! CodeItem)
            return reduce(instruction, vector.value.map { V.Scalar($0, call: []) }, function,
                          call: [vector, function, InstructionItem(instruction)], context)
        }
        .described(
            "Folds the block over a \(V.pushStack.noun) from the first element, with the running value as "
            + "`.input0` and the next element as `.input1`; refuses an empty vector or when steps run out.")
    }

    static let vecBoolMap_Behavior = vectorMapBehavior(.vecBoolMap, making: VecBoolItem.self)
    static let vecIntMap_Behavior = vectorMapBehavior(.vecIntMap, making: VecIntItem.self)
    static let vecDoubleMap_Behavior = vectorMapBehavior(.vecDoubleMap, making: VecDoubleItem.self)
    static let vecStringMap_Behavior = vectorMapBehavior(.vecStringMap, making: VecStringItem.self)
    static let vecBoolFilter_Behavior = vectorFilterBehavior(.vecBoolFilter, making: VecBoolItem.self)
    static let vecIntFilter_Behavior = vectorFilterBehavior(.vecIntFilter, making: VecIntItem.self)
    static let vecDoubleFilter_Behavior = vectorFilterBehavior(.vecDoubleFilter, making: VecDoubleItem.self)
    static let vecStringFilter_Behavior = vectorFilterBehavior(.vecStringFilter, making: VecStringItem.self)
    static let vecBoolReduce_Behavior = vectorReduceBehavior(.vecBoolReduce, making: VecBoolItem.self)
    static let vecIntReduce_Behavior = vectorReduceBehavior(.vecIntReduce, making: VecIntItem.self)
    static let vecDoubleReduce_Behavior = vectorReduceBehavior(.vecDoubleReduce, making: VecDoubleItem.self)
    static let vecStringReduce_Behavior = vectorReduceBehavior(.vecStringReduce, making: VecStringItem.self)

    // Strings: collections of chars.

    static let stringMap_Behavior =
        Behavior.applying(.stringMap, takes: [.string, .code], tags: [.fallible],
                          produces: mapResults) { a, context in
            let (text, function) = (a[0] as! StringItem, a[1] as! CodeItem)
            let call: [any Item] = [text, function, InstructionItem(.stringMap)]
            return map(.stringMap, text.value.map { CharItem($0) }, function,
                       call: call, empty: StringItem("", call: context.recording(call)), context)
        }
        .described(
            "Runs the block on each char of a string, bound as `.input0`, collecting each run's last pushed value "
            + "(the char if none); refuses mixed types or when steps run out.")

    static let stringFilter_Behavior =
        Behavior.applying(.stringFilter, takes: [.string, .code], tags: [.fallible],
                          produces: .results([.string])) { a, context in
            let (text, function) = (a[0] as! StringItem, a[1] as! CodeItem)
            let characters = Array(text.value)
            guard let kept = kept(characters.map { CharItem($0) }, function, context) else {
                return refusal(.stringFilter, "out of steps", context)
            }
            let origins = text.origins()
            let call: [any Item] = [text, function, InstructionItem(.stringFilter)]
            return [Router(.string, StringItem(String(kept.map { characters[$0] }),
                                               call: context.recording(call),
                                               members: context.recording.pieces(kept.map { origins[$0] })))]
        }
        .described(
            "Keeps the chars of a string for which the block, run with the char as `.input0`, last pushes true; "
            + "refuses when steps run out.")

    static let stringReduce_Behavior =
        Behavior.applying(.stringReduce, takes: [.string, .code], tags: [.fallible],
                          produces: foldResults) { a, context in
            let (text, function) = (a[0] as! StringItem, a[1] as! CodeItem)
            return reduce(.stringReduce, text.value.map { CharItem($0) }, function,
                          call: [text, function, InstructionItem(.stringReduce)], context)
        }
        .described(
            "Folds the block over a string's chars from the first, with the running value as `.input0` and the next "
            + "char as `.input1`; refuses an empty string or when steps run out.")


    // MARK: - The family

    static let functionBehaviors: [PushInstruction: Behavior] = [
        .vecBoolMap: vecBoolMap_Behavior,
        .vecIntMap: vecIntMap_Behavior,
        .vecDoubleMap: vecDoubleMap_Behavior,
        .vecStringMap: vecStringMap_Behavior,
        .vecBoolFilter: vecBoolFilter_Behavior,
        .vecIntFilter: vecIntFilter_Behavior,
        .vecDoubleFilter: vecDoubleFilter_Behavior,
        .vecStringFilter: vecStringFilter_Behavior,
        .vecBoolReduce: vecBoolReduce_Behavior,
        .vecIntReduce: vecIntReduce_Behavior,
        .vecDoubleReduce: vecDoubleReduce_Behavior,
        .vecStringReduce: vecStringReduce_Behavior,
        .stringMap: stringMap_Behavior,
        .stringFilter: stringFilter_Behavior,
        .stringReduce: stringReduce_Behavior
    ]
}
