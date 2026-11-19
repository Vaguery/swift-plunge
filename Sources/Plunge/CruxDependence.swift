//
//  CruxDependence.swift
//  Plunge
//
//  What an item's history reads from outside itself: inputs, constants or the
//  run's transient state. Kept on every history node, as its weight and depth
//  are, so that tools can tell constant work from input-dependent work without a
//  walk. Added 2026-11-15, for distilled cruxes.
//

/// **What an item's history depends on, beyond the literals in it.**
///
/// Every history node keeps one, computed from its arguments when its `call` is
/// assigned, the way `callWeight` and `callDepth` are. A literal depends on
/// nothing.
///
/// - **`input`:** the history reads an input (`.input0`), directly or through
///   the input pairs bound on `.binding`.
/// - **`constant`:** it reads a constant slot (`.constant3`).
/// - **`context`:** it holds an observed stand-in (provenance law 4b: a stack
///   depth, a step count, an error count, a refusal), or it runs a code block or
///   function whose contents read the run's state.
///
/// **It is conservative.** A flag that is set may be unnecessary, but one that is
/// clear is always right: a history with no `input` flag gives the same value on
/// every training case, and one with neither `input` nor `context` gives the same
/// value whenever its constants are the same. Code blocks and functions that a
/// history runs inside one step (map, filter, reduce, function application, a
/// folded loop) count everything their contents read.
///
/// **It is never visible to a program.** No instruction reads it, so a run with
/// provenance recording off is unchanged. It serves search and analysis: the
/// distilled crux, input-blindness checks, and sharing work across cases.
public nonisolated struct CruxDependence: OptionSet, Sendable, Hashable, Codable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// The history reads an input.
    public static let input = CruxDependence(rawValue: 1 << 0)
    /// The history reads a constant slot.
    public static let constant = CruxDependence(rawValue: 1 << 1)
    /// The history reads the run's transient state.
    public static let context = CruxDependence(rawValue: 1 << 2)

    /// Everything: what an elided stand-in decoded from an archive that predates
    /// these flags is taken to read.
    public static let all: CruxDependence = [.input, .constant, .context]

    /// **Not a dependence.** Set only on an instruction token that runs code
    /// inside one step, so that `of` knows to look inside the code blocks and
    /// functions beside it. Never stored on a node.
    static let runsCode = CruxDependence(rawValue: 1 << 7)

    /// Whether a history with this dependence gives the same value whenever its
    /// constants are the same: it reads no input and no transient state.
    public var isConstantWork: Bool { isDisjoint(with: [.input, .context]) }
}

nonisolated extension CruxDependence {
    /// What a `call` depends on: everything its elements depend on, plus, when an
    /// element is an instruction that runs code inside one step, everything the
    /// code blocks and functions beside it read.
    static func of(_ call: [any Item]) -> CruxDependence {
        var found: CruxDependence = []
        for element in call { found.formUnion(element.cruxDependence) }
        if found.contains(.runsCode) {
            found.remove(.runsCode)
            for element in call { found.formUnion(contents(of: element)) }
        }
        return found
    }

    /// What the contents of a code block or function read, if `item` is one:
    /// every token's own dependence and every content's history, through nested
    /// blocks. Iterative, since blocks can nest deeply.
    static func contents(of item: any Item) -> CruxDependence {
        var found: CruxDependence = []
        var pending: [any Item] = []
        func open(_ item: any Item) {
            if let block = item.exactly(CodeItem.self) {
                pending.append(contentsOf: block.value)
            } else if let function = item.exactly(FunctionItem.self) {
                pending.append(contentsOf: function.value)
            }
        }
        open(item)
        while let next = pending.popLast() {
            found.formUnion(next.cruxDependence)
            open(next)
        }
        found.remove(.runsCode)
        return found
    }

    /// What an instruction token depends on as an element of a history: an input
    /// token reads an input, a constant token a constant slot, and any other
    /// instruction that reads the run's state reads context. An instruction that
    /// runs code inside one step carries `runsCode`.
    static func token(_ instruction: PushInstruction) -> CruxDependence {
        tokens[instruction.representative] ?? []
    }

    /// `token`, built once from the language.
    private static let tokens: [PushInstruction: CruxDependence] = {
        var table: [PushInstruction: CruxDependence] = [:]
        for (instruction, behavior) in Interpreter.language {
            var dependence: CruxDependence = []
            if instruction.isInput {
                dependence.insert(.input)
            } else if instruction.isConstant {
                dependence.insert(.constant)
            } else if behavior.behaviorClass == .contextRead {
                dependence.insert(.context)
            }
            if case .applying = behavior.body { dependence.insert(.runsCode) }
            if behavior.behaviorClass == .control || Interpreter.reEntrantInstructions.contains(instruction) {
                dependence.insert(.runsCode)
            }
            if !dependence.isEmpty { table[instruction] = dependence }
        }
        return table
    }()
}
