//
//  Function Application.swift
//  Plunge
//
//  How map, filter and reduce find a function on `.function` and fill its
//  holes (`Function Behaviors.swift` has the rules).
//

nonisolated extension Interpreter {

    // MARK: - Finding and filling a function

    /// What a function is asked to do with a collection's elements, which decides
    /// what fits (`fits`) and how many holes the elements fill (`bound`).
    enum Family {
        /// Each element to a value a collection holds.
        case map
        /// Each element to a bool (filter, and the predicate searches and cuts).
        case filter
        /// The running value and the next element to a new running value
        /// (reduce, and scan, which keeps every running value).
        case reduce
        /// An element from each of two collections to a value a collection holds.
        case zip
        /// Each element to a value to order or compare elements by.
        case key
        /// A value to the next value of its own type (iterate).
        case step

        /// How many holes of the element's type the elements fill.
        var bound: Int {
            switch self {
            case .reduce, .zip: 2
            case .map, .filter, .key, .step: 1
            }
        }
    }

    /// The stacks a map's result can be collected from.
    static let collectableStacks: Set<PushStack> = [.bool, .int, .double, .string, .char]

    /// Whether `function` can do `family`'s job over elements on `element`.
    static func fits(_ function: FunctionItem, _ family: Family, over element: PushStack) -> Bool {
        guard let output = function.output, function.holeCount(on: element) >= family.bound else { return false }
        switch family {
        case .map, .zip, .key: return collectableStacks.contains(output)
        case .filter: return output == .bool
        case .reduce, .step: return output == element
        }
    }

    /// The sieve for the topmost function on `.function` that does `family`'s job
    /// over elements on `element`.
    static func fitting(_ family: Family, over element: PushStack) -> Requirement {
        .takesFirst(.function) { candidate, _ in
            candidate.exactly(FunctionItem.self).map { fits($0, family, over: element) } == true
        }
    }

    /// A function taken for an application, with every hole's filler but the
    /// elements'.
    struct Application {
        let function: FunctionItem
        /// Each hole's filler from the run, in hole order, or nil for an element's.
        let fixed: [(any Item)?]
        /// The fillers read from the run, deepest first: the order that replays them.
        let read: [any Item]
        /// How many fillers were read from each stack, sorted by stack.
        let counts: [(key: PushStack, value: Int)]

        /// The `call` of a result on `stack`: the fillers, the collection, the
        /// function and the instruction, then the fillers cleared away, as a
        /// query's are (`Behavior.reading`): they were read and left.
        func recorded(_ instruction: PushInstruction, _ collection: any Item,
                      producing stack: PushStack) -> [any Item] {
            recorded(instruction, collections: [collection], producing: stack)
        }

        /// As `recorded(_:_:producing:)`, for any number of collections in written
        /// order; `alsoRead` counts the ones the instruction read and left (a
        /// query's collection), which the crux clears away with the fillers.
        func recorded(_ instruction: PushInstruction, collections: [any Item], alsoRead: [PushStack] = [],
                      producing stack: PushStack) -> [any Item] {
            var merged: [PushStack: Int] = [:]
            for (key, value) in counts { merged[key, default: 0] += value }
            for key in alsoRead { merged[key, default: 0] += 1 }
            let sorted = merged.sorted { $0.key.rawValue < $1.key.rawValue }.map { (key: $0.key, value: $0.value) }
            return Behavior.reading(sorted: sorted, producing: stack,
                                    from: read + collections + [function, InstructionItem(instruction)])
        }

        /// The function filled, `bound` in the elements' holes.
        func program(_ bound: [any Item]) -> [any Item] {
            var next = bound.makeIterator()
            return function.filled(with: fixed.map { $0 ?? next.next()! })
        }
    }

    /// A filler read from the run, where it was read from.
    struct Filler {
        let depth: Int
        let order: Int
        let item: any Item
    }

    /// The fillers for `function`'s holes but the elements': every other hole takes
    /// the top of its stack in the run, then the next down, read and left. A refusal
    /// (`notFound`) when a stack runs short. The function itself was found by the
    /// sieve (`Requirement.takesFirst`).
    static func prepare(_ function: FunctionItem, _ family: Family, over element: PushStack,
                        _ context: ReadContext) -> Result<Application, Refusal> {
        var bound = family.bound
        var taken: [PushStack: Int] = [:]
        var fixed: [(any Item)?] = []
        var read: [Filler] = []
        for hole in function.holes {
            if hole.stack == element && bound > 0 {
                bound -= 1
                fixed.append(nil)
                continue
            }
            let depth = taken[hole.stack, default: 0]
            let supply = context.items(of: hole.stack)
            guard depth < supply.count else {
                return .failure(Refusal("nothing on .\(hole.stack) to fill \(function.pretty())", kind: .notFound))
            }
            taken[hole.stack] = depth + 1
            fixed.append(supply[depth])
            read.append(Filler(depth: depth, order: read.count, item: supply[depth]))
        }
        let ordered = read.sorted { ($0.depth, $0.order) > ($1.depth, $1.order) }.map(\.item)
        let counts = taken.sorted { $0.key.rawValue < $1.key.rawValue }.map { (key: $0.key, value: $0.value) }
        return .success(Application(function: function, fixed: fixed, read: ordered, counts: counts))
    }

    /// `application` run once with `bound` in the elements' holes, its steps
    /// charged: the top of its output stack, or nil if there is none.
    static func call(_ application: Application, _ bound: [any Item],
                     _ context: ReadContext) throws(ApplicationFailure) -> (any Item)? {
        let budget = context.remainingSteps
        guard context.maySandbox else { throw .tooDeep }
        guard budget > 0 else { throw .outOfSteps }
        let sub = Interpreter()
        sub.sandboxDepth = context.sandboxDepth + 1
        // The language's default limits, not this run's, as for `run`.
        sub.config = Interpreter.defaultSettings
        sub.config.recordsProvenance = false
        sub.config.stepLimit = budget
        sub.load(inputs: context.inputs, constants: context.constants, program: application.program(bound))
        sub.run()
        context.charge(sub.counter)
        guard sub.stacks[.exec]!.isEmpty else { throw .outOfSteps }
        return application.function.output.flatMap { sub.stacks[$0]?.first }
    }

    /// A refusal from `prepare`, as the instruction's error.
    static func refusal(_ instruction: PushInstruction, _ refusal: Refusal, _ context: ReadContext) -> [Router] {
        [Router(.error, ErrorItem("\(instruction): \(refusal.message)", kind: refusal.kind, source: instruction)
            .observed(by: instruction, context.recording))]
    }
}
