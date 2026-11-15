//
//  LoopMinimization.swift
//  Plunge
//
//  The loops in a crux run as few times as the result allows. Added 2026-11-15.
//

/// **A crux whose loops run no more often than the result needs.** A loop in a
/// random program often runs far longer than its result requires: its body
/// saturates (`7 .intMin` caps a count), reaches a fixed point, flips back and
/// forth (`.boolNot`), or feeds a value that a later step mostly throws away.
/// Its crux then repeats the body once per pass.
///
/// ``Item/minimizingLoops(on:settings:stack:)`` first folds every run of
/// identical passes in the history into a counted loop, `seed ( body ) K
/// .execDoTimes`, as the interpreter folds an over-budget history
/// (`CruxCompression`), and then looks for a smaller count for each loop. A
/// pass may be several levels of history: `1 .intAdd 7 .intMin` is two.
///
/// **This is a search, not a rewrite.** A smaller count is kept only when
/// replaying the whole crux with it gives the item's value on every case it was
/// given, so the result is exactly as trustworthy as the cases. The counts tried
/// are 0 to 8, then halvings of the count; between the largest count that failed
/// and the smallest that held, a bisection looks for one smaller still. Every
/// count kept was verified, whatever the bisection assumed.
public nonisolated struct LoopMinimization: Sendable {
    /// One loop whose count changed.
    public struct Change: Sendable, Hashable {
        public let from: Int, to: Int
    }

    /// The crux after folding and minimizing.
    public let program: [any Item]
    /// The loops whose counts were lowered, in the order they were tried.
    public let changes: [Change]
    /// How many counted loops the folded crux has.
    public let loops: Int
}

/// A case to verify against: inputs and constants.
public typealias CruxCase = (inputs: [PushInstruction: any Item], constants: [PushInstruction: any Item])

nonisolated extension Item {
    /// This item's crux with its loops folded and run as few times as keeps its
    /// value on every case in `cases`. The first case is the one the item was
    /// made on. See ``LoopMinimization``.
    public func minimizingLoops(on cases: [CruxCase], settings: InterpreterSettings = InterpreterSettings(),
                                stack: PushStack? = nil) -> LoopMinimization? {
        guard let stack = stack ?? PushStack.defaultStack(for: self), !cases.isEmpty else { return nil }
        let original = crux()
        var verifier = LoopVerifier(settings: settings, stack: stack, cases: cases)
        // What each case should give: this item on its own case, and the crux's
        // replay on the others.
        let targets = [pretty()] + cases.dropFirst().map { verifier.replay(original, $0) }
        verifier.targets = targets

        var current = HistoryRewrite.rewrite(self) { HistoryRewrite.foldedChain($0) }
        let loops = HistoryRewrite.foldCounts(in: current).count
        guard verifier.holds(current.crux()) else {
            // Folding alone changed something a case can see: give back the crux.
            return LoopMinimization(program: original, changes: [], loops: 0)
        }
        var changes: [LoopMinimization.Change] = []
        for ordinal in 0..<loops {
            let count = HistoryRewrite.foldCounts(in: current)[ordinal]
            guard count > 0, let lower = verifier.smallestCount(below: count, ordinal: ordinal, in: current) else {
                continue
            }
            current = HistoryRewrite.settingCount(of: ordinal, to: lower, in: current)
            changes.append(LoopMinimization.Change(from: count, to: lower))
        }
        return LoopMinimization(program: current.crux(), changes: changes, loops: loops)
    }
}

/// Replays cruxes on a list of cases and compares them with their targets.
private nonisolated struct LoopVerifier {
    let settings: InterpreterSettings
    let stack: PushStack
    let cases: [CruxCase]
    var targets: [String?] = []

    init(settings: InterpreterSettings, stack: PushStack, cases: [CruxCase]) {
        self.settings = settings
        self.stack = stack
        self.cases = cases
    }

    func replay(_ program: [any Item], _ given: CruxCase) -> String? {
        let room = max(settings.stepLimit, CruxCompression.replaySteps(program) * 2 + program.count)
        let redo = Interpreter()
        redo.config = settings.reconstructing
        redo.config.recordsProvenance = false
        redo.config.stepLimit = room
        redo.load(inputs: given.inputs, constants: given.constants, program: program)
        redo.run(stepLimit: room)
        guard redo.stacks[.exec]!.isEmpty else { return nil }
        return redo.stacks[stack]!.first?.pretty()
    }

    /// Whether `program` gives every case's target. A case whose target is
    /// unknown (the crux didn't replay there) is skipped.
    func holds(_ program: [any Item]) -> Bool {
        zip(cases, targets).allSatisfy { given, target in target == nil || replay(program, given) == target }
    }

    /// The smallest count found for loop `ordinal` below `count` that holds.
    func smallestCount(below count: Int, ordinal: Int, in root: any Item) -> Int? {
        func works(_ candidate: Int) -> Bool {
            holds(HistoryRewrite.settingCount(of: ordinal, to: candidate, in: root).crux())
        }
        var candidates = Set((0...8).filter { $0 < count })
        var halving = count / 2
        while halving > 8 {
            candidates.insert(halving)
            halving /= 2
        }
        if count > 9 { candidates.insert(count - 1) }
        var failed = -1
        for candidate in candidates.sorted() {
            if works(candidate) {
                // Bisect between the last failure and this success.
                var (low, high) = (failed, candidate)
                while high - low > 1 {
                    let middle = low + (high - low) / 2
                    if works(middle) { high = middle } else { low = middle }
                }
                return high
            }
            failed = candidate
        }
        return nil
    }
}

/// Rewriting a history bottom up, each distinct node once, so shared nodes stay
/// shared.
nonisolated enum HistoryRewrite {

    /// The distinct nodes under `root`, children before parents. Iterative.
    static func postOrder(_ root: any Item) -> [any Item] {
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
            for child in node.call.reversed() where !child.call.isEmpty {
                stack.append((child, false))
            }
        }
        return order
    }

    /// `root` with every node rebuilt from its rewritten children and then
    /// passed to `transform`, which may replace it.
    static func rewrite(_ root: any Item, _ transform: (any Item) -> (any Item)?) -> any Item {
        var memo: [CruxSharing.Key: any Item] = [:]
        for node in postOrder(root) {
            guard let key = CruxSharing.key(node) else { continue }
            var changed = false
            let children: [any Item] = node.call.map { child in
                guard let childKey = CruxSharing.key(child), let rewritten = memo[childKey],
                      CruxSharing.key(rewritten) != childKey else { return child }
                changed = true
                return rewritten
            }
            var rebuilt = node
            if changed, let holder = node as? any HoldsCall { rebuilt = holder.recalled(children) }
            memo[key] = transform(rebuilt) ?? rebuilt
        }
        return CruxSharing.key(root).flatMap { memo[$0] } ?? root
    }

    /// `node` as the top of a run of identical passes folded into a counted loop,
    /// `seed ( body ) K .execDoTimes .codePop`, or nil if it is not the top of at
    /// least `minimumPasses` passes. A pass is `period` levels down the first
    /// argument, each with the same other arguments (compared by structure) as
    /// the pass above. A run that ends on a loop folded before, with the same
    /// body, joins it.
    static func foldedChain(_ node: any Item, maxPeriod: Int = 4, minimumPasses: Int = 3) -> (any Item)? {
        foldedPass(node, maxPeriod: maxPeriod, minimumPasses: minimumPasses)?.fold
    }

    /// ``foldedChain(_:maxPeriod:minimumPasses:)``, also giving the levels of one
    /// pass, top first, so a caller can write the body from them. With
    /// `twoPassBody`, two passes are enough when the body has at least that many
    /// items.
    static func foldedPass(_ node: any Item, maxPeriod: Int = 4, minimumPasses: Int = 3,
                           twoPassBody: Int? = nil) -> (fold: any Item, pass: [any Item])? {
        guard let holder = node as? any HoldsCall, node.call.count >= 2 else { return nil }
        for period in 1...maxPeriod {
            // The first pass: `period` levels down the first argument.
            var pass: [any Item] = [node]
            while pass.count < period, let below = pass.last?.call.first, below.call.count >= 2,
                  CruxCompression.Fold(below) == nil {
                pass.append(below)
            }
            guard pass.count == period, let firstSeed = pass.last?.call.first else { continue }
            func sameAsFirst(_ level: any Item, _ offset: Int) -> Bool {
                let model = pass[offset]
                return type(of: level) == type(of: model) && level.call.count == model.call.count
                    && zip(level.call.dropFirst(), model.call.dropFirst()).allSatisfy {
                        CruxCompression.sameHistory($0, $1)
                    }
            }
            // Walk down while each further pass matches the first.
            var passes = 1
            var seed = firstSeed
            walk: while true {
                var cursor = seed
                for offset in 0..<period {
                    guard !cursor.call.isEmpty, sameAsFirst(cursor, offset) else { break walk }
                    cursor = cursor.call[0]
                }
                passes += 1
                seed = cursor
            }
            // A pass's body, bottom level first: each level's other arguments.
            let body = pass.reversed().flatMap { level in level.call.dropFirst().flatMap { $0.crux() } }
            var count = passes
            let enough = passes >= minimumPasses || (passes == 2 && twoPassBody.map { body.count >= $0 } ?? false)
            if let earlier = CruxCompression.Fold(seed), CruxCompression.sameLeaves(earlier.body, body) {
                seed = earlier.seed
                count += earlier.count
            } else if !enough {
                continue
            }
            let fold = holder.recalled([seed, CodeItem(body), IntItem(count), InstructionItem(.execDoTimes),
                                        InstructionItem(.codePop)])
            return (fold, pass)
        }
        return nil
    }

    /// The counts of the counted loops in `root`'s history, in post-order.
    static func foldCounts(in root: any Item) -> [Int] {
        postOrder(root).compactMap { CruxCompression.Fold($0)?.count }
    }

    /// `root` with the `ordinal`th loop (in post-order) running `count` times.
    static func settingCount(of ordinal: Int, to count: Int, in root: any Item) -> any Item {
        var seen = 0
        return rewrite(root) { node in
            guard CruxCompression.Fold(node) != nil, let holder = node as? any HoldsCall else { return nil }
            defer { seen += 1 }
            guard seen == ordinal else { return nil }
            var call = node.call
            call[2] = IntItem(count)
            return holder.recalled(call)
        }
    }
}
