//
//  Block Functions.swift
//  PlungeTests
//
//  A test-side `functionFromCode`: a block is stepped in a sandbox where every
//  missing argument is supplied as a hole (`Block Function Holes.swift`), and
//  every item a step pushes, to any stack but `.exec` and `.error`, is read as
//  its crux. A crux with at least one hole in it is a function of its holes;
//  one is kept each time it is pushed, even if a later step consumes it. V18
//  and V19 sieve these functions for one that fits a map, filter or reduce, as
//  a `.function` stack would.
//

@testable import Plunge

extension FunctionOutcome {

    // MARK: - Converting a block

    /// One function a block yields: the crux of one item it pushed.
    @MainActor struct BlockFunction {
        var body: [any Item]
        /// Its arguments, in order of first appearance in the body.
        var holes: [Hole]
        /// Constants the block itself names that the body uses.
        var constantRefs: [PushInstruction]
        var output: PushStack
        /// The item it was read from: the body's value with the first placeholders.
        var value: any Item

        func takes(_ stack: PushStack) -> Int { holes.filter { $0.stack == stack }.count }

        func hole(_ leaf: any Item) -> Hole? {
            guard let source = (leaf as? StandInItem)?.source else { return nil }
            return holes.first { $0.marker == source }
        }

        /// The body with each hole written as its type and order, each of the
        /// block's own constants as its type.
        var shape: String {
            var names: [PushInstruction: String] = [:]
            var counts: [PushStack: Int] = [:]
            for hole in holes {
                let n = counts[hole.stack, default: 0]
                names[hole.marker] = "⟨\(hole.stack)\(n)⟩"
                counts[hole.stack] = n + 1
            }
            return body.map { leaf in
                if let hole = hole(leaf), let name = names[hole.marker] { return name }
                guard let token = (leaf as? InstructionItem)?.value else { return FunctionOutcome.render(leaf) }
                if constantRefs.contains(token) { return "⟨\(token.rawValue.dropLast()) const⟩" }
                return "." + token.rawValue
            }.joined(separator: " ")
        }

        /// The instructions in the body, without its holes and values.
        var skeleton: String {
            body.compactMap { ($0 as? InstructionItem)?.value }
                .filter { !constantRefs.contains($0) }.map { "." + $0.rawValue }.joined(separator: " ")
        }

        var signature: String { "(" + holes.map { "\($0.stack)" }.joined(separator: ", ") + ") → \(output)" }
    }

    /// What converting one block found.
    struct Conversion {
        /// In the order their items were pushed, repeats kept.
        var functions: [BlockFunction] = []
        var steps = 0
        /// It ran out of steps, and is refused: it yields nothing.
        var exceeded = false
        /// Holes made, and unbound input tokens the block ran.
        var holesMade = 0, unboundInputs = 0
        /// Items pushed, and what those that are not functions were: a hole
        /// moved but unchanged, a value using no hole, one using only the
        /// block's own constants, one whose crux is over 300 items.
        /// `incomplete` functions have an elided history in their body.
        var pushes = 0, bareHoles = 0, constants = 0, constantRefOnly = 0, tooLong = 0, incomplete = 0
        /// The sandbox's errors, oldest first: refusals the placeholders caused.
        var errors: [String] = []
    }

    /// `block` as every function it yields, in the order their items were
    /// pushed. Refused (no functions) if it runs out of steps.
    static func convert(_ block: CodeItem, in s: Situation, charged: Bool = true, limit: Int = budget) -> Conversion {
        let used = tokens(in: block.value)
        var registry = HoleRegistry(avoiding: used, constants: s.constants)
        let blockConstants = used.filter { s.constants[$0] != nil }
        let sub = Interpreter()
        sub.config = Interpreter.defaultSettings
        sub.config.recordsProvenance = true
        sub.config.stepLimit = limit
        sub.load(inputs: s.inputs, constants: s.constants, program: block.value)
        var result = Conversion()
        while sub.counter < sub.config.stepLimit, let next = sub.stacks[.exec]!.first {
            if let token = (next as? InstructionItem)?.value {
                if Interpreter.inputSlots.contains(token), s.inputs[token] == nil { result.unboundInputs += 1 }
                result.holesMade += supplyHoles(for: token, in: sub, registry: &registry)
            }
            let before = Dictionary(uniqueKeysWithValues: holeStacks.map { ($0, sub.stacks[$0]!.map(fingerprint)) })
            sub.step()
            guard !rearranges(next) else { continue }
            for stack in holeStacks {
                for item in fresh(before[stack]!, Array(sub.stacks[stack]!)) {
                    read(item, on: stack, registry, blockConstants, into: &result)
                }
            }
        }
        result.steps = sub.counter
        result.errors = sub.stacks[.error]!.reversed().map(render)
        if charged { sandboxSteps += sub.counter }
        if !sub.stacks[.exec]!.isEmpty {
            result.exceeded = true
            result.functions = []
        }
        return result
    }

    /// Adds the function `item` is, if it is one, to `result`.
    static func read(_ item: any Item, on stack: PushStack, _ registry: HoleRegistry,
                     _ blockConstants: Set<PushInstruction>, into result: inout Conversion) {
        result.pushes += 1
        if item.call.count == 1, registry.hole(item.call[0]) != nil {
            result.bareHoles += 1
            return
        }
        guard let body = CruxSharing.crux(of: item, limit: 300) else { result.tooLong += 1; return }
        var holes: [Hole] = []
        var refs: [PushInstruction] = []
        for leaf in body {
            if let hole = registry.hole(leaf), !holes.contains(where: { $0.marker == hole.marker }) {
                holes.append(hole)
            } else if let token = (leaf as? InstructionItem)?.value, blockConstants.contains(token),
                      !refs.contains(token) {
                refs.append(token)
            }
        }
        guard !holes.isEmpty else {
            if body.count > 1 && !refs.isEmpty { result.constantRefOnly += 1 } else { result.constants += 1 }
            return
        }
        if body.contains(where: { ($0 as? StandInItem)?.reason == .elided }) { result.incomplete += 1 }
        result.functions.append(BlockFunction(body: body, holes: holes, constantRefs: refs, output: stack,
                                              value: item))
    }

    /// `f`'s body with each hole replaced by `args[marker]`.
    static func substituted(_ f: BlockFunction, _ args: [PushInstruction: any Item]) -> [any Item] {
        f.body.map { leaf in f.hole(leaf).flatMap { args[$0.marker] } ?? leaf }
    }

    /// Whether `f`'s value changes when its holes get the second or third
    /// placeholders. A hole in the body does not guarantee it (`x 0 .intMultiply`).
    static func responds(_ f: BlockFunction, in s: Situation) -> Bool {
        for round in [1, 2] {
            let args = Dictionary(uniqueKeysWithValues: f.holes.map { ($0.marker, $0.values[round]) })
            guard let sub = sandbox(substituted(f, args), inputs: s.inputs, constants: s.constants, budget: budget),
                  let value = sub.stacks[f.output]?.first else { return true }
            if render(value) != render(f.value) { return true }
        }
        return false
    }


    // MARK: - Sieving and applying (V18, V19)

    /// Whether `f` can do `family`'s job over elements on `stack`: one hole of
    /// the type and a value a vector can hold (map), a bool (filter), or two
    /// holes of the type and a value of it (reduce). A hole in the body is
    /// enough; whether the value responds to it is not checked.
    static func sieves(_ f: BlockFunction, _ family: Family, _ stack: PushStack) -> Bool {
        switch family {
        case .map: return f.takes(stack) >= 1 && scalarStacks.contains(f.output)
        case .filter: return f.takes(stack) >= 1 && f.output == .bool
        case .reduce: return f.takes(stack) >= 2 && f.output == stack
        }
    }

    /// The first function that fits, from the top block (V18) or from every
    /// block on `.code`, top down (V19, as if each had been converted when it
    /// was made: the conversions are not charged to the application).
    static func sievedFunction(_ call: Call, _ stack: PushStack) -> BlockFunction? {
        let s = call.situation
        let blocks = call.variant == .v18 ? [s.block] : (s.stacks[.code] ?? []).compactMap { $0 as? CodeItem }
        for block in blocks {
            let conversion = convert(block, in: s, charged: call.variant == .v18)
            if let found = conversion.functions.first(where: { sieves($0, call.family, stack) }) { return found }
        }
        return nil
    }

    /// `f`'s value with `bound` in its first holes of `stack`'s type and every
    /// other hole filled from the situation's stacks, top first (past the
    /// collection), then from its own placeholder. Nil if it ran out of steps
    /// or left no value.
    static func call(_ f: BlockFunction, binding bound: [any Item], of stack: PushStack,
                     in s: Situation, budget: Int) -> (value: any Item, steps: Int)? {
        var pending = bound
        var args: [PushInstruction: any Item] = [:]
        var taken: [PushStack: Int] = [:]
        let collectionStack = PushStack.defaultStack(for: s.collection)
        for hole in f.holes {
            if hole.stack == stack, !pending.isEmpty { args[hole.marker] = pending.removeFirst(); continue }
            let supply = s.stacks[hole.stack] ?? []
            let next = taken[hole.stack, default: hole.stack == collectionStack ? 1 : 0]
            taken[hole.stack] = next + 1
            args[hole.marker] = supply.indices.contains(next) ? supply[next] : hole.values[0]
        }
        guard let sub = sandbox(substituted(f, args), inputs: s.inputs, constants: s.constants, budget: budget),
              let value = sub.stacks[f.output]?.first else { return nil }
        return (value, sub.counter)
    }

    /// V18 and V19: the sieved function applied per element (map, filter), or
    /// as a fold with the accumulator in the first hole and the element in the
    /// second (reduce).
    static func functionStackOutput(_ call: Call, elements: [any Item]) -> Result<any Item, Refusal> {
        let stack = PushStack.defaultStack(for: elements[0])!
        guard let f = sievedFunction(call, stack) else { return .failure(Refusal("no function")) }
        let s = call.situation
        var used = 0
        func apply(_ bound: [any Item]) -> (any Item)? {
            guard let made = Self.call(f, binding: bound, of: stack, in: s, budget: budget - used) else { return nil }
            used += made.steps
            return made.value
        }
        if call.family == .reduce {
            var accumulator = elements[0]
            for element in elements.dropFirst() {
                guard let value = apply([accumulator, element]) else { return .failure(Refusal("no result")) }
                accumulator = value
            }
            return .success(accumulator)
        }
        var results: [any Item] = []
        for element in elements {
            guard let value = apply([element]) else { return .failure(Refusal("no result")) }
            results.append(value)
        }
        if call.family == .filter {
            let kept = zip(elements, results).filter { ($0.1 as? BoolItem)?.value == true }.map(\.0)
            return .success(rebuilt(kept, like: s.collection)!)
        }
        guard let gathered = Interpreter.collected(results, call: []) else { return .failure(Refusal("mixed types")) }
        return .success(gathered)
    }
}
