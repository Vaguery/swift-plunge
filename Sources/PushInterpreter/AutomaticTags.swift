//
//  AutomaticTags.swift
//  PushInterpreter
//
//  The derived half of the standard tags: each computed from what the Behaviors
//  declare (requirements, observed stacks, outputs, class, body and declared
//  tags), never from instruction names. Each tag's rule is stated in its
//  `rationale` (`InstructionTag.swift`); the code below is that rule.
//
//  The rules are meant to explain, not to be exact. Where two instructions have
//  identical declarations they get identical tags, even if they do different
//  things: `vecIntIndexOf` and `vecIntPeekNth` are both `vecInt, int → int`, and
//  nothing declared says one int is an element and the other an index. A finer
//  label is anyone's to add (`InstructionTagging.adding(_:to:)`).
//

nonisolated extension Interpreter {

    /// The derived tags, computed once from `language`.
    static let automaticTags: [InstructionTag: Set<PushInstruction>] = {
        var result: [InstructionTag: Set<PushInstruction>] = [:]
        let generatedFamily = Set(combinatorBehaviors.keys)
        for (name, behavior) in language {
            for tag in AutomaticTagging(behavior, inGeneratedFamily: generatedFamily.contains(name)).tags {
                result[tag, default: []].insert(name)
            }
        }
        return result
    }()
}

/// One Behavior's declarations, read for tagging.
nonisolated struct AutomaticTagging {

    static let scalars: Set<PushStack> = [.bool, .int, .double, .char]
    static let numbers: Set<PushStack> = [.int, .double]
    static let text: Set<PushStack> = [.char, .string, .vecString]
    static let vectors: Set<PushStack> = [.vecBool, .vecInt, .vecDouble, .vecString]
    static let collections: Set<PushStack> = vectors.union([.string, .code])
    static let reified: Set<PushStack> = [.iterator, .binding]

    /// A collection's element stack: what taking one element out of it gives.
    static func element(of stack: PushStack) -> PushStack? {
        switch stack {
        case .string: .char
        case .vecBool: .bool
        case .vecInt: .int
        case .vecDouble: .double
        case .vecString: .string
        default: nil
        }
    }

    let behavior: Behavior
    let inGeneratedFamily: Bool
    /// Consumed, in order (`.takes`, and `.takesMany` once).
    let taken: [PushStack]
    /// Read and left, in order.
    let read: [PushStack]
    /// Read, then observed without an argument.
    let looked: [PushStack]
    let needed: Set<PushStack>
    let variadic: Bool
    /// The value stacks of the declared output, every alternative included.
    let outputs: [PushStack]
    /// Every stack it takes, reads, observes, needs, gives or rearranges, `.error` aside.
    let touched: Set<PushStack>

    init(_ behavior: Behavior, inGeneratedFamily: Bool) {
        self.behavior = behavior
        self.inGeneratedFamily = inGeneratedFamily
        var taken: [PushStack] = [], read: [PushStack] = [], needed: Set<PushStack> = [], variadic = false
        for requirement in behavior.requirements {
            switch requirement {
            case .takes(let stack): taken.append(stack)
            case .reads(let stack): read.append(stack)
            case .needs(let stack, _): needed.insert(stack)
            case .takesMany(let stack, _): taken.append(stack); variadic = true
            }
        }
        self.taken = taken
        self.read = read
        self.looked = read + behavior.observes
        self.needed = needed
        self.variadic = variadic
        let outputs: [PushStack] = switch behavior.produces {
        case .results(let stacks): stacks
        case .alternatives(let options): options.flatMap { $0 }
        case .deferred(let stack), .delivery(let stack): [stack]
        case .positions, .continuation, .input, .printout: []
        }
        self.outputs = outputs
        var touched = Set(taken + looked + outputs).union(needed)
        if case .positions(let stack) = behavior.produces { touched.insert(stack) }
        touched.remove(.error)
        self.touched = touched
    }

    var isFixedResults: Bool { if case .results = behavior.produces { true } else { false } }
    var isAlternatives: Bool { if case .alternatives = behavior.produces { true } else { false } }
    var isApplying: Bool { if case .applying = behavior.body { true } else { false } }
    var reEntrant: Bool { behavior.tags.contains(.reEntrant) }
    var fallible: Bool { behavior.tags.contains(.fallible) }
    var data: Set<PushStack> { Set(taken + looked) }

    var tags: Set<InstructionTag> {
        var tags = typeTags.union(kindTags).union(costTags)
        tags.insert(classTag)
        if isBridge { tags.insert(.bridge) }
        if !tags.contains(where: { $0.facet == .kind }) && behavior.behaviorClass != .channel {
            tags.insert(.complicated)
        }
        return tags
    }

    var classTag: InstructionTag {
        switch behavior.behaviorClass {
        case .operation: .operation
        case .structural: .structural
        case .contextRead: .contextRead
        case .control: .control
        case .channel: .channel
        }
    }

    var typeTags: Set<InstructionTag> {
        var tags: Set<InstructionTag> = []
        guard !touched.isEmpty else { return tags }
        if touched.isSubset(of: Self.scalars) { tags.insert(.scalar) }
        if touched.isSubset(of: Self.numbers) { tags.insert(.numeric) }
        if !touched.isDisjoint(with: Self.text) { tags.insert(.textual) }
        if !touched.isDisjoint(with: Self.collections) { tags.insert(.collection) }
        if !touched.isDisjoint(with: Self.vectors) { tags.insert(.vector) }
        if !touched.isDisjoint(with: Self.reified) { tags.insert(.reified) }
        return tags
    }

    var kindTags: Set<InstructionTag> {
        var tags: Set<InstructionTag> = []
        let kind = behavior.behaviorClass
        if isCalculation { tags.insert(.calculation) }
        tags.formUnion(inspectionTags)
        if kind == .structural || inGeneratedFamily { tags.insert(.stackCombinator) }

        let loops = reEntrant || isApplying || behavior.tags.contains(.looping)
        let applies = isApplying || (kind == .control && !read.isEmpty && taken.contains(.code) && !loops)
        let branches = kind == .control && taken.contains(.bool) && !loops
        if loops { tags.insert(.looping) }
        if applies { tags.insert(.higherOrder) }
        if branches { tags.insert(.branching) }
        if behavior.produces == .continuation && !loops && !applies && !branches { tags.insert(.execution) }

        tags.formUnion(transformationTags)
        switch behavior.produces {
        case .deferred, .input: tags.insert(.source)
        default: break
        }
        if kind == .contextRead, isFixedResults, outputs.count == 1, outputs[0] == .int || outputs[0] == .bool,
           read.isEmpty, !touched.contains(.binding), !tags.contains(.search) {
            tags.insert(.introspection)
        }
        let bindingResults = isFixedResults || { if case .alternatives = behavior.produces { true } else { false } }()
        if data.union(needed).contains(.binding) || behavior.produces == .positions(.binding)
            || (bindingResults && outputs.contains(.binding) && Set(outputs).isSubset(of: [.binding, .int])) {
            tags.insert(.naming)
        }
        if Set(outputs).contains(.iterator) && behavior.produces != .continuation
            && Set(outputs).isSubset(of: [.iterator, .code, .int, .bool])
            || isIteratorSetter || read.contains(.iterator) {
            tags.insert(.iterators)
        }
        return tags
    }

    /// An iterator in, an iterator out (a setter), with perhaps the body of a loop
    /// it ended beside it.
    var isIteratorSetter: Bool { taken.contains(.iterator) && outputs.contains(.iterator) }

    var isCalculation: Bool {
        guard behavior.behaviorClass == .operation, case .values = behavior.body,
              taken.isEmpty != read.isEmpty else { return false }
        let stacks = Set(taken + read + outputs)
        return stacks.count == 1 && stacks.isSubset(of: Self.scalars)
    }

    var inspectionTags: Set<InstructionTag> {
        let kind = behavior.behaviorClass
        guard !looked.isEmpty, Set(taken).isSubset(of: [.int]), needed.isEmpty,
              kind == .operation || kind == .contextRead, isFixedResults || isAlternatives,
              !outputs.isEmpty, !(isFixedResults && outputs.contains(.binding)) else { return [] }
        var tags: Set<InstructionTag> = [.inspection]
        if outputs == [.bool] {
            tags.insert(.detection)
            if read.count == 2 && read[0] == read[1] { tags.insert(.comparison) }
        }
        if outputs == [.int], !Set(looked).subtracting([.int]).isEmpty, looked.count == 1 || !fallible {
            tags.insert(.measurement)
        }
        let withPosition = outputs.count == 2 && outputs[1] == .int
        let refusingIndex = outputs == [.int] && looked.count >= 2 && fallible
        let element = kind == .operation && fallible && outputs != [.bool]
            && (looked.contains { stack in Self.element(of: stack).map(outputs.contains) ?? false }
                || (outputs == [.code] && looked.contains(.code)))
        if withPosition || refusingIndex || element { tags.insert(.search) }
        return tags
    }

    var transformationTags: Set<InstructionTag> {
        guard behavior.behaviorClass == .operation, !taken.isEmpty, !outputs.isEmpty, !isCalculation,
              !touched.contains(.binding), !outputs.contains(.iterator) else { return [] }
        var tags: Set<InstructionTag> = [.transformation]
        let inputs = Set(taken)
        let elementOut = taken.contains { stack in Self.element(of: stack).map(outputs.contains) ?? false }
        if outputs == [.code] && taken.count == 1 && taken[0] != .code {
            tags.insert(.conversion)
        } else if inputs.count == 1 && inputs.isDisjoint(with: outputs) && !elementOut {
            tags.insert(.conversion)
        }
        if outputs.count == 1, Self.collections.contains(outputs[0]) {
            let collection = outputs[0]
            var pairs: Set<[PushStack]> = [[collection, collection]]
            if let element = Self.element(of: collection) {
                pairs.formUnion([[collection, element], [element, collection]])
            }
            if variadic || pairs.contains(taken) { tags.insert(.assembly) }
            if inputs.contains(collection) && isFixedResults { tags.insert(.reshaping) }
        }
        let delivers = if case .delivery = behavior.produces { true } else { false }
        let cuts = outputs.count == 2 && outputs[0] == outputs[1] && Self.collections.contains(outputs[0])
        if delivers || cuts || (elementOut && outputs.count == 1) { tags.insert(.disassembly) }
        return tags
    }

    var costTags: Set<InstructionTag> {
        var tags: Set<InstructionTag> = []
        switch behavior.produces {
        case .continuation, .delivery, .deferred, .input: tags.insert(.addsSteps)
        default: if reEntrant { tags.insert(.addsSteps) }
        }
        if reEntrant && Set(taken).isSubset(of: [.bool, .code]) && taken.count(where: { $0 == .code }) <= 1 {
            tags.insert(.mayRunUnbounded)
        }
        if isApplying { tags.insert(.runsSubprograms) }
        return tags
    }

    var isBridge: Bool {
        behavior.behaviorClass == .operation && !isIteratorSetter
            && !Set(outputs).subtracting(data).subtracting([.int, .bool]).isEmpty
    }
}
