//
//  Function Outcome Variants.swift
//  PlungeTests
//
//  The variants as test-side functions, and the classifier. Every variant runs
//  its block in fresh sandboxes with the language's default settings, as the
//  real instructions do, so the comparison is between rules, not machinery.
//

@testable import Plunge

extension FunctionOutcome {

    // MARK: - Running a sandbox

    /// `program` on a fresh interpreter with the language's default settings,
    /// or nil if it ran out of steps.
    static func sandbox(_ program: [any Item], inputs: [PushInstruction: any Item],
                        constants: [PushInstruction: any Item],
                        stacks: [PushStack: [any Item]] = [:], budget: Int) -> Interpreter? {
        guard budget > 0 else { return nil }
        let sub = Interpreter()
        sub.config = Interpreter.defaultSettings
        sub.config.recordsProvenance = false
        sub.config.stepLimit = budget
        sub.load(inputs: inputs, constants: constants, stacks: stacks, program: program)
        sub.run()
        sandboxSteps += sub.counter
        guard sub.stacks[.exec]!.isEmpty else { return nil }
        return sub
    }

    /// The `.inputN` tokens in `block`, at any depth, lowest-numbered first.
    static func holes(in block: CodeItem) -> [PushInstruction] {
        var found: Set<PushInstruction> = []
        func walk(_ items: [any Item]) {
            for item in items {
                if let token = (item as? InstructionItem)?.value, Interpreter.inputSlots.contains(token) {
                    found.insert(token)
                } else if let inner = item as? CodeItem {
                    walk(inner.value)
                }
            }
        }
        walk(block.value)
        return Interpreter.inputSlots.filter(found.contains)
    }

    /// Binds `holes` to `values` in order, as far as both go.
    static func bind(_ holes: [PushInstruction], to values: [any Item], in inputs: inout [PushInstruction: any Item]) {
        for (hole, value) in zip(holes, values) { inputs[hole] = value }
    }


    // MARK: - Crux-to-function (V7)

    /// The block V7 applies: the crux of the item on top of the element type's
    /// stack, with its first element-typed argument (and for reduce, its
    /// second) replaced by `.input0` (`.input1`). Nil when there is no such
    /// item, no history, or too few arguments of the type.
    static func cruxFunction(_ situation: Situation, elementStack: PushStack, holesNeeded: Int) -> CodeItem? {
        guard let item = situation.stacks[elementStack]?.first,
              !item.call.isEmpty,
              let crux = CruxSharing.crux(of: item, limit: 300) else { return nil }
        func isArgument(_ leaf: any Item) -> Bool {
            if let token = (leaf as? InstructionItem)?.value {
                let bound = situation.constants[token] ?? situation.inputs[token]
                return bound.map { PushStack.defaultStack(for: $0) == elementStack } ?? false
            }
            return !(leaf is CodeItem) && PushStack.defaultStack(for: leaf) == elementStack
        }
        var body = crux
        var holes = Array([PushInstruction.input0, .input1].prefix(holesNeeded))
        for index in body.indices where !holes.isEmpty && isArgument(body[index]) {
            body[index] = InstructionItem(holes.removeFirst())
        }
        guard holes.isEmpty else { return nil }
        return CodeItem(body)
    }


    // MARK: - Typed help (V9–V14)

    static let runner = Runner()

    /// Whether `item` is about `stack`: a value of its type, a constant or input
    /// token bound to one, or an instruction whose signature touches it.
    static func touches(_ item: any Item, _ stack: PushStack, _ s: Situation) -> Bool {
        if let token = (item as? InstructionItem)?.value {
            if let bound = s.constants[token] ?? s.inputs[token] { return PushStack.defaultStack(for: bound) == stack }
            return runner.signature(of: token)?.touches(stack) ?? false
        }
        return !(item is CodeItem) && PushStack.defaultStack(for: item) == stack
    }

    /// How many arguments `signature` takes from `stack`, consumed or read. A
    /// query (`intGT`) reads its arguments and leaves them, so counting only
    /// what is consumed would miss every comparison.
    static func arguments(_ signature: InstructionSignature, from stack: PushStack) -> Int {
        (signature.consumes[stack] ?? 0) + (signature.reads[stack] ?? 0)
    }

    /// Whether `item` is an instruction that takes an argument from `stack`.
    static func takes(_ item: any Item, _ stack: PushStack) -> Bool {
        guard let token = (item as? InstructionItem)?.value,
              let signature = runner.signature(of: token) else { return false }
        return arguments(signature, from: stack) > 0
    }

    /// The block with everything not about `stack` left out.
    static func projection(of block: CodeItem, onto stack: PushStack, _ s: Situation) -> CodeItem {
        CodeItem(block.value.filter { touches($0, stack, s) })
    }

    /// The constants of `stack`'s type, slot order, top first.
    static func typedConstants(_ s: Situation, _ stack: PushStack) -> [any Item] {
        s.constants.sorted { $0.key.rawValue < $1.key.rawValue }
            .map(\.value)
            .filter { PushStack.defaultStack(for: $0) == stack }
    }


    // MARK: - One application

    /// What one application left.
    struct Run {
        /// The result under the variant's rule.
        var result: (any Item)?
        /// The last value pushed, and the stack it went to.
        var lastPushed: (any Item)?
        var lastStack: PushStack?
        var steps: Int
    }

    /// One application of a per-element variant: `args` is `[element]`, or
    /// `[accumulator, element]` for reduce. A typed result is read from
    /// `resultStack` when one is given, else from the element's stack (`.bool`
    /// for filter). Nil if it ran out of steps.
    static func applyOnce(_ call: Call, _ block: CodeItem, args: [any Item], budget: Int,
                          resultStack: PushStack? = nil) -> Run? {
        let s = call.situation
        let elementStack = PushStack.defaultStack(for: args.last!)!
        var program = block.value
        var inputs = s.inputs
        var stacks: [PushStack: [any Item]] = [:]

        if call.variant.isStackFed { program = args + program }
        if call.variant == .v4 { stacks = s.stacks }
        if call.variant.hasTypedContext { stacks = [elementStack: typedConstants(s, elementStack)] }
        switch call.variant {
        case .v0, .v7: bind([.input0, .input1], to: args, in: &inputs)
        case .v1: bind(holes(in: block), to: args.reversed(), in: &inputs)
        default: if call.variant.bindsHoles { bind(holes(in: block), to: args, in: &inputs) }
        }

        guard let sub = sandbox(program, inputs: inputs, constants: s.constants, stacks: stacks,
                                budget: budget) else { return nil }
        let lastPushed = sub.lastPush.flatMap { sub.stacks[$0]?.first }
        let typedStack = resultStack ?? (call.family == .filter ? .bool : elementStack)
        let result = call.variant.hasTypedResult ? sub.stacks[typedStack]?.first : lastPushed
        return Run(result: result, lastPushed: lastPushed, lastStack: sub.lastPush, steps: sub.counter)
    }


    // MARK: - A whole application

    /// The block `call` applies: the situation's own, or its crux-made or
    /// projected replacement; nil if V7 finds no function.
    static func function(for call: Call, elementStack: PushStack) -> CodeItem? {
        var block = call.situation.block
        if call.variant == .v7 {
            guard let made = cruxFunction(call.situation, elementStack: elementStack,
                                          holesNeeded: call.family == .reduce ? 2 : 1) else { return nil }
            block = made
        }
        if call.variant.isProjected { block = projection(of: block, onto: elementStack, call.situation) }
        return block
    }

    /// The output of `call` over `elements`, or why it refused.
    static func output(_ call: Call, elements: [any Item], collection: any Item) -> Result<any Item, Refusal> {
        if call.variant.usesFunctionStack { return functionStackOutput(call, elements: elements) }
        let elementStack = PushStack.defaultStack(for: elements[0])!
        guard let block = function(for: call, elementStack: elementStack) else {
            return .failure(Refusal("no function"))
        }
        if call.variant == .v5 || call.variant == .v6 {
            return wholeStack(call, block, elements: elements, collection: collection)
        }
        switch call.family {
        case .map: return mapped(call, block, elements: elements)
        case .filter: return filtered(call, block, elements: elements, collection: collection)
        case .reduce: return folded(call, block, elements: elements)
        }
    }

    /// V5 and V6: one sandbox for the whole collection; what is left on the
    /// element type's stack is the output (its top, for reduce).
    static func wholeStack(_ call: Call, _ block: CodeItem, elements: [any Item],
                           collection: any Item) -> Result<any Item, Refusal> {
        let elementStack = PushStack.defaultStack(for: elements[0])!
        let iterate = InstructionItem(iterate(over: PushStack.defaultStack(for: collection)!))
        let program: [any Item]
        if call.variant == .v5 {
            program = elements + block.value
        } else if call.family == .reduce {
            guard let rest = rebuilt(Array(elements.dropFirst()), like: collection) else {
                return .failure(Refusal("unbuildable"))
            }
            program = [elements[0], rest, block, iterate]
        } else {
            program = [collection, block, iterate]
        }
        let s = call.situation
        guard let sub = sandbox(program, inputs: s.inputs, constants: s.constants, budget: budget) else {
            return .failure(Refusal("out of steps"))
        }
        let left = Array(sub.stacks[elementStack] ?? [])
        if call.family == .reduce {
            guard let top = left.first else { return .failure(Refusal("nothing left")) }
            return .success(top)
        }
        guard let gathered = rebuilt(left.reversed(), like: collection) else {
            return .failure(Refusal("mixed types"))
        }
        return .success(gathered)
    }

    static func mapped(_ call: Call, _ block: CodeItem, elements: [any Item]) -> Result<any Item, Refusal> {
        var results: [any Item] = []
        var used = 0
        // V17: the first element's run fixes the result's type, as the stack
        // it last pushed a value to; every later run is read from that stack.
        var pinned: PushStack?
        for element in elements {
            guard let run = applyOnce(call, block, args: [element], budget: budget - used,
                                      resultStack: pinned) else {
                return .failure(Refusal("out of steps"))
            }
            used += run.steps
            if call.variant == .v17 && pinned == nil {
                if let stack = run.lastStack, scalarStacks.contains(stack), let value = run.lastPushed {
                    pinned = stack
                    results.append(value)
                } else {
                    pinned = PushStack.defaultStack(for: element)
                    results.append(run.result ?? element)
                }
                continue
            }
            results.append(run.result ?? element)
        }
        guard let gathered = Interpreter.collected(results, call: []) else { return .failure(Refusal("mixed types")) }
        return .success(gathered)
    }

    static func filtered(_ call: Call, _ block: CodeItem, elements: [any Item],
                         collection: any Item) -> Result<any Item, Refusal> {
        var kept: [any Item] = []
        var used = 0
        for element in elements {
            guard let run = applyOnce(call, block, args: [element], budget: budget - used) else {
                return .failure(Refusal("out of steps"))
            }
            used += run.steps
            if (run.result as? BoolItem)?.value == true { kept.append(element) }
        }
        return .success(rebuilt(kept, like: collection)!)
    }

    static func folded(_ call: Call, _ block: CodeItem, elements: [any Item]) -> Result<any Item, Refusal> {
        var accumulator = elements[0]
        var used = 0
        for element in elements.dropFirst() {
            guard let run = applyOnce(call, block, args: [accumulator, element], budget: budget - used) else {
                return .failure(Refusal("out of steps"))
            }
            used += run.steps
            accumulator = run.result ?? accumulator
        }
        return .success(accumulator)
    }


    // MARK: - Classifying

    /// Classifies one variant's outcome on one situation.
    static func classify(_ variant: Variant, _ family: Family, _ s: Situation) -> Outcome {
        switch variant {
        case .v8: classifyByTrial(family, s)
        case .v12: classifyAfterLookup(.v10, family, s, criteria: [.takesType])
        case .v14: classifyAfterLookup(.v14, family, s, criteria: [.takesType])
        case .v15: classifyAfterLookup(.v14, family, s, criteria: [.doesFamilyJob])
        case .v16: classifyAfterLookup(.v14, family, s, criteria: [.doesFamilyJob, .takesType])
        case .v17: classifyAfterLookup(.v17, family, s,
                                       criteria: [family == .map ? .transforms : .doesFamilyJob, .takesType])
        default: classifyDirectly(Call(variant: variant, family: family, situation: s))
        }
    }

    /// V8: every block on `.code` under V3, top down; the first that depends
    /// on the element, else what the first block gave.
    static func classifyByTrial(_ family: Family, _ s: Situation) -> Outcome {
        var firstOutcome: Outcome?
        for block in (s.stacks[.code] ?? []).compactMap({ $0 as? CodeItem }) {
            var tried = s
            tried.block = block
            let outcome = classifyDirectly(Call(variant: .v3, family: family, situation: tried))
            if outcome == .dependent { return .dependent }
            if firstOutcome == nil { firstOutcome = outcome }
        }
        return firstOutcome ?? classifyDirectly(Call(variant: .v3, family: family, situation: s))
    }

    static func classifyDirectly(_ call: Call) -> Outcome {
        let s = call.situation
        guard var elements = elements(of: s.collection) else { return .refused("not a collection") }
        guard !elements.isEmpty else { return .emptyInput }
        if elements.count > maxElements { elements = Array(elements.prefix(maxElements)) }
        if call.family == .reduce && elements.count < 2 { return .tooShort }
        let collection = rebuilt(elements, like: s.collection)!

        let result: any Item
        switch output(call, elements: elements, collection: collection) {
        case .failure(let refusal): return .refused(refusal.why)
        case .success(let item): result = item
        }
        if let trivial = trivial(call.family, result, elements: elements, collection: collection) { return trivial }

        let changed = elements.map(perturbed)
        guard case .success(let other) = output(call, elements: changed,
                                                collection: rebuilt(changed, like: s.collection)!) else {
            return .dependent
        }
        if render(other) == render(result) { return .constant }
        let retyped = call.family == .map && type(of: result) != type(of: collection)
        return retyped ? .dependentRetyped : .dependent
    }

    /// The trivial outcomes a result can be recognized as without a second run.
    static func trivial(_ family: Family, _ result: any Item, elements: [any Item],
                        collection: any Item) -> Outcome? {
        switch family {
        case .filter:
            return filterOutcome(kept: Self.elements(of: result) ?? [], from: elements)
        case .map:
            let mapped = Self.elements(of: result) ?? []
            if mapped.isEmpty { return .empty }
            if render(result) == render(collection) { return .identity }
            // A whole-stack harvest (V5, V6) can change the length or the order
            // without computing anything element by element.
            if mapped.count != elements.count { return .reshaped }
            if mapped.map(render).sorted() == elements.map(render).sorted() { return .rearranged }
        case .reduce:
            if render(result) == render(elements[0]) { return .first }
            if render(result) == render(elements[elements.count - 1]) { return .last }
        }
        return nil
    }

    /// What a filter that kept `kept` of `elements` did: nothing, everything,
    /// exactly the trues or falses of a bool collection, or something else.
    static func filterOutcome(kept: [any Item], from elements: [any Item]) -> Outcome {
        if kept.isEmpty { return .empty }
        if kept.count == elements.count { return .all }
        let flags = elements.compactMap { ($0 as? BoolItem)?.value }
        let keptFlags = kept.compactMap { ($0 as? BoolItem)?.value }
        if flags.count == elements.count, Set(keptFlags).count == 1, let value = keptFlags.first,
           keptFlags.count == flags.filter({ $0 == value }).count {
            return value ? .keptTrues : .keptFalses
        }
        return .dependent
    }
}
