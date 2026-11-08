//
//  CruxSharing.swift
//  PushInterpreter
//
//  A crux that builds each shared value once. Added 2026-11-07 for provenance
//  completeness (Roadmap §P, step 3): see "Sharing" in
//  `Notes on Push/Provenance and the crux.md`.
//

/// **Provenance is a DAG, and a crux used to be its tree.** When one value feeds
/// several others (`.intDup` then `.intAdd`, or a non-destructive read such as
/// `.boolEq`, which leaves its arguments where they were), the histories that
/// use it hold the very same node. Flattening the tree wrote that node out once
/// per use: `x x .intAdd`, where the program ran `x .intDup .intAdd`. A loop
/// over a non-destructive read builds each value from the two before it, so the
/// program runs N steps and the flattened crux has fib(N) leaves. Every history
/// the round-trip fuzz saw elided was one of these: a few dozen distinct nodes
/// weighing tens of thousands.
///
/// So `crux()` builds each **shared** node once, before anything else, and leaves
/// it on its stack, and every use takes a copy (`.xDup`, `n .xYankDup`), the last
/// use taking the node itself (`.xSwap`, `n .xYank`, or nothing when it is
/// already in place). That is how the program itself reused the value, and it is
/// ordinary runnable Push. `x .intDup .intAdd` reads back as itself.
///
/// **It is a fixed point.** Dup and yank are rearrangements, which record nothing
/// (provenance law 1): the copy *is* the node, history included. So a replay
/// shares exactly the nodes the original shared, and nothing else, and its crux
/// comes out the same.
///
/// **Where a node may be reused.** Only in an *argument position*: before the
/// first instruction in its parent's `call`, where every element pushes exactly
/// one item (a node's crux nets its item on its stack, a literal pushes itself),
/// so the depth of every item on every stack is known. After an instruction
/// (a clean-up, a prefix argument read from `.exec`), elements are written out as
/// before. A history with no shared node comes out exactly as the flattened tree.
nonisolated enum CruxSharing {

    /// The crux of `root`: its history as runnable Push, each shared node built
    /// once. Falls back to the flattened tree if the history has nothing to share
    /// or the bookkeeping finds something it cannot account for (it never has).
    static func crux(of root: any Item) -> [any Item] {
        crux(of: root, limit: .max) ?? flattened(root)
    }

    /// The crux of `root`, or nil as soon as it would run past `limit` items:
    /// the push boundary's measure of a history (`Interpreter.push`), which costs
    /// at most `limit` however large the flattened tree has grown.
    static func crux(of root: any Item, limit: Int) -> [any Item]? {
        guard !root.call.isEmpty else { return [root] }
        let plan = restingStack(of: root) == nil ? nil : SharingPlan(root)
        if let plan, !plan.prelude.isEmpty {
            var emitter = SharingEmitter(plan, limit: limit)
            if let program = emitter.run(root) { return program }
            if emitter.overLimit { return nil }
        }
        var leaves: [any Item] = []
        return appendFlattened(root, to: &leaves, limit: limit) ? leaves : nil
    }

    /// The tree written out leaf by leaf, left to right: the crux before sharing,
    /// and still the crux of anything with no shared node. Iterative, because a
    /// history can nest deeper than a worker thread's stack allows recursion.
    static func flattened(_ item: any Item) -> [any Item] {
        var leaves: [any Item] = []
        appendFlattened(item, to: &leaves, limit: .max)
        return leaves
    }

    /// Appends `item`'s tree leaf by leaf; false, part-way, once `leaves` would
    /// hold more than `limit`.
    @discardableResult
    static func appendFlattened(_ item: any Item, to leaves: inout [any Item], limit: Int) -> Bool {
        if item.call.isEmpty { leaves.append(item); return leaves.count <= limit }
        var pending: [any Item] = item.call.reversed()
        while let next = pending.popLast() {
            if next.call.isEmpty {
                leaves.append(next)
                if leaves.count > limit { return false }
            } else {
                pending.append(contentsOf: next.call.reversed())
            }
        }
        return true
    }

    // MARK: - Nodes

    /// A node of the history: an item with a `call`, identified by the storage of
    /// that `call`. Copies made by dup or yank share it; a value rebuilt by another
    /// route does not. The type is part of the key, so two results of one
    /// instruction on different stacks are never confused.
    struct Key: Hashable {
        let storage: UnsafeRawPointer
        let type: ObjectIdentifier
    }

    static func key(_ item: any Item) -> Key? {
        let call = item.call
        guard !call.isEmpty else { return nil }
        return call.withUnsafeBufferPointer { buffer in
            buffer.baseAddress.map { Key(storage: UnsafeRawPointer($0), type: ObjectIdentifier(type(of: item))) }
        }
    }

    /// Where `element` comes to rest when its crux runs: a node's crux, or a
    /// literal, nets one item on this stack. A stand-in pushes the value it stands
    /// in for. `nil` for an instruction, which ends the argument positions.
    static func restingStack(of element: any Item) -> PushStack? {
        if let standIn = element.exactly(StandInItem.self) {
            return PushStack.defaultStack(for: standIn.value)
        }
        return PushStack.defaultStack(for: element)
    }

    /// How many leading elements of `call` are argument positions.
    static func argumentCount(_ call: [any Item]) -> Int {
        call.firstIndex { restingStack(of: $0) == nil } ?? call.count
    }

    /// `element`'s key if it is a node whose stack can copy and move it.
    static func shareableKey(_ element: any Item) -> Key? {
        guard let stack = restingStack(of: element), stack.canShare else { return nil }
        return key(element)
    }
}

// MARK: - Planning a shared crux

/// Which nodes are shared, and in what order to build them.
nonisolated struct SharingPlan {
    /// How many argument positions use each node, counting every node once
    /// (each is built once).
    var uses: [CruxSharing.Key: Int] = [:]
    /// The shared nodes (used twice or more), children before parents.
    var prelude: [(key: CruxSharing.Key, item: any Item)] = []

    /// A node whose arguments are being visited.
    private struct Frame {
        let call: [any Item]
        let end: Int
        var index = 0
        let key: CruxSharing.Key?
        let item: any Item
    }

    init(_ root: any Item) {
        var visited: Set<CruxSharing.Key> = []
        var finished: [(key: CruxSharing.Key, item: any Item)] = []
        let rootCall = root.call
        var frames = [Frame(call: rootCall, end: CruxSharing.argumentCount(rootCall), key: nil, item: root)]
        while !frames.isEmpty {
            let top = frames.count - 1
            if frames[top].index < frames[top].end {
                let child = frames[top].call[frames[top].index]
                frames[top].index += 1
                guard let key = CruxSharing.shareableKey(child) else { continue }
                uses[key, default: 0] += 1
                if visited.insert(key).inserted {
                    let call = child.call
                    frames.append(Frame(call: call, end: CruxSharing.argumentCount(call), key: key, item: child))
                }
            } else {
                let done = frames.removeLast()
                if let key = done.key { finished.append((key, done.item)) }
            }
        }
        prelude = finished.filter { (uses[$0.key] ?? 0) >= 2 }
    }
}

// MARK: - Writing a shared crux

/// Writes the crux while keeping count of what every stack holds, so each use
/// of a shared node knows how deep its copy lies.
nonisolated struct SharingEmitter {
    /// One item on a stack, as far as the crux knows: a node (its key), or
    /// anything else (`nil`). `kept` marks a shared node's own copy, built in
    /// the prelude and waiting for its uses.
    struct Slot {
        let key: CruxSharing.Key?
        let kept: Bool
    }

    /// A node whose `call` is being written out.
    struct Frame {
        let call: [any Item]
        let end: Int
        var index = 0
        let key: CruxSharing.Key?
        let stack: PushStack
        let keep: Bool
        /// Each stack's height when the node began: everything above it is
        /// the node's arguments, which its instruction consumes.
        var bases: [Int]
    }

    let plan: SharingPlan
    let limit: Int
    /// Set when the crux ran past `limit`, as distinct from a miscount.
    private(set) var overLimit = false
    let shared: Set<CruxSharing.Key>
    var remaining: [CruxSharing.Key: Int]
    var stacks = Array(repeating: [Slot](), count: PushStack.allCases.count)
    var frames: [Frame] = []
    var output: [any Item] = []

    init(_ plan: SharingPlan, limit: Int) {
        self.plan = plan
        self.limit = limit
        let shared = Set(plan.prelude.map(\.key))
        self.shared = shared
        remaining = plan.uses.filter { shared.contains($0.key) }
    }

    /// The whole crux, or nil if the count of the stacks goes wrong.
    mutating func run(_ root: any Item) -> [any Item]? {
        for node in plan.prelude {
            guard write(node.item, key: node.key, keep: true) else { return nil }
        }
        guard write(root, key: nil, keep: false),
              remaining.values.allSatisfy({ $0 == 0 }) else { return nil }
        guard output.count <= limit else { overLimit = true; return nil }
        return output
    }

    /// Writes `node`'s `call`, then leaves one slot for it.
    private mutating func write(_ node: any Item, key: CruxSharing.Key?, keep: Bool) -> Bool {
        guard open(node, key: key, keep: keep) else { return false }
        while let top = frames.indices.last {
            guard output.count <= limit else { overLimit = true; return false }
            let index = frames[top].index
            guard index < frames[top].call.count else {
                guard close() else { return false }
                continue
            }
            frames[top].index += 1
            let element = frames[top].call[index]
            if index < frames[top].end {
                guard place(element) else { return false }
            } else {
                CruxSharing.appendFlattened(element, to: &output, limit: limit)
            }
        }
        return true
    }

    /// One argument: a use of a shared node, a node to write out in place, or a
    /// literal (or a node whose stack cannot share), written out and counted as
    /// one more item on its stack.
    private mutating func place(_ element: any Item) -> Bool {
        if let key = CruxSharing.key(element), shared.contains(key) {
            return reuse(element, key: key)
        }
        if let key = CruxSharing.shareableKey(element) {
            return open(element, key: key, keep: false)
        }
        guard let stack = CruxSharing.restingStack(of: element) else { return false }
        CruxSharing.appendFlattened(element, to: &output, limit: limit)
        stacks[stack.ordinal].append(Slot(key: nil, kept: false))
        return true
    }

    private mutating func open(_ node: any Item, key: CruxSharing.Key?, keep: Bool) -> Bool {
        guard let stack = CruxSharing.restingStack(of: node) else { return false }
        let call = node.call
        frames.append(Frame(call: call, end: CruxSharing.argumentCount(call), key: key,
                            stack: stack, keep: keep, bases: stacks.map(\.count)))
        return true
    }

    /// The node's instruction has consumed its arguments; one item, the node,
    /// stands in their place.
    private mutating func close() -> Bool {
        let frame = frames.removeLast()
        for ordinal in stacks.indices {
            let extra = stacks[ordinal].count - frame.bases[ordinal]
            guard extra >= 0 else { return false }
            stacks[ordinal].removeLast(extra)
        }
        stacks[frame.stack.ordinal].append(Slot(key: frame.key, kept: frame.keep))
        return true
    }

    /// One use of a shared node: a copy of its kept slot, or, for the last
    /// use, the kept slot itself.
    private mutating func reuse(_ element: any Item, key: CruxSharing.Key) -> Bool {
        guard let stack = CruxSharing.restingStack(of: element),
              let instructions = stack.sharingInstructions,
              let left = remaining[key], left > 0,
              let kept = stacks[stack.ordinal].lastIndex(where: { $0.kept && $0.key == key })
        else { return false }
        remaining[key] = left - 1
        let slots = stacks[stack.ordinal]
        let depth = slots.count - 1 - kept
        if left > 1 {
            // A copy. The top item serves as well as the kept one if it is
            // the same node.
            if depth == 0 || slots.last?.key == key {
                output.append(InstructionItem(instructions.dup))
            } else {
                output.append(contentsOf: [IntItem(depth), InstructionItem(instructions.yankDup)] as [any Item])
            }
            stacks[stack.ordinal].append(Slot(key: key, kept: false))
            return true
        }
        // The last use moves the kept slot to the top, which needs nothing
        // when everything above it is the same node.
        if depth > 0, !slots[(kept + 1)...].allSatisfy({ $0.key == key }) {
            if depth == 1 {
                output.append(InstructionItem(instructions.swap))
            } else {
                output.append(contentsOf: [IntItem(depth), InstructionItem(instructions.yank)] as [any Item])
            }
        }
        stacks[stack.ordinal].remove(at: kept)
        for frame in frames.indices where frames[frame].bases[stack.ordinal] > kept {
            frames[frame].bases[stack.ordinal] -= 1
        }
        stacks[stack.ordinal].append(Slot(key: key, kept: false))
        return true
    }
}

nonisolated extension PushStack {
    /// The instructions a crux uses to reuse a node on this stack.
    struct SharingInstructions {
        let dup: PushInstruction
        let swap: PushInstruction
        let yank: PushInstruction
        let yankDup: PushInstruction
    }

    private static let sharingByOrdinal: [SharingInstructions?] = allCases.map { stack in
        guard stack != .exec,
              let dup = PushInstruction(rawValue: "\(stack.rawValue)Dup"),
              let swap = PushInstruction(rawValue: "\(stack.rawValue)Swap"),
              let yank = PushInstruction(rawValue: "\(stack.rawValue)Yank"),
              let yankDup = PushInstruction(rawValue: "\(stack.rawValue)YankDup")
        else { return nil }
        return SharingInstructions(dup: dup, swap: swap, yank: yank, yankDup: yankDup)
    }

    /// This stack's dup, swap, yank and yankDup, or nil if it lacks one (`.error`)
    /// or is `.exec`, where a copy would run rather than rest.
    var sharingInstructions: SharingInstructions? { Self.sharingByOrdinal[ordinal] }

    /// Whether a crux can reuse a node resting on this stack.
    var canShare: Bool { sharingInstructions != nil }
}
