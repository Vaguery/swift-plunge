//
//  SourceTrace.swift
//  Plunge
//
//  Where in the program a run's items came from: a prototype for seeing cause and
//  effect between program positions, steps and cruxes (PlungeGP #56, #57;
//  2026-11-18).
//

/// One run, traced back to the positions of the program it ran.
///
/// Provenance records *what* an item was made from, not *where* in the program
/// that was. A source trace adds the where, for analysis only:
///
/// - **Literals keep their position.** Every item of the program, at every depth of
///   its code blocks, is tagged with its position before loading (`CallStorage.tagged`).
///   The tag rides in an otherwise empty history, so the item is still a literal to
///   the interpreter, and every copy of it (on `.code`, spread by `.codeDo`, duplicated)
///   carries the same tag.
/// - **Instructions are found by step.** A behavior records the instruction that
///   made an item by name, as a fresh `InstructionItem`, so its position can't ride
///   along. Instead the trace notes the step at which each history node was first
///   pushed, and the position of the item that step ran.
///
/// So a crux's leaves map to positions through their tags, and its nodes through
/// their steps. What neither reaches is counted as untraced: literals a behavior made
/// (an address's index, a count), and nodes built inside a step but never pushed.
/// Sandboxes (maps, function application) run with their own interpreters, so only
/// their results are seen.
///
/// Positions number the program in pre-order: a code block, then its contents, then
/// what follows it. Running a trace records provenance whatever the settings say.
public nonisolated struct SourceTrace {

    /// One item of the program, at any depth.
    public struct Position {
        public let item: any Item
        /// 0 for the program's own items, one more inside each code block.
        public let depth: Int
        /// The position of the code block holding it, if any.
        public let parent: Int?
        /// Whether this position is a code block (its contents follow it).
        public let isCodeBlock: Bool
    }

    /// One step of the run.
    public struct Step {
        /// The item the step ran (or moved to its stack), as it was on `.exec`.
        public let executed: any Item
        /// Its program position, if it was a tagged item of the program.
        public let position: Int?
        /// The program positions in the histories of the items the step pushed,
        /// leaving out the step's own: for a new item, the cruxes of the arguments
        /// it consumed; for an item moved, the item's own crux.
        public let sources: Set<Int>
        /// The input and constant tokens in those histories, and the step's own
        /// token if it reads a slot.
        public let slots: Set<PushInstruction>
        /// The stacks the step pushed onto, in order.
        public let pushed: [PushStack]
    }

    /// What reached an item, from its history.
    public struct Reach {
        /// Positions of the literals in the history (by their tags).
        public var literals: Set<Int> = []
        /// Positions of the instructions that made the history's nodes (by step).
        public var instructions: Set<Int> = []
        /// The steps that made the history's nodes.
        public var steps: Set<Int> = []
        /// The input and constant tokens in the history.
        public var slots: Set<PushInstruction> = []
        /// Literals and nodes the trace couldn't place.
        public var untraced = 0

        /// Every position, literal or instruction.
        public var positions: Set<Int> { literals.union(instructions) }
    }

    /// The top item of a stack when the run ended, and what reached it.
    public struct Top {
        public let stack: PushStack
        public let item: any Item
        public let reach: Reach
    }

    public let positions: [Position]
    public let steps: [Step]
    /// The top of every non-empty stack except `.exec`, in `PushStack` order.
    public let tops: [Top]
    /// Whether the run ended because `.exec` was empty, rather than at the step limit.
    public let finished: Bool
    /// The input and constant slots the run was loaded with.
    public let inputs: [PushInstruction: any Item]
    public let constants: [PushInstruction: any Item]

    /// Traces `individual` on `trainingCase` under `configuration` (its settings and
    /// disabled behaviors; its recorders are not used).
    public init(individual: Individual, trainingCase: TrainingCase, configuration: RunnerConfiguration) {
        var positions: [Position] = []
        let program = individual.program.map { Self.tag($0, depth: 0, parent: nil, into: &positions) }

        let interpreter = Interpreter()
        interpreter.config = configuration.settings
        interpreter.config.recordsProvenance = true
        interpreter.behaviors = behaviorTable(for: configuration)
        interpreter.load(inputs: trainingCase.inputs, constants: individual.constants, program: program)

        var ledger = Ledger()
        // Histories made while loading (the input pairs on `.binding`) belong to no
        // step: `loadStep`.
        for stack in PushStack.allCases {
            ledger.note(Array(interpreter.stacks[stack] ?? []), at: Self.loadStep)
        }
        while interpreter.counter < interpreter.config.stepLimit, let next = interpreter.stacks[.exec]?.first {
            ledger.steps.append(ledger.step(interpreter, running: next))
        }
        var tops: [Top] = []
        for stack in PushStack.allCases where stack != .exec {
            guard let item = interpreter.stacks[stack]?.first else { continue }
            tops.append(Top(stack: stack, item: item, reach: ledger.reach(of: [item])))
        }

        self.positions = positions
        self.steps = ledger.steps
        self.tops = tops
        self.finished = interpreter.stacks[.exec]?.isEmpty ?? true
        self.inputs = interpreter.inputs
        self.constants = interpreter.constants
    }

    /// The step a history made while loading is placed at: before the first.
    static let loadStep = -1
    /// How many items from the top of each stack are checked after a step for
    /// histories made without a push.
    static let scannedDepth = 4

    /// The steps so far, and the step at which each history node first appeared.
    private struct Ledger {
        var steps: [Step] = []
        var stepOfNode: [CruxSharing.Key: Int] = [:]
        /// Every item noted is held until the trace ends, so no node's storage is
        /// freed and its address reused by a later node.
        var held: [any Item] = []

        /// Places the nodes of `items` not seen before at `step`; returns the items
        /// whose own node is new.
        @discardableResult
        mutating func note(_ items: [any Item], at step: Int) -> [any Item] {
            held.append(contentsOf: items)
            return items.filter { item in
                guard let key = CruxSharing.key(item), stepOfNode[key] == nil else { return false }
                stepOfNode[key] = step
                return true
            }
        }

        /// Runs one step of `interpreter`, whose next item is `next`, and records it.
        mutating func step(_ interpreter: Interpreter, running next: any Item) -> Step {
            let index = steps.count
            interpreter.pushLog = []
            interpreter.step()
            let pushed = interpreter.pushLog ?? []
            interpreter.pushLog = nil
            note(pushed.map(\.item), at: index)
            var made = pushed.map(\.item)
            // Some instructions replace an item where it rests rather than pushing
            // one; the tops of the stacks catch most of those.
            for stack in PushStack.allCases where stack != .exec {
                made += note(Array((interpreter.stacks[stack] ?? []).prefix(SourceTrace.scannedDepth)), at: index)
            }
            // For an item this step made, what it consumed; for one it moved, itself.
            let consumed = made.flatMap { item -> [any Item] in
                guard let key = CruxSharing.key(item), stepOfNode[key] == index else { return [item] }
                return item.call
            }
            let new = Set(made.compactMap(CruxSharing.key).filter { stepOfNode[$0] == index })
            let reach = reach(of: consumed, skipping: new)
            let position = SourceTrace.origin(of: next)
            var slots = reach.slots
            if let token = next.exactly(InstructionItem.self)?.value, token.isInput || token.isConstant {
                slots.insert(token)
            }
            var sources = reach.positions
            if let position { sources.remove(position) }
            return Step(executed: next, position: position, sources: sources, slots: slots,
                        pushed: pushed.map(\.stack))
        }

        /// Everything in the histories of `items`: tagged literals, the steps (and so
        /// the instructions) that made their nodes, slot tokens, and the contents of
        /// any code block in them. Each shared node is visited once, and the nodes in
        /// `skipping` not at all.
        func reach(of items: [any Item], skipping: Set<CruxSharing.Key> = []) -> Reach {
            var reach = Reach()
            var visited = Set<CruxSharing.Key>()
            var pending = items
            while let next = pending.popLast() {
                if let key = CruxSharing.key(next) {
                    guard !skipping.contains(key), visited.insert(key).inserted else { continue }
                    place(stepOfNode[key], in: &reach)
                    pending.append(contentsOf: next.call)
                } else if let position = SourceTrace.origin(of: next) {
                    reach.literals.insert(position)
                } else if next.exactly(InstructionItem.self) == nil, next.exactly(CodeItem.self) == nil {
                    // An instruction leaf a behavior wrote is placed by its node's step.
                    reach.untraced += 1
                }
                if let token = next.exactly(InstructionItem.self)?.value, token.isInput || token.isConstant {
                    reach.slots.insert(token)
                }
                if let block = next.exactly(CodeItem.self) {
                    pending.append(contentsOf: block.value)
                }
            }
            return reach
        }

        /// Adds a node made at `step` to `reach`.
        private func place(_ step: Int?, in reach: inout Reach) {
            guard let step else { reach.untraced += 1; return }
            guard step >= 0 else { return }
            reach.steps.insert(step)
            if step < steps.count, let position = steps[step].position { reach.instructions.insert(position) }
        }
    }

    /// `item` tagged with its position, and its contents with theirs, recursively;
    /// each position appended to `positions` in pre-order.
    private static func tag(_ item: any Item, depth: Int, parent: Int?,
                            into positions: inout [Position]) -> any Item {
        let position = positions.count
        let block = item.exactly(CodeItem.self)
        positions.append(Position(item: item, depth: depth, parent: parent, isCodeBlock: block != nil))
        if let block {
            let contents = block.value.map { tag($0, depth: depth + 1, parent: position, into: &positions) }
            var tagged = CodeItem(contents)
            tagged.callStorage = .tagged(origin: position)
            return tagged
        }
        guard var holder = item as? any HoldsCall, item.call.isEmpty else { return item }
        holder.callStorage = .tagged(origin: position)
        return holder
    }

    /// The position a literal was tagged with, if any.
    static func origin(of item: any Item) -> Int? {
        (item as? any HoldsCall)?.callStorage.origin
    }
}
