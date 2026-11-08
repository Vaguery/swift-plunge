//
//  WrittenCall.swift
//  PushInterpreter
//
//  The `call` a typed operation records (Roadmap #44).
//

/// **The `call` a typed operation records**, for one run of it: the arguments as
/// written, then the instruction (provenance law 3), plus, for a query, the
/// clean-up of what it read (`Behavior.reading`). Cheap to make; the arrays are
/// built only when asked for, which `recording(…)` does only when recording.
nonisolated struct WrittenCall {
    let arguments: [any Item]
    /// For each argument in written order, its index in `arguments`.
    let positions: [Int]
    let instruction: InstructionItem
    /// The stacks a query read and how many from each, sorted; nil for an
    /// operation that consumes its arguments.
    let readCounts: [(key: PushStack, value: Int)]?

    /// The arguments in written order, then the instruction.
    var written: [any Item] { positions.map { arguments[$0] } + [instruction] }

    /// The whole `call` for a result that lands on `stack`.
    func recorded(producing stack: PushStack) -> [any Item] {
        guard let readCounts else { return written }
        return Behavior.reading(sorted: readCounts, producing: stack, from: written)
    }
}
