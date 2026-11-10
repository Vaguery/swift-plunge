//
//  Typed Operations.swift
//  Plunge
//
//  Operations declared by their argument and result types.
//
//      Behavior.operation(.intGT, reads: IntItem.self, IntItem.self, gives: BoolItem.self) { y, x in y > x }
//
//  The constructor writes the casts, the `Router` and the recorded `call` once,
//  so a definition says only what is particular to it: its types, in the order a
//  program writes them, and the function of their values.
//

nonisolated extension Behavior {

    // MARK: - Values in, a value out

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
        typed(label, stacks: stacks(repeat each takes), reading: false, gives: R.pushStack, tags: tags) { args, call, recording in
            let value = body(repeat each values(args, call.positions, repeat each takes))
            return [Router(R.pushStack, R(value, call: recording(call.recorded(producing: R.pushStack))))]
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
        typed(label, stacks: stacks(repeat each takes), reading: false, gives: R.pushStack,
              tags: tags.union([.fallible])) { args, call, recording throws(Refusal) in
            let value = try body(repeat each values(args, call.positions, repeat each takes))
            return [Router(R.pushStack, R(value, call: recording(call.recorded(producing: R.pushStack))))]
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
        typed(label, stacks: stacks(repeat each reads), reading: true, gives: R.pushStack, tags: tags) { args, call, recording in
            let value = body(repeat each values(args, call.positions, repeat each reads))
            return [Router(R.pushStack, R(value, call: recording(call.recorded(producing: R.pushStack))))]
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
        typed(label, stacks: stacks(repeat each reads), reading: true, gives: R.pushStack,
              tags: tags.union([.fallible])) { args, call, recording throws(Refusal) in
            let value = try body(repeat each values(args, call.positions, repeat each reads))
            return [Router(R.pushStack, R(value, call: recording(call.recorded(producing: R.pushStack))))]
        }
    }


    // MARK: - Items in, a container out

    /// Builds a **container from its arguments' elements**. `body` receives the
    /// arguments as typed items, so it can read their element origins, and returns
    /// the new value with the origin of each element (`Built`).
    static func assembling<each A: ValueItem, R: MemberItem>(
        _ label: PushInstruction,
        takes: repeat (each A).Type,
        gives: R.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat each A) -> Built<R.Value>
    ) -> Behavior {
        typed(label, stacks: stacks(repeat each takes), reading: false, gives: R.pushStack, tags: tags) { args, call, recording in
            let built = body(repeat each items(args, call.positions, repeat each takes))
            return [Router(R.pushStack, R(built.value,
                                          call: recording(call.recorded(producing: R.pushStack)),
                                          members: recording.pieces(built.members())))]
        }
    }

    /// Builds a container and **can refuse**. Tagged `.fallible`.
    static func assembling<each A: ValueItem, R: MemberItem>(
        _ label: PushInstruction,
        takes: repeat (each A).Type,
        gives: R.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat each A) throws(Refusal) -> Built<R.Value>
    ) -> Behavior {
        typed(label, stacks: stacks(repeat each takes), reading: false, gives: R.pushStack,
              tags: tags.union([.fallible])) { args, call, recording throws(Refusal) in
            let built = try body(repeat each items(args, call.positions, repeat each takes))
            return [Router(R.pushStack, R(built.value,
                                          call: recording(call.recorded(producing: R.pushStack)),
                                          members: recording.pieces(built.members())))]
        }
    }


    /// Builds a container from arguments it **reads and leaves**, and can refuse.
    /// Tagged `.fallible`. The crux clears the read arguments, as a query's does.
    static func assembling<each A: ValueItem, R: MemberItem>(
        _ label: PushInstruction,
        reads: repeat (each A).Type,
        gives: R.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat each A) throws(Refusal) -> Built<R.Value>
    ) -> Behavior {
        typed(label, stacks: stacks(repeat each reads), reading: true, gives: R.pushStack,
              tags: tags.union([.fallible])) { args, call, recording throws(Refusal) in
            let built = try body(repeat each items(args, call.positions, repeat each reads))
            return [Router(R.pushStack, R(built.value,
                                          call: recording(call.recorded(producing: R.pushStack)),
                                          members: recording.pieces(built.members())))]
        }
    }


    // MARK: - Items in, a value out

    /// Builds a value **from the argument items themselves**, not just their
    /// values: for a result that contains an argument, history and all (a block
    /// quoting or pairing its arguments). A values body would rebuild such an
    /// argument without its `call`, and change its provenance.
    static func composing<each A: ValueItem, R: ValueItem>(
        _ label: PushInstruction,
        takes: repeat (each A).Type,
        gives: R.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat each A) -> R.Value
    ) -> Behavior {
        typed(label, stacks: stacks(repeat each takes), reading: false, gives: R.pushStack, tags: tags) { args, call, recording in
            let value = body(repeat each items(args, call.positions, repeat each takes))
            return [Router(R.pushStack, R(value, call: recording(call.recorded(producing: R.pushStack))))]
        }
    }


    // MARK: - Items in, an element out

    /// **Takes one element out of a container.** `body` names it (`Extraction`) or
    /// refuses (an empty container has no element). The result is the element that
    /// went in, if it kept a history (`Containment`); otherwise it is built with
    /// this instruction's own `call`. Tagged `.fallible`.
    static func extracting<each A: ValueItem, C: TracingItem>(
        _ label: PushInstruction,
        takes: repeat (each A).Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat each A) throws(Refusal) -> Extraction<C>
    ) -> Behavior {
        let gives = C.ElementItem.pushStack
        return typed(label, stacks: stacks(repeat each takes), reading: false, gives: gives,
                     tags: tags.union([.fallible])) { args, call, recording throws(Refusal) in
            let extraction = try body(repeat each items(args, call.positions, repeat each takes))
            let container = extraction.container, index = extraction.index
            let element = container.tracedElement(at: index, recording)
                ?? C.ElementItem(container.element(at: index), call: recording(call.recorded(producing: gives)))
            return [Router(gives, element)]
        }
    }


    /// **Reads one element out of a container**, leaving the container and the
    /// index where they were: the non-destructive sibling of `extracting(takes:)`
    /// (the `Peek` forms). A traced element is still the item that went
    /// in; otherwise its crux names this instruction and then removes what it
    /// read (`Behavior.reading`), so the fragment leaves only the element.
    static func extracting<each A: ValueItem, C: TracingItem>(
        _ label: PushInstruction,
        reads: repeat (each A).Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat each A) throws(Refusal) -> Extraction<C>
    ) -> Behavior {
        let gives = C.ElementItem.pushStack
        return typed(label, stacks: stacks(repeat each reads), reading: true, gives: gives,
                     tags: tags.union([.fallible])) { args, call, recording throws(Refusal) in
            let extraction = try body(repeat each items(args, call.positions, repeat each reads))
            let container = extraction.container, index = extraction.index
            let element = container.tracedElement(at: index, recording)
                ?? C.ElementItem(container.element(at: index), call: recording(call.recorded(producing: gives)))
            return [Router(gives, element)]
        }
    }


    // MARK: - Items in, an element and its index out

    /// **Finds one element in a container and gives it with its index** (the
    /// lookups in a collection): a query, reading
    /// every argument. The index goes down first and the element on top of it,
    /// which matters only when both land on `.int`.
    ///
    /// Each result's crux is the written call, then the removal of its sibling
    /// (the element is on top; the index lifted past the element when they share
    /// `.int`), then the clean-up of what was read. An element that kept an
    /// origin in its container is that origin instead (`tracedElement`), as in
    /// `extracting`. Tagged `.fallible`; a miss is a refusal.
    static func finding<each A: ValueItem, E: ValueItem>(
        _ label: PushInstruction,
        reads: repeat (each A).Type,
        gives: E.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat each A) throws(Refusal) -> Found<E.Value>
    ) -> Behavior {
        let stack = E.pushStack
        let dropElement = [InstructionItem(stack.popInstruction)]
        let dropIndex = stack == .int
            ? [InstructionItem(.intSwap), InstructionItem(.intPop)]
            : [InstructionItem(.intPop)]
        return typed(label, stacks: stacks(repeat each reads), reading: true, gives: stack,
                     produces: .results([stack, .int]),
                     tags: tags.union([.fallible])) { args, call, recording throws(Refusal) in
            let found = try body(repeat each items(args, call.positions, repeat each reads))
            let index = IntItem(found.index, call: recording(call.recorded(producing: .int, after: dropElement)))
            let element = found.container?.tracedElement(at: found.index, recording)
                ?? E(found.value, call: recording(call.recorded(producing: stack, after: dropIndex)))
            return [Router(.int, index), Router(stack, element)]
        }
    }


    // MARK: - Items in, two containers out

    /// **Splits into two results on one stack**, the first produced ending deepest
    /// (`cut`: prefix under suffix). Each records the selecting crux (provenance
    /// law 5): the instruction, then the clean-up that surfaces that one result.
    /// A pair, not a list, so the declared output is exactly two.
    static func splitting<each A: ValueItem, R: MemberItem>(
        _ label: PushInstruction,
        takes: repeat (each A).Type,
        gives: R.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat each A) -> (Built<R.Value>, Built<R.Value>)
    ) -> Behavior {
        typed(label, stacks: stacks(repeat each takes), reading: false, gives: R.pushStack, count: 2,
              tags: tags) { args, call, recording in
            let pair = body(repeat each items(args, call.positions, repeat each takes))
            let parts = [pair.0, pair.1]
            return parts.enumerated().map { produced, part in
                Router(R.pushStack, R(part.value,
                                      call: recording(Behavior.selecting(produced, of: parts.count,
                                                                         on: R.pushStack, from: call.written)),
                                      members: recording.pieces(part.members())))
            }
        }
    }


    /// Two results on one stack, for a type **without element origins** (a
    /// block's pieces: `codeCutAtGap`). As `splitting` above, but the body returns
    /// the pieces' values.
    static func splitting<each A: ValueItem, R: ValueItem>(
        _ label: PushInstruction,
        takes: repeat (each A).Type,
        gives: R.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (repeat each A) -> (R.Value, R.Value)
    ) -> Behavior {
        typed(label, stacks: stacks(repeat each takes), reading: false, gives: R.pushStack, count: 2,
              tags: tags) { args, call, recording in
            let pair = body(repeat each items(args, call.positions, repeat each takes))
            let parts = [pair.0, pair.1]
            return parts.enumerated().map { produced, value in
                Router(R.pushStack, R(value, call: recording(Behavior.selecting(produced, of: parts.count,
                                                                                on: R.pushStack, from: call.written))))
            }
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

    /// The arguments themselves in written order, cast to their declared types,
    /// for the forms that need more than values (element origins, history).
    private static func items<each A: ValueItem>(
        _ args: [any Item], _ positions: [Int], _ types: repeat (each A).Type
    ) -> (repeat each A) {
        var i = 0
        func next<T: ValueItem>(_ type: T.Type) -> T {
            defer { i += 1 }
            return args[positions[i]] as! T
        }
        return (repeat next(each types))
    }

    /// Builds the Behavior: requirements from the written order, results from
    /// `produce`, a `Refusal` routed to `.error` with the `call` a result would
    /// have recorded.
    private static func typed(
        _ label: PushInstruction,
        stacks: [PushStack],
        reading: Bool,
        gives: PushStack,
        count: Int = 1,
        produces declared: Produces? = nil,
        tags: Set<InstructionTag>,
        produce: @escaping @Sendable ([any Item], WrittenCall, ProvenanceRecording) throws(Refusal) -> [Router]
    ) -> Behavior {
        let order = WrittenOrder(stacks)
        let requirements = order.groups.flatMap { group in
            Array(repeating: reading ? Requirement.reads(group.stack) : Requirement.takes(group.stack),
                  count: group.count)
        }
        let positions = order.positions
        let readCounts = reading
            ? order.groups.map { (key: $0.stack, value: $0.count) }.sorted { $0.key.rawValue < $1.key.rawValue }
            : nil
        let instruction = InstructionItem(label)
        let produces = declared ?? Produces.results(Array(repeating: gives, count: count))

        let fxn: @Sendable ([any Item], ProvenanceRecording) -> [Router] = { args, recording in
            let call = WrittenCall(arguments: args, positions: positions, instruction: instruction, readCounts: readCounts)
            do throws(Refusal) {
                return try produce(args, call, recording)
            } catch {
                return [Behavior.refusal(error.message, kind: error.kind,
                                         call: recording(call.recorded(producing: .error)))]
            }
        }
        return Behavior(label, requires: requirements, tags: tags,
                        behaviorClass: .operation, body: .values(fxn), produces: produces)
    }
}
