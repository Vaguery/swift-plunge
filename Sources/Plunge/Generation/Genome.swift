//
//  Genome.swift
//  Plunge
//
//  What search operators edit, and how it becomes a program (2026-11-19). The
//  maintainer's ruling for PlungeGP's D1: an individual includes its genome,
//  because the genome is where every search operator acts.
//

/// How a ``Genome`` becomes a program. There is one encoding so far; a search
/// that adds another registers its own translation.
public nonisolated enum GenomeEncoding: String, Sendable, Codable, CaseIterable {
    /// Instruction tokens cut into code blocks by a plan (``GenomePiece``). With no
    /// plan of its own, a genome's plan is the Fibonacci default: blocks of 1, 1,
    /// 2, 3, 5, … tokens cut from the head, placed in the order its permutation
    /// gives, ahead of the remaining tokens.
    case fibonacci
}


/// One code block in a genome's plan: where its tokens are cut from, and where
/// the block is placed.
///
/// A plan is applied in two passes. **Cut:** the pieces are taken in order, and
/// each cuts `length` tokens starting at `start`, counted in what is left of the
/// genome's tokens after the earlier pieces' cuts. The tokens left over form the
/// top level of the program, the *trunk*. **Place:** the pieces are taken in
/// order again; each is wrapped as a code block and inserted at position `at`
/// into a later piece (`into`) or into the trunk (`into` nil), counting the items
/// already there.
///
/// A piece can only be placed into a *later* piece, so every piece is complete
/// before it is wrapped and nesting can never loop. Every number is clamped
/// (and `into` that names no later piece means the trunk), so any plan, however
/// a search edits it, gives a program.
public nonisolated struct GenomePiece: Sendable, Hashable, Codable {
    /// Where the piece's tokens begin, among the tokens the earlier pieces left.
    public var start: Int
    /// How many tokens it cuts. Zero makes an empty code block.
    public var length: Int
    /// The later piece it is placed into, or nil for the trunk.
    public var into: Int?
    /// Where it is inserted, among the items its container holds when it is placed.
    public var at: Int

    public init(start: Int, length: Int, into: Int? = nil, at: Int) {
        self.start = start
        self.length = length
        self.into = into
        self.at = at
    }
}


/// What a search edits: instruction tokens, constants, and how the tokens become
/// a program with code blocks.
///
/// Every part can be edited, and every edit gives a program:
/// - **`tokens`**: the instructions, in order.
/// - **`constants`**: the values of `.constant(k)` slots, of any type. To change a
///   constant, change its value; a token names only the slot it reads.
/// - **`permutation`**: numbers whose sorted order is the order the default plan
///   places its blocks in. Empty places them in the order they were cut.
/// - **`codeTarget`**: how much of the genome the default plan cuts into blocks,
///   from 0 (none) to 1 (all of it). Nil is the long-standing third.
/// - **`plan`**: an explicit ``GenomePiece`` list. Nil uses the default, made from
///   the length, the code target and the permutation; an explicit plan replaces
///   all three.
///
/// ```swift
/// let genome = Genome(tokens: [.intAdd, .input(0), .constant(0), .intMultiply], constants: [.constant(0): IntItem(3)])
/// genome.translate()          // ( .intAdd ) ( .input0 ) .constant0 .intMultiply
/// Genome(program: genome.translate(), constants: genome.constants)   // the same program back
/// ```
///
/// See <doc:Genomes>.
public nonisolated struct Genome: Sendable {
    /// How the genome becomes a program.
    public var encoding: GenomeEncoding
    /// The instruction tokens, in order.
    public var tokens: [PushInstruction]
    /// The constants' values, by slot (`.constant(k)`), each of any type.
    public var constants: [PushInstruction: any Item]
    /// The default plan's placement order: its blocks go in the ascending order of
    /// these values, ties by position. Fitted to the number of blocks by cycling.
    public var permutation: [Double]
    /// The default plan's share of the genome cut into blocks: blocks are cut
    /// while the running total is at most this share. Nil is a third, in exact
    /// integers; 0 or less cuts no blocks; 1 or more cuts every token.
    public var codeTarget: Double?
    /// An explicit plan, or nil for the default one.
    public var plan: [GenomePiece]?

    public init(tokens: [PushInstruction], constants: [PushInstruction: any Item] = [:], permutation: [Double] = [],
                codeTarget: Double? = nil, plan: [GenomePiece]? = nil, encoding: GenomeEncoding = .fibonacci) {
        self.encoding = encoding
        self.tokens = tokens
        self.constants = constants
        self.permutation = permutation
        self.codeTarget = codeTarget
        self.plan = plan
    }
}


// MARK: - Translation

public nonisolated extension Genome {

    /// The plan the genome follows: its own, or the default one.
    var effectivePlan: [GenomePiece] {
        plan ?? Self.defaultPlan(tokenCount: tokens.count, permutation: permutation, codeTarget: codeTarget)
    }

    /// The program the genome encodes.
    func translate() -> [any Item] {
        Self.render(Self.assemble(tokenCount: tokens.count, plan: effectivePlan), tokens)
    }

    /// For each position of the translated program, in reading order (a code
    /// block, then its contents, then what follows it), the index of the token it
    /// came from; nil for a code block's own position. The map a search uses to
    /// turn a program position into a genome edit.
    func tokenIndices() -> [Int?] {
        func flatten(_ nodes: [Node]) -> [Int?] {
            nodes.flatMap { node -> [Int?] in
                switch node {
                case .token(let index): [index]
                case .block(let inner): [nil] + flatten(inner)
                }
            }
        }
        return flatten(Self.assemble(tokenCount: tokens.count, plan: effectivePlan))
    }

    /// The default plan for `tokenCount` tokens: blocks of 1, 1, 2, 3, 5, … tokens
    /// cut from the head while the running total is at most `codeTarget` of the
    /// whole (a third when nil), the last one cut short if the tokens run out, and
    /// placed at the top level in the order `permutation` sorts into, ahead of the
    /// tokens left over.
    static func defaultPlan(tokenCount: Int, permutation: [Double], codeTarget: Double?) -> [GenomePiece] {
        let lengths = defaultLengths(tokenCount: tokenCount, codeTarget: codeTarget)
        let order = FibonacciGenome.placementOrder(FibonacciGenome.adjustedPermutation(permutation,
                                                                                     toCount: lengths.count))
        var rank = [Int](repeating: 0, count: lengths.count)
        for (position, piece) in order.enumerated() { rank[piece] = position }
        // Each piece is placed after the earlier ones, so its position is the
        // number of earlier pieces that come before it in the placement order.
        return lengths.indices.map { piece in
            GenomePiece(start: 0, length: lengths[piece], into: nil,
                        at: (0..<piece).filter { rank[$0] < rank[piece] }.count)
        }
    }

    /// The lengths of the code blocks the default plan cuts from the head, in cut
    /// order: block *i* holds the tokens after the first *i* blocks'. Empty when the
    /// genome has an explicit plan, whose blocks need not come from the head.
    var headBlockLengths: [Int] {
        plan == nil ? Self.defaultLengths(tokenCount: tokens.count, codeTarget: codeTarget) : []
    }

    /// The Fibonacci block lengths for `count` tokens and a code target: 1, 1, 2,
    /// 3, 5, … up to the block that takes the running total past the target's
    /// share (a third when nil), without cutting the last one short.
    static func blockLengths(forGenomeOf count: Int, codeTarget: Double? = nil) -> [Int] {
        FibonacciGenome.blockLengths(forGenomeOf: count, codeTarget: codeTarget)
    }

    /// `permutation` fitted to exactly `count` values: truncated if longer, cycled
    /// if shorter (each further cycle nudged up by `epsilon`, so repeats break ties
    /// the same way every time), and `0, 1, 2, …` if empty.
    static func adjustedPermutation(_ permutation: [Double], toCount count: Int,
                                    epsilon: Double = 0.0001) -> [Double] {
        FibonacciGenome.adjustedPermutation(permutation, toCount: count, epsilon: epsilon)
    }

    /// The indices of `values` in ascending order of value, ties broken by index,
    /// a NaN sorting last: the order the default plan places its blocks in.
    static func placementOrder(_ values: [Double]) -> [Int] {
        FibonacciGenome.placementOrder(values)
    }

    /// The default plan's block lengths in cut order: the Fibonacci lengths the
    /// code target allows, the last cut short if the tokens run out.
    internal static func defaultLengths(tokenCount: Int, codeTarget: Double?) -> [Int] {
        var lengths: [Int] = []
        var cursor = 0
        for size in FibonacciGenome.blockLengths(forGenomeOf: tokenCount, codeTarget: codeTarget) {
            guard cursor < tokenCount else { break }
            let end = min(cursor + size, tokenCount)
            lengths.append(end - cursor)
            cursor = end
        }
        return lengths
    }
}


// MARK: - Assembly

nonisolated extension Genome {

    /// A program's shape, holding token indices instead of items.
    indirect enum Node {
        case token(Int)
        case block([Node])
    }

    /// The program `plan` builds from `tokenCount` tokens, as token indices. Every
    /// number in the plan is clamped, so any plan gives a program.
    static func assemble(tokenCount: Int, plan: [GenomePiece]) -> [Node] {
        var remaining = Array(0..<tokenCount)
        var contents: [[Node]] = []
        contents.reserveCapacity(plan.count + 1)
        for piece in plan {
            let start = min(max(piece.start, 0), remaining.count)
            let length = min(max(piece.length, 0), remaining.count - start)
            contents.append(remaining[start..<(start + length)].map(Node.token))
            remaining.removeSubrange(start..<(start + length))
        }
        let trunk = plan.count
        contents.append(remaining.map(Node.token))
        for (index, piece) in plan.enumerated() {
            let target = piece.into.flatMap { $0 > index && $0 < plan.count ? $0 : nil } ?? trunk
            let block = Node.block(contents[index])
            contents[target].insert(block, at: min(max(piece.at, 0), contents[target].count))
        }
        return contents[trunk]
    }

    /// `nodes` as items, each token index replaced by its instruction.
    static func render(_ nodes: [Node], _ tokens: [PushInstruction]) -> [any Item] {
        nodes.map { node -> any Item in
            switch node {
            case .token(let index): InstructionItem(tokens[index])
            case .block(let inner): CodeItem(render(inner, tokens))
            }
        }
    }
}


// MARK: - From a program back to a genome

public nonisolated extension Genome {

    /// The genome of `program`: the same program comes back from ``translate()``.
    ///
    /// - Instructions become the tokens, read left to right as the program is
    ///   printed. Code blocks become the plan.
    /// - Anything else in the program (a literal `3`, `"fizz"`, `true`, a function)
    ///   becomes a new constant slot and its token, numbered after the highest slot
    ///   in `constants`. A constant reaches its stack one step later than the literal
    ///   did, by way of `.exec`, and a crux names `.constantN` where it named the
    ///   literal.
    /// - **The default form when it fits.** If the program is shaped as the default
    ///   plan makes programs (code blocks of Fibonacci sizes, none nested, all ahead
    ///   of the other tokens), the genome has no explicit plan: its code target and
    ///   permutation say the same thing. Otherwise it has an explicit plan.
    ///
    /// The result depends only on `program` and `constants`, so the same program
    /// always gives the same genome.
    init(program: [any Item], constants: [PushInstruction: any Item] = [:]) {
        var allConstants = constants
        var nextSlot = (constants.keys.compactMap { $0.isConstant ? $0.slot : nil }.max() ?? -1) + 1
        func withoutLiterals(_ items: [any Item]) -> [any Item] {
            items.map { item -> any Item in
                if item is InstructionItem { return item }
                if let block = item.exactly(CodeItem.self) { return CodeItem(withoutLiterals(block.value)) }
                var value = item
                value.call = []
                let slot = PushInstruction.constant(nextSlot)
                nextSlot += 1
                allConstants[slot] = value
                return InstructionItem(slot)
            }
        }
        let structured = withoutLiterals(program)
        self = Self.defaultForm(of: structured, constants: allConstants)
            ?? Self.explicitForm(of: structured, constants: allConstants)
    }
}

nonisolated extension Genome {

    /// The genome of `program` with no explicit plan, if the default plan can make
    /// it. `program` holds only instructions and code blocks.
    static func defaultForm(of program: [any Item], constants: [PushInstruction: any Item]) -> Genome? {
        var blocks: [[PushInstruction]] = []
        var trunk: [PushInstruction] = []
        for item in program {
            if let block = item.exactly(CodeItem.self) {
                guard trunk.isEmpty else { return nil }   // a block after a token
                let inner = block.value.compactMap { ($0 as? InstructionItem)?.value }
                guard inner.count == block.value.count else { return nil }   // a nested block
                blocks.append(inner)
            } else if let instruction = item as? InstructionItem {
                trunk.append(instruction.value)
            } else {
                return nil
            }
        }
        let count = blocks.reduce(trunk.count) { $0 + $1.count }
        let sizes = blocks.map(\.count)
        guard let codeTarget = Self.codeTarget(giving: sizes, tokenCount: count) else { return nil }
        // Which block was cut where: in reading order, each takes the first unused
        // cut position of its size.
        let lengths = defaultLengths(tokenCount: count, codeTarget: codeTarget)
        var cutFor = [Int](repeating: -1, count: blocks.count)
        var used = Set<Int>()
        for (position, size) in sizes.enumerated() {
            guard let cut = lengths.indices.first(where: { !used.contains($0) && lengths[$0] == size }) else {
                return nil
            }
            used.insert(cut)
            cutFor[position] = cut
        }
        var blockAtCut = [Int](repeating: 0, count: blocks.count)
        for (position, cut) in cutFor.enumerated() { blockAtCut[cut] = position }
        let tokens = blockAtCut.flatMap { blocks[$0] } + trunk
        let permutation = blocks.isEmpty ? [] : blockAtCut.map(Double.init)
        let genome = Genome(tokens: tokens, constants: constants, permutation: permutation,
                            codeTarget: codeTarget)
        // A check that costs one translation: the default form must give the program back.
        return CodeItem(genome.translate()).pretty() == CodeItem(program).pretty() ? genome : nil
    }

    /// A code target that makes the default plan cut blocks of `sizes` (in any
    /// order) from `tokenCount` tokens: `.some(nil)` when the default third does,
    /// otherwise the middle of the range that does. Nil when none does.
    static func codeTarget(giving sizes: [Int], tokenCount: Int) -> Double?? {
        let wanted = sizes.sorted()
        func fits(_ target: Double?) -> Bool {
            defaultLengths(tokenCount: tokenCount, codeTarget: target).sorted() == wanted
        }
        if fits(nil) { return .some(nil) }
        if sizes.isEmpty { return tokenCount == 0 ? .some(nil) : fits(0) ? .some(0) : nil }
        // m blocks are cut when the running total after m - 1 blocks is within the
        // target and after m blocks is past it: aim between the two.
        var (previous, current, total, before) = (0, 1, 0, 0)
        for _ in 0..<sizes.count {
            before = total
            total += current
            (previous, current) = (current, previous + current)
        }
        let target = min(1, (Double(before) + Double(total)) / 2 / Double(max(tokenCount, 1)))
        if fits(target) { return .some(target) }
        return fits(1) ? .some(1) : nil
    }

    /// The genome of `program` with an explicit plan. `program` holds only
    /// instructions and code blocks. Tokens are in reading order; the pieces are
    /// the code blocks innermost first (each block after the blocks inside it), so
    /// every piece is placed into a later one.
    static func explicitForm(of program: [any Item], constants: [PushInstruction: any Item]) -> Genome {
        struct Block {
            var direct: [Int]       // the numbers of the tokens directly inside it
            var position: Int       // its index among its container's items
            var spanStart: Int      // the number of the first token inside it, at any depth
        }
        var tokens: [PushInstruction] = []
        var blocks: [Block] = []    // numbered as they close: innermost first
        var parents: [Int?] = []    // each block's container, nil for the trunk

        /// Reads `items`, numbering their tokens and closing their blocks; collects
        /// the tokens directly inside in `direct`, and returns the numbers of the
        /// blocks directly inside.
        func walk(_ items: [any Item], direct: inout [Int]) -> [Int] {
            var children: [Int] = []
            for (position, item) in items.enumerated() {
                if let block = item.exactly(CodeItem.self) {
                    let spanStart = tokens.count
                    var inner: [Int] = []
                    let grandchildren = walk(block.value, direct: &inner)
                    let number = blocks.count
                    blocks.append(Block(direct: inner, position: position, spanStart: spanStart))
                    parents.append(nil)
                    for grandchild in grandchildren { parents[grandchild] = number }
                    children.append(number)
                } else if let instruction = item as? InstructionItem {
                    direct.append(tokens.count)
                    tokens.append(instruction.value)
                }
            }
            return children
        }
        var trunk: [Int] = []
        _ = walk(program, direct: &trunk)

        // Cut each block's own tokens in closing order. Its children's tokens are
        // gone by then, so its own are one run of what remains.
        var remaining = Array(tokens.indices)
        var plan: [GenomePiece] = []
        for (number, block) in blocks.enumerated() {
            let start = block.direct.first.flatMap { remaining.firstIndex(of: $0) }
                ?? remaining.filter { $0 < block.spanStart }.count
            remaining.removeSubrange(start..<(start + block.direct.count))
            plan.append(GenomePiece(start: start, length: block.direct.count, into: parents[number], at: block.position))
        }
        return Genome(tokens: tokens, constants: constants, plan: plan)
    }
}


// MARK: - Encoding

extension Genome: Codable {
    private enum CodingKeys: String, CodingKey {
        case encoding, tokens, constants, permutation, codeTarget, plan
    }

    // `constants` holds `any Item`, so it bridges through `AnyItem` as a map keyed
    // by instruction name, as an `Individual`'s constants do.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            tokens: try container.decode([PushInstruction].self, forKey: .tokens),
            constants: ItemBindingCoding.decode(
                try container.decodeIfPresent([String: AnyItem].self, forKey: .constants) ?? [:]),
            permutation: try container.decodeIfPresent([Double].self, forKey: .permutation) ?? [],
            codeTarget: try container.decodeIfPresent(Double.self, forKey: .codeTarget),
            plan: try container.decodeIfPresent([GenomePiece].self, forKey: .plan),
            encoding: try container.decodeIfPresent(GenomeEncoding.self, forKey: .encoding) ?? .fibonacci)
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(encoding, forKey: .encoding)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(ItemBindingCoding.encode(constants), forKey: .constants)
        try container.encode(permutation, forKey: .permutation)
        try container.encodeIfPresent(codeTarget, forKey: .codeTarget)
        try container.encodeIfPresent(plan, forKey: .plan)
    }
}
