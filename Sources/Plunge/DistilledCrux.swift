//
//  DistilledCrux.swift
//  Plunge
//
//  A crux with its constant-only work replaced by the values that work made.
//  Added 2026-11-15.
//

/// **A crux with its constant work distilled away.** A history records every
/// step that made an item, including whole branches that read nothing but
/// literals and constant slots: a constant string reversed, a character at a
/// constant index removed, the result used to filter a constant `vecString`.
/// Such a branch gives the same value whenever the constants are the same, so a
/// distilled crux puts that value in its place, as a stand-in marked
/// `distilled`: `«distilled .vecStringFilter: ["ab" "c"]»`. Work that reads an
/// input, or the run's transient state (a stack depth, an error count), stays as
/// it was.
///
/// **What it promises.** Run with the same inputs and constants, a distilled crux
/// leaves the same value as the crux it came from, and it is never longer. The
/// two are different programs, so anything that inspects a program's own size or
/// shape may tell them apart, but no value they compute differs.
///
/// **This is not simplification.** No algebra is done: `x 1 .intAdd 1
/// .intSubtract` stays as it is when `x` reads an input. Only work whose inputs
/// are all constant is replaced, and its value is the one the run already
/// computed, so distilling evaluates nothing.
///
/// Each replaced branch is listed as a ``DerivedConstant``, with the constant
/// slots it read and the history it replaced, so a search can tune the new
/// constant on its own, or expand it again after changing a slot it read.
public nonisolated struct DistilledCrux: Sendable {
    /// The item, its history rewritten with the constant branches replaced.
    public let item: any Item
    /// The distilled crux: a program that reproduces `item`'s value.
    public let program: [any Item]
    /// The replaced branches, in the order their stand-ins appear in `program`.
    public let derived: [DerivedConstant]

    /// Whether anything was replaced.
    public var isChanged: Bool { !derived.isEmpty }
}

/// One branch of constant work that a distilled crux replaced by its value.
public nonisolated struct DerivedConstant: Sendable {
    /// Where its stand-in is in the distilled program.
    public let position: Int
    /// The value the branch made.
    public let value: any Item
    /// The instruction that finished the branch.
    public let source: PushInstruction?
    /// The item whose history was replaced, history included.
    public let original: any Item

    /// The constant slots the branch read, each once, in the order its crux
    /// first reads them. Empty when the branch read only literals, so that its
    /// value never changes.
    ///
    /// Walks each shared node once: written out as a tree, a history that reuses
    /// its values can grow exponentially.
    public var slotsRead: [PushInstruction] {
        var slots: [PushInstruction] = []
        var seenSlots = Set<PushInstruction>()
        var seenNodes = Set<CruxSharing.Key>()
        var pending: [any Item] = [original]
        while let node = pending.popLast() {
            if let key = CruxSharing.key(node), !seenNodes.insert(key).inserted { continue }
            if let instruction = node.exactly(InstructionItem.self)?.value,
               CruxDependence.token(instruction).contains(.constant), seenSlots.insert(instruction).inserted {
                slots.append(instruction)
            }
            // Children in reverse, so the first argument's slots are found first.
            pending.append(contentsOf: node.call.reversed())
        }
        return slots
    }

    /// The crux of the branch that was replaced.
    public var origin: [any Item] { original.crux() }
}

nonisolated extension DistilledCrux {
    /// The distilled crux with each run of identical passes rolled into a counted
    /// loop (`seed ( body ) K .execDoTimes`), by the same rule as the abstract
    /// crux's rolling (two passes are enough when the body has at least three
    /// items), but with shared values still built once, by dup and yank, as in
    /// ``program``. It replays to the same value.
    ///
    /// Its size counts a loop once and a reused value once: the abstract and
    /// skeleton forms also roll loops, but are written as trees, so a value used
    /// twice is written twice (swift-plunge, 2026-11-16).
    public var rolledProgram: [any Item] {
        HistoryRewrite.rewrite(item) { HistoryRewrite.foldedPass($0, twoPassBody: 3)?.fold }.crux()
    }
}

nonisolated extension Item {
    /// This item's crux with every branch of constant-only work replaced by its
    /// value. See ``DistilledCrux``.
    public func distilledCrux() -> DistilledCrux {
        var distiller = Distiller()
        let rewritten = distiller.rewrite(self)
        let program = rewritten.crux()
        // Match each distilled stand-in in the program to the branch it replaced.
        var pending = distiller.replaced
        var derived: [DerivedConstant] = []
        for (position, element) in program.enumerated() {
            guard let standIn = element.exactly(StandInItem.self), standIn.reason == .distilled,
                  let match = pending.firstIndex(where: { $0.matches(standIn) }) else { continue }
            let original = pending.remove(at: match).original
            derived.append(DerivedConstant(position: position, value: standIn.value, source: standIn.source,
                                           original: original))
        }
        return DistilledCrux(item: rewritten, program: program, derived: derived)
    }
}

/// Rewrites a history bottom up, each node once, so a node shared by several
/// parents is still one node afterwards and the distilled crux still builds it
/// once.
private nonisolated struct Distiller {
    struct Replacement {
        let original: any Item
        let source: PushInstruction?
        let printed: String

        func matches(_ standIn: StandInItem) -> Bool {
            standIn.source == source && standIn.value.pretty() == printed
        }
    }

    private var memo: [CruxSharing.Key: any Item] = [:]
    private(set) var replaced: [Replacement] = []

    /// Whether `node`'s history can be replaced by its value: it is constant
    /// work, more than a single leaf (a lone constant read stays a read), and its
    /// value comes to rest on the stack of its type. A printed item rests on
    /// `.print`, where a stand-in would not put it, so the print stays and only
    /// the work before it is replaced.
    static func isReplaceable(_ node: any Item) -> Bool {
        let call = node.call
        guard call.count > 1, node.cruxDependence.isConstantWork,
              let stack = PushStack.defaultStack(for: node), stack != .error else { return false }
        if let producer = producer(of: node), Interpreter.language[producer]?.behaviorClass == .channel {
            return false
        }
        return true
    }

    /// The instruction that made `node`: the first instruction in its `call`.
    static func producer(of node: any Item) -> PushInstruction? {
        node.call.lazy.compactMap { $0.exactly(InstructionItem.self)?.value }.first
    }

    /// `root` rewritten. Iterative, since a history can nest deeper than a
    /// worker thread's stack allows recursion.
    mutating func rewrite(_ root: any Item) -> any Item {
        guard !root.call.isEmpty else { return root }
        // Post-order over the distinct nodes.
        var order: [any Item] = []
        var visited = Set<CruxSharing.Key>()
        var stack: [(node: any Item, expanded: Bool)] = [(root, false)]
        while let (node, expanded) = stack.popLast() {
            guard let key = CruxSharing.key(node) else { continue }
            if expanded {
                order.append(node)
                continue
            }
            guard visited.insert(key).inserted else { continue }
            stack.append((node, true))
            // A replaceable node's own history is never looked at.
            if Self.isReplaceable(node) { continue }
            for child in node.call.reversed() where !child.call.isEmpty {
                stack.append((child, false))
            }
        }
        for node in order {
            guard let key = CruxSharing.key(node) else { continue }
            memo[key] = rebuilt(node)
        }
        return CruxSharing.key(root).flatMap { memo[$0] } ?? root
    }

    /// `node` with its children already rewritten, or replaced by its value.
    private mutating func rebuilt(_ node: any Item) -> any Item {
        if Self.isReplaceable(node) {
            let source = Self.producer(of: node)
            var value = node
            value.call = [StandInItem(standingInFor: node, source: source, reason: .distilled)]
            replaced.append(Replacement(original: node, source: source, printed: value.pretty()))
            return value
        }
        let call = node.call
        var changed = false
        let children: [any Item] = call.map { child in
            guard let key = CruxSharing.key(child), let rewritten = memo[key] else { return child }
            if let rewrittenKey = CruxSharing.key(rewritten), rewrittenKey == key { return child }
            changed = true
            return rewritten
        }
        guard changed, let holder = node as? any HoldsCall else { return node }
        return holder.recalled(children)
    }
}
