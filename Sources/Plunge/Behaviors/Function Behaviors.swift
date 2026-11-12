//
//  Function Behaviors.swift
//  Plunge
//
//  Map, filter and reduce over vectors and strings, applying a function from
//  `.function`.
//
//  **The function is found, not given.** Each takes its collection, and takes
//  the topmost function on `.function` that can do its job over the collection's
//  elements, through the planner's sieve (`Requirement.takesFirst`, testing
//  `fits`):
//  - **map**: a hole of the element's type, and a value a collection can hold;
//  - **filter**: a hole of the element's type, and a bool;
//  - **reduce**: two holes of the element's type, and a value of that type.
//  An empty `.function` is a missing argument, so the instruction starves (and is
//  itself shelved on `.function`). A non-empty `.function` with nothing that fits
//  is a miss: `notFound`, with the collection consumed.
//
//  **Filling the holes** (the user's rulings 1–3, 2026-11-11). Holes are filled
//  in order. The element takes the first hole of its type; for reduce the
//  running value takes the first and the element the second, a left fold. Every
//  other hole takes the top of its stack in the run, then the next down, **read
//  and left**, so every element sees the same values: `.intAdd` mapped with 10 on
//  top of `.int` adds 10. When a stack runs short of filler, the instruction
//  refuses with `notFound` after consuming its arguments: the filler is material
//  it acquires, not an argument.
//
//  **Applying** runs the filled function in a fresh sub-interpreter over this
//  run's inputs and constants, with the language's default limits and its steps
//  charged to this run. **The result is the top of the function's output stack**
//  afterwards (provisional). With none there, map passes the element through,
//  filter drops it, and reduce keeps its running value.
//  - **Uniform or refuse.** A map's results must be one type: bools, ints,
//    doubles or strings make that vector; chars make a string.
//  - **Reduce folds from the first element**; an empty collection is refused.
//
//  Provenance: a result records the fillers it read, deepest first, then
//  `collection function .xMap`, then clears the fillers away as a query does
//  (they were read and left). It re-runs to the same result and nothing else:
//  the function lands on top of `.function`, where the sieve finds it first.
//

nonisolated extension Interpreter {

    // MARK: - Applying a function

    /// Why an application stopped short of a result for every element.
    enum ApplicationFailure: Error {
        case outOfSteps
        /// The run is already `Interpreter.maxSandboxDepth` sandboxes deep.
        case tooDeep

        /// The refusal's wording.
        var reason: String {
            switch self {
            case .outOfSteps: "out of steps"
            case .tooDeep: "sandboxes nested past \(Interpreter.maxSandboxDepth) deep"
            }
        }
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
        guard context.maySandbox else { throw .tooDeep }
        guard budget > 0 else { throw .outOfSteps }
        let sub = Interpreter()
        sub.sandboxDepth = context.sandboxDepth + 1
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

    /// Map over `elements` of `collection`; `empty` is the result for none.
    static func map(_ instruction: PushInstruction, _ arguments: [any Item], _ elements: [any Item],
                    empty: (([any Item]) -> any Item), _ context: ReadContext) -> [Router] {
        let (collection, function) = (arguments[0], arguments[1].exactly(FunctionItem.self)!)
        let element = elementStack[PushStack.defaultStack(for: collection)!]!
        let application: Application
        switch prepare(function, .map, over: element, context) {
        case .failure(let why): return refusal(instruction, why, context)
        case .success(let ready): application = ready
        }
        guard !elements.isEmpty else {
            let stack = PushStack.defaultStack(for: collection)!
            return [Router(stack, empty(context.recording(application.recorded(instruction, collection,
                                                                               producing: stack))))]
        }
        var results: [any Item] = []
        for item in elements {
            do throws(ApplicationFailure) {
                results.append(try Self.call(application, [item], context) ?? item)
            } catch {
                return refusal(instruction, error.reason, context)
            }
        }
        guard let made = collected(results, call: []), let stack = PushStack.defaultStack(for: made),
              let output = collected(results, call: context.recording(application.recorded(
                  instruction, collection, producing: stack))) else {
            return refusal(instruction, "results are not all one collectable type", context)
        }
        return [Router(stack, output)]
    }

    /// Filter `elements` of `collection`: `keep` builds the result from the kept
    /// positions and its call.
    static func filter(_ instruction: PushInstruction, _ arguments: [any Item], _ elements: [any Item],
                       keep: ([Int], [any Item]) -> Router, _ context: ReadContext) -> [Router] {
        let (collection, function) = (arguments[0], arguments[1].exactly(FunctionItem.self)!)
        let element = elementStack[PushStack.defaultStack(for: collection)!]!
        let application: Application
        switch prepare(function, .filter, over: element, context) {
        case .failure(let why): return refusal(instruction, why, context)
        case .success(let ready): application = ready
        }
        var kept: [Int] = []
        for (index, item) in elements.enumerated() {
            do throws(ApplicationFailure) {
                if (try call(application, [item], context) as? BoolItem)?.value == true { kept.append(index) }
            } catch {
                return refusal(instruction, error.reason, context)
            }
        }
        return [keep(kept, application.recorded(instruction, collection,
                                                producing: PushStack.defaultStack(for: collection)!))]
    }

    /// Fold over `elements` of `collection` from the first.
    static func reduce(_ instruction: PushInstruction, _ arguments: [any Item], _ elements: [any Item],
                       _ context: ReadContext) -> [Router] {
        let (collection, function) = (arguments[0], arguments[1].exactly(FunctionItem.self)!)
        let element = elementStack[PushStack.defaultStack(for: collection)!]!
        let application: Application
        switch prepare(function, .reduce, over: element, context) {
        case .failure(let why): return refusal(instruction, why, context)
        case .success(let ready): application = ready
        }
        guard var accumulator = elements.first else {
            return refusal(instruction, "an empty collection has nothing to fold", context)
        }
        for item in elements.dropFirst() {
            do throws(ApplicationFailure) {
                accumulator = try call(application, [accumulator, item], context) ?? accumulator
            } catch {
                return refusal(instruction, error.reason, context)
            }
        }
        guard let stack = PushStack.defaultStack(for: accumulator) else {
            return refusal(instruction, "the fold produced \(accumulator.pretty()), which rests on no stack", context)
        }
        let result = rebuilt(accumulator, call: context.recording(application.recorded(instruction, collection,
                                                                                      producing: stack)))
        return [Router(stack, result)]
    }


    // MARK: - Factories

    static let mapResults: Produces =
        .alternatives([[.vecBool], [.vecDouble], [.vecInt], [.vecString], [.string]])

    /// Every stack a filler can be read from.
    static let fillerStacks: [PushStack] = PushStack.allCases.filter { ![.exec, .error].contains($0) }

    /// One of the three over `collection`'s stack: takes the collection, and
    /// reads `.function` (an empty one is a missing argument).
    /// One of the three over `collection`'s stack: takes the collection, and the
    /// topmost function that fits through the sieve (`Requirement.takesFirst`): an
    /// empty `.function` is a missing argument, one with nothing that fits a miss.
    static func functionBehavior(_ instruction: PushInstruction, _ family: Family, over collection: PushStack,
                                 summary: String,
                                 _ body: @escaping @Sendable ([any Item], ReadContext) -> [Router]) -> Behavior {
        let element = elementStack[collection]!
        let produces: Produces = switch family {
        case .map: mapResults
        case .filter: .results([collection])
        case .reduce: .results([element])
        }
        let fitting: Requirement = .takesFirst(.function) { candidate, _ in
            candidate.exactly(FunctionItem.self).map { fits($0, family, over: element) } == true
        }
        return Behavior(instruction, requires: [.takes(collection), fitting], tags: [.fallible],
                        behaviorClass: .operation, body: .applying(body), produces: produces,
                        observes: fillerStacks)
        .described(summary)
    }

    static func vectorMapBehavior<V: VectorItem>(_ instruction: PushInstruction, making itemType: V.Type) -> Behavior {
        functionBehavior(instruction, .map, over: V.pushStack,
                         summary: "Maps the topmost function on `.function` that fits over a "
                         + "\(V.pushStack.noun), each element in its first \(elementStack[V.pushStack]!) hole; "
                         + "refuses when none fits, filler runs short, results are mixed or steps run "
                         + "out.") { a, context in
            let vector = a[0] as! V
            return map(instruction, a, vector.value.map { V.Scalar($0, call: []) },
                       empty: { V([], call: $0) }, context)
        }
    }

    static func vectorFilterBehavior<V: VectorItem>(
        _ instruction: PushInstruction, making itemType: V.Type
    ) -> Behavior {
        functionBehavior(instruction, .filter, over: V.pushStack,
                         summary: "Keeps the elements of a \(V.pushStack.noun) for which the topmost "
                         + "bool-valued function on `.function` that fits gives true; refuses when none fits, "
                         + "filler runs short or steps run out.") { a, context in
            let vector = a[0] as! V
            let origins = vector.origins()
            return filter(instruction, a, vector.value.map { V.Scalar($0, call: []) },
                          keep: { kept, call in
                              Router(V.pushStack, V(kept.map { vector.value[$0] }, call: context.recording(call),
                                                    members: context.recording.pieces(kept.map { origins[$0] })))
                          }, context)
        }
    }

    static func vectorReduceBehavior<V: VectorItem>(
        _ instruction: PushInstruction, making itemType: V.Type
    ) -> Behavior {
        let element = elementStack[V.pushStack]!
        return functionBehavior(instruction, .reduce, over: V.pushStack,
                                summary: "Folds the topmost function on `.function` that fits over a "
                                + "\(V.pushStack.noun) from the first element, the running value in its first "
                                + "\(element) hole and the next element in its second; refuses an empty vector, or "
                                + "when none fits, filler runs short or steps run out.") { a, context in
            let vector = a[0] as! V
            return reduce(instruction, a, vector.value.map { V.Scalar($0, call: []) }, context)
        }
    }

    /// Each collection's element stack.
    static let elementStack: [PushStack: PushStack] = [
        .vecBool: .bool, .vecInt: .int, .vecDouble: .double, .vecString: .string, .string: .char
    ]

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
        functionBehavior(.stringMap, .map, over: .string,
                         summary: "Maps the topmost function on `.function` that fits over a string's chars, each "
                         + "in its first char hole; refuses when none fits, filler runs short, results are mixed or "
                         + "steps run out.") { a, context in
            let text = a[0] as! StringItem
            return map(.stringMap, a, text.value.map { CharItem($0) },
                       empty: { StringItem("", call: $0) }, context)
        }

    static let stringFilter_Behavior =
        functionBehavior(.stringFilter, .filter, over: .string,
                         summary: "Keeps the chars of a string for which the topmost bool-valued function on "
                         + "`.function` that fits gives true; refuses when none fits, filler runs short or steps run "
                         + "out.") { a, context in
            let text = a[0] as! StringItem
            let characters = Array(text.value)
            let origins = text.origins()
            return filter(.stringFilter, a, characters.map { CharItem($0) },
                          keep: { kept, call in
                              Router(.string, StringItem(String(kept.map { characters[$0] }),
                                                         call: context.recording(call),
                                                         members: context.recording.pieces(kept.map { origins[$0] })))
                          }, context)
        }

    static let stringReduce_Behavior =
        functionBehavior(.stringReduce, .reduce, over: .string,
                         summary: "Folds the topmost function on `.function` that fits over a string's chars from "
                         + "the first, the running value in its first char hole and the next char in its second; "
                         + "refuses an empty string, or when none fits, filler runs short or steps run "
                         + "out.") { a, context in
            let text = a[0] as! StringItem
            return reduce(.stringReduce, a, text.value.map { CharItem($0) }, context)
        }


    // MARK: - The family

    static let functionBehaviors: [PushInstruction: Behavior] = [
        .codePushAllFunctions: codePushAllFunctions_Behavior,
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
