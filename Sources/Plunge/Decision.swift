//
//  Decision.swift
//  Plunge
//
//  A conditional's choice, as the decision log records it (2026-11-17, #57).
//

/// One choice a conditional made during a run: `.execIf`, `.execWhen` or
/// `.codeDoIf`, reached with its arguments, at one step.
///
/// A crux follows data, not control: a conditional records nothing in any
/// item's history, so the Boolean that chose a branch is in no result's crux,
/// and a result made by one branch looks the same as one made with no branch
/// at all. The decision log keeps what the crux leaves out: the deciding
/// Boolean, with its history (the condition), and the code each way would run.
/// The same conditional reached on different cases gives the same blocks, the
/// conditions, and which way each case went.
///
/// The blocks are held as the items they were, not copied (code blocks share
/// their storage), and keep their own histories: a block built during the run
/// records how.
public nonisolated struct Decision: Sendable, Equatable, Codable {
    /// The step the conditional ran at (the run's step counter).
    public let step: Int
    /// The conditional: `.execIf`, `.execWhen` or `.codeDoIf`.
    public let instruction: PushInstruction
    /// The Boolean that decided, history and all.
    public let condition: AnyItem
    /// The code block run when the condition is true.
    public let whenTrue: AnyItem
    /// The code block run when it is false: `.execIf`'s else block. `nil` for
    /// `.execWhen` (discarded) and `.codeDoIf` (left on `.code`), which run
    /// nothing when false.
    public let whenFalse: AnyItem?

    /// Which way it went: the condition's value.
    public var tookTrue: Bool { (condition.item as? BoolItem)?.value ?? false }

    public init(step: Int, instruction: PushInstruction, condition: any Item, whenTrue: any Item,
                whenFalse: (any Item)?) {
        self.step = step
        self.instruction = instruction
        self.condition = AnyItem(condition)
        self.whenTrue = AnyItem(whenTrue)
        self.whenFalse = whenFalse.map(AnyItem.init)
    }
}

nonisolated extension Decision {
    /// The conditionals the log watches.
    static let conditionals: Set<PushInstruction> = [.execIf, .execWhen, .codeDoIf]

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
