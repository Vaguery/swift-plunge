//
//  Typed Operations.swift
//  PushInterpreter
//
//  Operations declared by their argument and result types (Roadmap #44).
//
//      Behavior.operation(.intGT, reads: IntItem.self, IntItem.self, gives: BoolItem.self) { y, x in y > x }
//
//  The constructor writes the casts, the `Router` and the recorded `call` once,
//  so a definition says only what is particular to it: its types, in the order a
//  program writes them, and the function of their values.
//

/// **Where each argument of a typed operation sits**, worked out once from the
/// argument stacks listed in written order.
///
/// The rule reproduces how the hand-written operations always recorded `call`
/// (provenance law 3): arguments grouped by stack in order of first appearance,
/// and within a stack deepest first — `y x .intAdd`, `"abc" 2 .stringNth`,
/// `[1, 2] 9 0 .vecIntSet`. It also gives the requirements: each stack's items
/// claimed top first, the stacks in the same order.
nonisolated struct WrittenOrder: Sendable {
    /// Each stack and how many arguments it supplies, in order of first appearance.
    let groups: [(stack: PushStack, count: Int)]
    /// For each argument in written order, its index in the gathered arguments
    /// (which arrive in requirement order: each stack's top first).
    let positions: [Int]

    init(_ stacks: [PushStack]) {
        var groups: [(stack: PushStack, count: Int)] = []
        for stack in stacks {
            if let slot = groups.firstIndex(where: { $0.stack == stack }) {
                groups[slot].count += 1
            } else {
                groups.append((stack, 1))
            }
        }
        var offset: [PushStack: Int] = [:]
        var running = 0
        for group in groups {
            offset[group.stack] = running
            running += group.count
        }
        var seen: [PushStack: Int] = [:]
        var positions: [Int] = []
        for stack in stacks {
            let k = seen[stack, default: 0]
            seen[stack] = k + 1
            let count = groups.first { $0.stack == stack }!.count
            // Written k-th, so it is (count − 1 − k) from the top.
            positions.append(offset[stack]! + count - 1 - k)
        }
        self.groups = groups
        self.positions = positions
    }

}


nonisolated extension Behavior {

    /// An operation that **consumes** its arguments. `takes` lists the argument
    /// types in written order; `body` receives their values in that order and
    /// returns the result's value.
    static func operation<each A: ValueItem, R: ValueItem>(
        _ label: PushInstruction,
        takes: repeat (each A).Type,
        gives: R.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat (each A).Value) -> R.Value
    ) -> Behavior {
        typed(label, stacks: stacks(repeat each takes), reading: false, gives: gives, tags: tags) { args, positions in
            body(repeat each values(args, positions, repeat each takes))
        }
    }

    /// An operation that consumes its arguments and **can refuse**: a thrown
    /// `Refusal` becomes an error. Tagged `.fallible`.
    static func operation<each A: ValueItem, R: ValueItem>(
        _ label: PushInstruction,
        takes: repeat (each A).Type,
        gives: R.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat (each A).Value) throws(Refusal) -> R.Value
    ) -> Behavior {
        typed(label, stacks: stacks(repeat each takes), reading: false, gives: gives,
              tags: tags.union([.fallible])) { args, positions throws(Refusal) in
            try body(repeat each values(args, positions, repeat each takes))
        }
    }

    /// A **non-destructive query**: reads its arguments and leaves them, and its
    /// result's crux cleans them up (`Behavior.reading`).
    static func operation<each A: ValueItem, R: ValueItem>(
        _ label: PushInstruction,
        reads: repeat (each A).Type,
        gives: R.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat (each A).Value) -> R.Value
    ) -> Behavior {
        typed(label, stacks: stacks(repeat each reads), reading: true, gives: gives, tags: tags) { args, positions in
            body(repeat each values(args, positions, repeat each reads))
        }
    }

    /// A query that **can refuse**. Tagged `.fallible`.
    static func operation<each A: ValueItem, R: ValueItem>(
        _ label: PushInstruction,
        reads: repeat (each A).Type,
        gives: R.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat (each A).Value) throws(Refusal) -> R.Value
    ) -> Behavior {
        typed(label, stacks: stacks(repeat each reads), reading: true, gives: gives,
              tags: tags.union([.fallible])) { args, positions throws(Refusal) in
            try body(repeat each values(args, positions, repeat each reads))
        }
    }


    // MARK: - The shared core

    /// The home stack of each argument type, in written order.
    private static func stacks<each A: ValueItem>(_ types: repeat (each A).Type) -> [PushStack] {
        var result: [PushStack] = []
        for type in repeat each types { result.append(type.pushStack) }
        return result
    }

    /// The arguments' values in written order, cast to their declared types.
    /// Safe to force: the requirements put exactly these types at these positions,
    /// and every stack is homogeneous.
    private static func values<each A: ValueItem>(
        _ args: [any Item], _ positions: [Int], _ types: repeat (each A).Type
    ) -> (repeat (each A).Value) {
        var i = 0
        func next<T: ValueItem>(_ type: T.Type) -> T.Value {
            defer { i += 1 }
            return (args[positions[i]] as! T).value
        }
        return (repeat next(each types))
    }

    /// Builds the Behavior: requirements and `call` from the written order, the
    /// result routed to `R`'s stack, a `Refusal` routed to `.error`.
    private static func typed<R: ValueItem>(
        _ label: PushInstruction,
        stacks: [PushStack],
        reading: Bool,
        gives: R.Type,
        tags: Set<InstructionTag>,
        compute: @escaping @Sendable ([any Item], [Int]) throws(Refusal) -> R.Value
    ) -> Behavior {
        let order = WrittenOrder(stacks)
        let requirements = order.groups.flatMap { group in
            Array(repeating: reading ? Requirement.reads(group.stack) : Requirement.takes(group.stack),
                  count: group.count)
        }
        let positions = order.positions
        let readCounts = order.groups
            .map { (key: $0.stack, value: $0.count) }
            .sorted { $0.key.rawValue < $1.key.rawValue }
        let instruction = InstructionItem(label)

        let fxn: @Sendable ([any Item], ProvenanceRecording) -> [Router] = { args, recording in
            // The recorded `call`: the arguments as written and the instruction,
            // plus, for a query, the clean-up of what it read. Built only when
            // recording (`recording` takes it as an autoclosure).
            func call(producing stack: PushStack) -> [any Item] {
                let written = positions.map { args[$0] } + [instruction]
                return reading ? Behavior.reading(sorted: readCounts, producing: stack, from: written) : written
            }
            do throws(Refusal) {
                let value = try compute(args, positions)
                return [Router(R.pushStack, R(value, call: recording(call(producing: R.pushStack))))]
            } catch {
                return [Behavior.refusal(error.message, kind: error.kind, call: recording(call(producing: .error)))]
            }
        }
        return Behavior(label, requires: requirements, tags: tags,
                        behaviorClass: .operation, body: .values(fxn), gives: R.pushStack)
    }
}
