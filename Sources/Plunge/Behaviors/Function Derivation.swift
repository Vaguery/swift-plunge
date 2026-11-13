//
//  Function Derivation.swift
//  Plunge
//
//  `codePushAllFunctions`: a block converted into the functions its pushes
//  compute.
//
//  The block runs in a sandbox. Before each instruction, every argument it is
//  missing is supplied as a **placeholder**, slipped under what is there so the
//  arguments present keep their places, and marked as a hole (a `StandInItem` of
//  reason `.hole`, its value the hole's number). Every item the sandbox then
//  pushes (to any stack but `.exec`, `.error` and `.function`) whose history
//  reaches a hole is a function of its holes: its history, each hole taken out
//  and recorded as a position (`FunctionItem.Hole`). They are pushed in the order
//  they were made, repeats included.
//
//  The rulings (the user, 2026-11-11; PlungeGP `Notes on Push/Function
//  application variants.md`):
//  - **Explicit only, and the block is consumed.** Nothing converts a block
//    automatically.
//  - **Repeats cost once.** A block's derivation costs its steps the first time a
//    run makes that block; later copies reuse it (`Interpreter.derivations`).
//  - **A block that runs too long yields nothing**, and that refusal is the one
//    error that reaches the run. The sandbox's own errors stay in it.
//  - The sandbox has the run's inputs and constants and the language's default
//    limits, whatever the run's, so a function never depends on configuration.
//

nonisolated extension Interpreter {

    // Tunables, kept here rather than in `InterpreterSettings` (as the runaway
    // guard's are). PROVISIONAL: the user has not settled how a derivation's
    // allowance should scale. Measured on random blocks, a block needs a median
    // 1.5 steps per point and its slowest tenth 3–9; a fixed 100 refused 92% of
    // 89-token blocks. Every step is also charged to the run.
    static let derivationStepsPerPoint = 10
    static let derivationStepFloor = 100

    static let codePushAllFunctions_Behavior =
        Behavior.applying(.codePushAllFunctions, takes: [.code], tags: [.fallible],
                          produces: .several(.function)) { a, context in
            let block = a[0].exactly(CodeItem.self)!
            guard context.maySandbox else {
                return [Router(.error, ErrorItem("codePushAllFunctions: sandboxes nested past "
                                                 + "\(Interpreter.maxSandboxDepth) deep", kind: .sizeRefusal,
                                                 source: .codePushAllFunctions)
                    .observed(by: .codePushAllFunctions, context.recording))]
            }
            let key = block.pretty()
            let functions: [FunctionItem]?
            if let known = context.derivation(of: key) {
                functions = known
            } else {
                let allowance = max(derivationStepFloor, derivationStepsPerPoint * block.flatSize)
                let derivation = FunctionDerivation(block, inputs: context.inputs, constants: context.constants,
                                                    limit: min(context.remainingSteps, allowance),
                                                    depth: context.sandboxDepth + 1)
                context.charge(derivation.steps)
                functions = derivation.functions
                context.remember(functions, for: key)
            }
            guard let functions else {
                return [Router(.error, ErrorItem("codePushAllFunctions: the block ran past its derivation limit",
                                                 kind: .outOfSteps, source: .codePushAllFunctions)
                    .observed(by: .codePushAllFunctions, context.recording))]
            }
            return functions.map { Router(.function, $0.observed(by: .codePushAllFunctions, context.recording)) }
        }
        .described(
            "Takes a code block and pushes every function its pushes compute: the code block runs with a placeholder " +
            "for each missing argument, and each item it makes from a placeholder becomes a function with a hole " +
            "there; refuses a code block that runs too long.")
}

/// One code block's derivation: the functions it yields, or nil if it ran past its
/// limit, and the steps it took.
nonisolated struct FunctionDerivation {
    private(set) var steps = 0
    private(set) var functions: [FunctionItem]?

    /// The stacks a hole can be made on, and pushes are read from.
    static let holeStacks: Set<PushStack> =
        Set(PushStack.allCases.filter { !$0.isChannel }).subtracting([.exec, .function])

    init(_ block: CodeItem, inputs: [PushInstruction: any Item], constants: [PushInstruction: any Item],
         limit: Int, depth: Int) {
        let sandbox = Interpreter()
        sandbox.sandboxDepth = depth
        sandbox.config = Interpreter.defaultSettings
        sandbox.config.recordsProvenance = true
        sandbox.config.stepLimit = limit
        sandbox.load(inputs: inputs, constants: constants, program: block.value)
        var holes: [PushStack] = []     // each hole's stack, by number
        var found: [FunctionItem] = []
        while sandbox.counter < limit, let next = sandbox.stacks[.exec]!.first {
            var rearranges = false
            if let token = next.exactly(InstructionItem.self)?.value, let behavior = Interpreter.language[token] {
                Self.supplyHoles(for: token, in: sandbox, holes: &holes)
                if case .positions = behavior.produces { rearranges = true }
            }
            sandbox.pushLog = []
            sandbox.step()
            // What a rearranging instruction leaves was not made by it.
            guard !rearranges, let pushed = sandbox.pushLog else { continue }
            for (stack, item) in pushed where Self.holeStacks.contains(stack) {
                if let function = Self.function(item, on: stack, holes: holes) { found.append(function) }
            }
        }
        sandbox.pushLog = nil
        steps = sandbox.counter
        functions = sandbox.stacks[.exec]!.isEmpty ? found : nil
    }

    /// Before `token` runs: a hole for every argument it is missing, under what
    /// is there, numbered in the order made.
    static func supplyHoles(for token: PushInstruction, in sandbox: Interpreter, holes: inout [PushStack]) {
        guard let wanted = FunctionItem.bareShapes[token]?.holes, !wanted.isEmpty else { return }
        var counts: [PushStack: Int] = [:], order: [PushStack] = []
        for hole in wanted {
            if counts[hole.stack] == nil { order.append(hole.stack) }
            counts[hole.stack, default: 0] += 1
        }
        for stack in order where holeStacks.contains(stack) {
            let present = sandbox.stacks[stack]!.count
            for _ in present..<max(present, counts[stack]!) {
                let ordinal = holes.count { $0 == stack }
                var item = placeholder(stack, ordinal)
                item.call = [StandInItem(standingInFor: IntItem(holes.count), source: nil, reason: .hole)]
                holes.append(stack)
                sandbox.insert(item, at: sandbox.stacks[stack]!.count, on: stack)
            }
        }
    }

    /// `item`, pushed to `stack`, as a function of the holes its history
    /// reaches; nil if it reaches none, is a hole itself, or its history is too
    /// long to read.
    static func function(_ item: any Item, on stack: PushStack, holes: [PushStack]) -> FunctionItem? {
        if item.call.count == 1, holeNumber(item.call[0]) != nil { return nil }
        guard let crux = CruxSharing.crux(of: item, limit: 300) else { return nil }
        var order: [Int] = []
        var positions: [Int: [Int]] = [:]
        var body: [any Item] = []
        for leaf in crux {
            if let number = holeNumber(leaf), number < holes.count {
                if positions[number] == nil { order.append(number) }
                positions[number, default: []].append(body.count)
            } else {
                body.append(leaf)
            }
        }
        guard !order.isEmpty else { return nil }
        let made = order.map { FunctionItem.Hole(stack: holes[$0], positions: positions[$0]!) }
        return FunctionItem(body: body, holes: made, output: stack)
    }

    /// The number of the hole `leaf` marks, if it marks one.
    static func holeNumber(_ leaf: any Item) -> Int? {
        guard let mark = leaf.exactly(StandInItem.self), mark.reason == .hole else { return nil }
        return mark.value.exactly(IntItem.self)?.value
    }

    /// A placeholder value for the `ordinal`th hole on `stack`: fixed values,
    /// varied so that comparisons between holes come out both ways.
    static func placeholder(_ stack: PushStack, _ ordinal: Int) -> any Item {
        if stack == .binding {
            // Negative keys, which neither the inputs (0…) nor fresh keys use.
            return BindingItem(key: -1 - ordinal, bound: IntItem(3))
        }
        let choices = placeholders[stack] ?? [IntItem(0)]    // .exec, .error, .function: never made
        return choices[ordinal % choices.count]
    }

    static let placeholders: [PushStack: [any Item]] = [
        .int: [3, 5, 2, 7].map { IntItem($0) },
        .double: [1.5, 2.25, 0.75, 3.5].map { DoubleItem($0) },
        .bool: [true, false].map { BoolItem($0) },
        .char: Array("aexm").map { CharItem($0) },
        .string: ["abc", "hello", "xy", "qrst"].map { StringItem($0) },
        .vecInt: [[1, 2, 3], [4, 5]].map { VecIntItem($0) },
        .vecDouble: [[1.5, 2.5], [0.25]].map { VecDoubleItem($0) },
        .vecBool: [[true, false], [false]].map { VecBoolItem($0) },
        .vecString: [["a", "bc"], ["d"]].map { VecStringItem($0) },
        .code: [CodeItem([IntItem(1)])],
        .iterator: [IteratorItem(kind: .counting(stride: 1), origin: IntItem(0), destination: IntItem(3),
                                 body: nil, emits: true)]
    ]
}
