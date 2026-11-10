//
//  InstructionSignature.swift
//  Plunge
//
//  One instruction's edge in the language's input-output map.
//

/// **What an instruction takes and what it gives**, read off its `Behavior`'s
/// declarations: its `requirements` for the inputs, its `Produces` for the
/// outputs, its `.fallible` tag for whether the edge is partial.
///
/// The language as a whole is a typed hypergraph of these: each instruction an
/// edge from a multiset of input stacks to one of a few output lists. It has cycles
/// (`intInc` is `.int → .int`), so it is not itself a DAG; chaining backwards from
/// the outputs a problem wants *builds* one, a provenance DAG, which is what a crux
/// already is.
public nonisolated struct InstructionSignature: Hashable, Sendable {

    /// The stacks it consumes from, and how many items from each. A variadic
    /// requirement (`vecIntConstruct`'s N ints) counts zero here and is listed in
    /// `variadic`.
    public let consumes: [PushStack: Int]

    /// The stacks it reads and leaves (the non-destructive queries).
    public let reads: [PushStack: Int]

    /// The stacks it requires items on without handing them to its code: what a
    /// structural rule reaches into.
    public let needs: [PushStack: Int]

    /// The stacks it consumes a number of items from that its arguments decide.
    public let variadic: Set<PushStack>

    /// The stacks it looks at through the run's state without claiming an
    /// argument: a lookup's stack, a binder's source, the bindings a key query
    /// searches.
    public let observes: Set<PushStack>

    /// What it puts out when it succeeds.
    public let produces: Produces

    /// Whether it can refuse arguments it found (`.fallible`): outside its domain
    /// it writes `.error` instead of `produces`. Starvation is not counted here;
    /// every instruction with inputs can starve.
    public let isPartial: Bool
}


public nonisolated extension InstructionSignature {

    /// Whether it takes, reads, observes, needs, gives or rearranges `stack`.
    func touches(_ stack: PushStack) -> Bool {
        consumes[stack] != nil || reads[stack] != nil || needs[stack] != nil || variadic.contains(stack)
            || observes.contains(stack) || produces.valueStacks.contains(stack) || produces == .positions(stack)
    }
}

nonisolated extension Behavior {

    /// This Behavior's edge in the input-output map.
    var signature: InstructionSignature {
        var consumes: [PushStack: Int] = [:], reads: [PushStack: Int] = [:]
        var needs: [PushStack: Int] = [:], variadic: Set<PushStack> = []
        for requirement in requirements {
            switch requirement {
            case .takes(let stack):             consumes[stack, default: 0] += 1
            case .reads(let stack):             reads[stack, default: 0] += 1
            case .needs(let stack, let count):  needs[stack, default: 0] += count
            case .takesMany(let stack, _):      variadic.insert(stack)
            }
        }
        return InstructionSignature(consumes: consumes, reads: reads, needs: needs, variadic: variadic,
                                    observes: Set(observes), produces: produces,
                                    isPartial: tags.contains(.fallible))
    }
}


nonisolated extension Interpreter {

    /// Every instruction's signature. Built once from the declarations, so it
    /// cannot fall out of step with the definitions.
    static let signatures: [PushInstruction: InstructionSignature] =
        language.mapValues(\.signature)

    /// The instructions that can put a value on each stack (`Produces.valueStacks`):
    /// the first step of chaining backwards from a wanted output.
    static let producers: [PushStack: Set<PushInstruction>] = {
        var result: [PushStack: Set<PushInstruction>] = [:]
        for (name, signature) in signatures {
            for stack in signature.produces.valueStacks { result[stack, default: []].insert(name) }
        }
        return result
    }()
}
