//
//  Decision.swift
//  Plunge
//
//  A conditional's choice, as the decision log records it (2026-11-17, #57).
//  Selections by a computed stack depth, binding key or code point added
//  2026-11-19.
//

/// One choice a program made during a run, at one step: a **conditional**
/// (`.execIf`, `.execWhen` or `.codeDoIf`) choosing code by a Boolean, or a
/// **selection** (``Decision/selections``) choosing by an int: an item by a
/// computed stack depth (`.intYank`, `.codeShove` and every other stack
/// instruction that takes a depth or a count), a binding by a computed key
/// (`.bindingDeref` and kin), or a point of a code block by a computed index
/// (`.codeDoNth` and kin), reached with its arguments.
///
/// A crux follows data, not control: a conditional records nothing in any
/// item's history, so the Boolean that chose a branch is in no result's crux,
/// and a result made by one branch looks the same as one made with no branch
/// at all. A selection is the same: moving an item records nothing (provenance
/// law 1), so the depth that picked it is in no crux either. The decision log
/// keeps what the crux leaves out: the deciding item, with its history (the
/// condition), and what each way would do. The same conditional reached on
/// different cases gives the same blocks, the conditions, and which way each
/// case went.
///
/// The blocks are held as the items they were, not copied (code blocks share
/// their storage), and keep their own histories: a block built during the run
/// records how.
public nonisolated struct Decision: Sendable, Equatable, Codable {
    /// The step the choice was made at (the run's step counter).
    public let step: Int
    /// The instruction that chose: a conditional, or a selection.
    public let instruction: PushInstruction
    /// The item that decided, history and all: a conditional's Boolean, or a
    /// selection's depth or count.
    public let condition: AnyItem
    /// A conditional's code block run when the condition is true; `nil` for a
    /// selection.
    public let whenTrue: AnyItem?
    /// A conditional's code block run when it is false: `.execIf`'s else block.
    /// `nil` for `.execWhen` (discarded) and `.codeDoIf` (left on `.code`), which
    /// run nothing when false, and for a selection.
    public let whenFalse: AnyItem?
    /// A selection's options, the values of its deciding int that name them.
    /// By ``Naming/position`` (a depth or index): for each different thing it
    /// could do, the lowest position that does it, lowest first; positions are
    /// clamped, so one below the first option takes the first, and one past the
    /// last takes the last. By ``Naming/key``: each key bound on `.binding`
    /// within reach, once, from the top down. `nil` for a conditional.
    public let options: [Int]?
    /// How ``options`` are named; `nil` for a conditional.
    public let naming: Naming?
    /// The option a selection took, as an index into ``options``; for a key
    /// lookup whose key was unbound (it refused), `options.count`. `nil` for a
    /// conditional.
    public internal(set) var chosen: Int?

    /// How a selection's deciding int names its options.
    public enum Naming: String, Sendable, Codable {
        /// A depth or index, clamped into range: each option covers the positions
        /// from its own up to the next option's.
        case position
        /// A key: an option is taken by its own key only.
        case key
    }

    /// Whether the run took it otherwise than its condition said: a conditional
    /// flipped (`InterpreterSettings/flippedDecisions`), or a selection forced to
    /// another option (`InterpreterSettings/forcedChoices`). A counterfactual
    /// decision.
    public internal(set) var flipped = false

    /// Which way a conditional went: the condition's value, or its negation
    /// when flipped. False for a selection.
    public var tookTrue: Bool { ((condition.item as? BoolItem)?.value ?? false) != flipped }

    /// Whether it is a selection rather than a conditional.
    public var isSelection: Bool { options != nil }

    /// Which way it went, as a number: a selection's ``chosen`` option, or 1 for
    /// a conditional that took its true branch and 0 for one that didn't.
    public var outcome: Int { chosen ?? (tookTrue ? 1 : 0) }

    /// A conditional's choice.
    public init(step: Int, instruction: PushInstruction, condition: any Item, whenTrue: any Item,
                whenFalse: (any Item)?, flipped: Bool = false) {
        self.flipped = flipped
        self.step = step
        self.instruction = instruction
        self.condition = AnyItem(condition)
        self.whenTrue = AnyItem(whenTrue)
        self.whenFalse = whenFalse.map(AnyItem.init)
        self.options = nil
        self.naming = nil
        self.chosen = nil
    }

    /// A selection's choice: `options` named by `naming`, and `chosen` the one
    /// taken.
    public init(step: Int, instruction: PushInstruction, selector: any Item, options: [Int], chosen: Int,
                naming: Naming = .position, forced: Bool = false) {
        self.flipped = forced
        self.step = step
        self.instruction = instruction
        self.condition = AnyItem(selector)
        self.whenTrue = nil
        self.whenFalse = nil
        self.options = options
        self.naming = naming
        self.chosen = chosen
    }

    private enum CodingKeys: String, CodingKey {
        case step, instruction, condition, whenTrue, whenFalse, options, naming, chosen, flipped
    }

    /// Decodes a decision; one saved before `flipped` existed was not flipped,
    /// and one saved before selections were logged is a conditional.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        step = try container.decode(Int.self, forKey: .step)
        instruction = try container.decode(PushInstruction.self, forKey: .instruction)
        condition = try container.decode(AnyItem.self, forKey: .condition)
        whenTrue = try container.decodeIfPresent(AnyItem.self, forKey: .whenTrue)
        whenFalse = try container.decodeIfPresent(AnyItem.self, forKey: .whenFalse)
        options = try container.decodeIfPresent([Int].self, forKey: .options)
        naming = try container.decodeIfPresent(Naming.self, forKey: .naming) ?? (options == nil ? nil : .position)
        chosen = try container.decodeIfPresent(Int.self, forKey: .chosen)
        flipped = try container.decodeIfPresent(Bool.self, forKey: .flipped) ?? false
    }
}

nonisolated extension Decision {
    /// The conditionals the log watches. A program none of whose instructions is
    /// one of these never logs a decision.
    public static let conditionals: Set<PushInstruction> = [.execIf, .execWhen, .codeDoIf]

    /// The selections the log watches: every stack instruction that takes a
    /// depth or a count from `.int` and moves, copies or removes items by it
    /// (`.intYank`, `.codeShove`, `.vecIntDeleteAtDepth`, `.boolPopItems`, …); the
    /// binding lookups by key; and the code-point runs by index. One is logged
    /// only when it could have done more than one thing.
    public static let selections: Set<PushInstruction> = depthSelections.union(keyLookups).union(codePoints)

    /// The stack instructions that pick by a depth or count they take.
    static let depthSelections: Set<PushInstruction> = Set(Interpreter.language.compactMap { entry in
        guard case .structural = entry.value.body, case .takes(let stack)? = entry.value.requirements.first,
              stack == .int else { return nil }
        return entry.key
    })

    /// The binding lookups: each reads its key from `.int` and leaves it.
    public static let keyLookups: Set<PushInstruction> = [.bindingDeref, .bindingDerefFrom, .bindingDerefToCode,
                                                          .bindingDerefToCodeFrom, .bindingDo]

    /// The code-point runs: each reads a code block and an index and leaves them.
    public static let codePoints: Set<PushInstruction> = [.codeDoNth, .codeDoNthRoot, .codeEmitNth,
                                                          .codeEmitNthRoot]

    /// A key lookup or code-point run about to choose, read from the stacks
    /// before it runs: its deciding int and where it is on `.int`, its options,
    /// and the one it will take; `nil` when it will refuse for want of
    /// arguments, or has only one thing it could do.
    static func pendingSelection(_ instruction: PushInstruction, stacks: StackSet)
        -> (selector: IntItem, at: Int, options: [Int], naming: Naming, chosen: Int)? {
        if keyLookups.contains(instruction) {
            // The `From` forms take a starting depth first; the key is below it.
            let from = instruction == .bindingDerefFrom || instruction == .bindingDerefToCodeFrom
            guard let key = stacks.item(at: from ? 1 : 0, on: .int)?.exactly(IntItem.self) else { return nil }
            let start = from ? max(0, stacks.item(at: 0, on: .int)?.exactly(IntItem.self)?.value ?? 0) : 0
            let pairs = stacks[.binding] ?? []
            var keys: [Int] = []
            var seen = Set<Int>()
            for depth in start..<max(start, pairs.count) {
                if let bound = (pairs[depth] as? BindingItem)?.key, seen.insert(bound).inserted { keys.append(bound) }
            }
            guard !keys.isEmpty else { return nil }
            return (key, from ? 1 : 0, keys, .key, keys.firstIndex(of: key.value) ?? keys.count)
        }
        guard codePoints.contains(instruction), let block = stacks.item(at: 0, on: .code)?.exactly(CodeItem.self),
              let index = stacks.item(at: 0, on: .int)?.exactly(IntItem.self) else { return nil }
        let root = instruction == .codeDoNthRoot || instruction == .codeEmitNthRoot
        let count = root ? block.value.count : block.pointCount
        guard count > 1 else { return nil }
        return (index, 0, Array(0..<count), .position, Position.item(index.value, count: count))
    }

    /// The decision `instruction` is about to make, read from the stacks before
    /// it runs: the top Boolean and the top one or two code blocks; `nil` when
    /// they aren't there (it will refuse, deciding nothing).
    static func pending(_ instruction: PushInstruction, step: Int, stacks: StackSet) -> Decision? {
        guard let condition = stacks.item(at: 0, on: .bool), let top = stacks.item(at: 0, on: .code) else {
            return nil
        }
        guard instruction == .execIf else {
            return Decision(step: step, instruction: instruction, condition: condition, whenTrue: top,
                            whenFalse: nil)
        }
        // `( then ) ( else ) .execIf`: else is on top, then below it.
        guard let below = stacks.item(at: 1, on: .code) else { return nil }
        return Decision(step: step, instruction: instruction, condition: condition, whenTrue: below,
                        whenFalse: top)
    }
}
