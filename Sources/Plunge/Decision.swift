//
//  Decision.swift
//  Plunge
//
//  A conditional's choice, as the decision log records it (2026-11-17, #57).
//  Selections by a computed stack depth added 2026-11-19.
//

/// One choice a program made during a run, at one step: a **conditional**
/// (`.execIf`, `.execWhen` or `.codeDoIf`) choosing code by a Boolean, or a
/// **selection** choosing an item by a computed stack depth (`.intYank`,
/// `.codeShove` and every other stack instruction that takes a depth or a
/// count, ``Decision/selections``), reached with its arguments.
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
    /// A selection's options: for each different thing it could do to its stack,
    /// the lowest depth that does it, lowest first. Depths are clamped into the
    /// stack, so a depth below the first option does what the first does, and
    /// one past the last does what the last does. `nil` for a conditional.
    public let options: [Int]?
    /// The option a selection took, as an index into ``options``; `nil` for a
    /// conditional.
    public internal(set) var chosen: Int?

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
        self.chosen = nil
    }

    /// A selection's choice: `options` the lowest depth for each different
    /// effect, and `chosen` the one taken.
    public init(step: Int, instruction: PushInstruction, selector: any Item, options: [Int], chosen: Int,
                forced: Bool = false) {
        self.flipped = forced
        self.step = step
        self.instruction = instruction
        self.condition = AnyItem(selector)
        self.whenTrue = nil
        self.whenFalse = nil
        self.options = options
        self.chosen = chosen
    }

    private enum CodingKeys: String, CodingKey {
        case step, instruction, condition, whenTrue, whenFalse, options, chosen, flipped
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
    /// (`.intYank`, `.codeShove`, `.vecIntDeleteAtDepth`, `.boolPopItems`, …). One
    /// is logged only when the depth could have done more than one thing.
    public static let selections: Set<PushInstruction> = Set(Interpreter.language.compactMap { entry in
        guard case .structural = entry.value.body, case .takes(let stack)? = entry.value.requirements.first,
              stack == .int else { return nil }
        return entry.key
    })

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
