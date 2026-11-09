//
//  BackwardChaining.swift
//  PushInterpreter
//
//  Chaining backwards over the input-output map (Roadmap #41): from the stack a
//  problem wants, through the instructions that produce it, down to the inputs
//  and constants the problem provides.
//

/// One instruction the chainer can use: an operation with a single fixed result
/// whose arguments all come from data stacks.
nonisolated struct ChainEdge: Sendable {
    let name: PushInstruction
    /// The argument stacks in requirement order: the first is claimed from the
    /// top of its stack, so its subtree is written last.
    let inputs: [PushStack]
    let result: PushStack
    /// What a query reads and leaves, sorted by stack, for the cleanup that
    /// leaves only its result (`Behavior.reading`). Empty for a consuming
    /// operation.
    let readCounts: [(key: PushStack, value: Int)]
}


/// **A tree of instructions that produces one value**: an instruction applied to
/// trees for each of its arguments, or a leaf (an input or a constant). It is the
/// shape of a provenance DAG, read top-down, and like a crux it is a well-formed
/// fragment: run alone, it leaves its result and nothing else.
nonisolated indirect enum Derivation: Sendable {
    case leaf(PushInstruction)
    case apply(ChainEdge, [Derivation])

    /// Instructions applied, leaves not counted.
    var size: Int {
        switch self {
        case .leaf: 0
        case .apply(_, let children): 1 + children.reduce(0) { $0 + $1.size }
        }
    }

    /// The fragment as a program. Arguments are written in reverse requirement
    /// order, so the first requirement's value ends on top where it claims; a
    /// query is followed by the cleanup of what it read.
    var program: [any Item] {
        switch self {
        case .leaf(let name):
            return [InstructionItem(name)]
        case .apply(let edge, let children):
            return children.reversed().flatMap(\.program)
                + Behavior.reading(sorted: edge.readCounts, producing: edge.result, from: [InstructionItem(edge.name)])
        }
    }
}


/// **Backward chaining over the declared signatures.** Built for one problem: the
/// type of each input it binds, and whether the program may use constants. It
/// counts the trees up to a given height that produce a stack, and samples them
/// uniformly by those counts.
///
/// Uses only the part of the map that is already exact: operations whose
/// `Produces` is a single fixed result and whose arguments are taken or read from
/// data stacks. Not yet: structural rules and control (no typed output), the
/// alternatives and the cuts (more than one possible or actual result), and
/// anything taking `.exec`.
nonisolated struct BackwardChainer: Sendable {

    /// Leaves by stack: the problem's inputs, then the constants.
    let leaves: [PushStack: [PushInstruction]]
    /// Usable instructions by the stack they produce.
    let producers: [PushStack: [ChainEdge]]

    /// `cruxOnly` admits the instructions tagged `.cruxOnly` (the iterator
    /// constructors, five to seven arguments each), which a sampled tree would
    /// otherwise be dominated by: uniform over trees means weighted by arity.
    init(inputs: [PushInstruction: PushStack], constants: Bool = true, cruxOnly: Bool = false,
         excluding: Set<PushInstruction> = []) {
        var leaves: [PushStack: [PushInstruction]] = [:]
        for (name, stack) in inputs.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            leaves[stack, default: []].append(name)
        }
        var producers: [PushStack: [ChainEdge]] = [:]
        for (name, behavior) in Interpreter.language.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        where !excluding.contains(name) && (cruxOnly || !behavior.tags.contains(.cruxOnly)) {
            if constants, case .deferred(let stack) = behavior.produces {
                leaves[stack, default: []].append(name)
                continue
            }
            if let edge = Self.edge(name, behavior) { producers[edge.result, default: []].append(edge) }
        }
        self.leaves = leaves
        self.producers = producers
    }

    /// `behavior` as an edge, if the chainer can use it.
    static func edge(_ name: PushInstruction, _ behavior: Behavior) -> ChainEdge? {
        guard behavior.behaviorClass == .operation, case .results(let results) = behavior.produces,
              results.count == 1 else { return nil }
        var inputs: [PushStack] = [], reads: [PushStack: Int] = [:]
        for requirement in behavior.requirements {
            switch requirement {
            case .takes(let stack): inputs.append(stack)
            case .reads(let stack): inputs.append(stack); reads[stack, default: 0] += 1
            case .needs, .takesMany: return nil
            }
        }
        guard !inputs.contains(where: { [.exec, .error].contains($0) }) else { return nil }
        let readCounts = reads.sorted { $0.key.rawValue < $1.key.rawValue }.map { (key: $0.key, value: $0.value) }
        return ChainEdge(name: name, inputs: inputs, result: results[0], readCounts: readCounts)
    }

    /// How many distinct trees of height at most `height` produce `goal` (a leaf
    /// has height 0). A `Double`, because it grows fast: products of counts.
    func count(_ goal: PushStack, height: Int) -> Double {
        var memo: [Key: Double] = [:]
        return count(goal, height, &memo)
    }

    private struct Key: Hashable { let stack: PushStack, height: Int }

    private func count(_ goal: PushStack, _ height: Int, _ memo: inout [Key: Double]) -> Double {
        let key = Key(stack: goal, height: height)
        if let known = memo[key] { return known }
        var total = Double(leaves[goal]?.count ?? 0)
        if height > 0 {
            for edge in producers[goal] ?? [] { total += weight(edge, height, &memo) }
        }
        memo[key] = total
        return total
    }

    private func weight(_ edge: ChainEdge, _ height: Int, _ memo: inout [Key: Double]) -> Double {
        edge.inputs.reduce(1.0) { $0 * count($1, height - 1, &memo) }
    }

    /// A tree of height at most `height` producing `goal`, drawn uniformly from
    /// all of them; nil if there is none.
    func sample(_ goal: PushStack, height: Int, using rng: inout some RandomNumberGenerator) -> Derivation? {
        var memo: [Key: Double] = [:]
        return sample(goal, height, &memo, &rng)
    }

    private func sample(_ goal: PushStack, _ height: Int, _ memo: inout [Key: Double],
                        _ rng: inout some RandomNumberGenerator) -> Derivation? {
        let total = count(goal, height, &memo)
        guard total > 0 else { return nil }
        var pick = Double.random(in: 0..<total, using: &rng)
        for leaf in leaves[goal] ?? [] {
            if pick < 1 { return .leaf(leaf) }
            pick -= 1
        }
        var chosen: ChainEdge?
        for edge in height > 0 ? producers[goal] ?? [] : [] {
            let share = weight(edge, height, &memo)
            guard share > 0 else { continue }
            chosen = edge   // the last with any weight, should rounding overrun the total
            if pick < share { break }
            pick -= share
        }
        guard let chosen else { return nil }
        var children: [Derivation] = []
        for input in chosen.inputs {
            guard let child = sample(input, height - 1, &memo, &rng) else { return nil }
            children.append(child)
        }
        return .apply(chosen, children)
    }
}
