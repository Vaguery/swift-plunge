//
//  Behavior Factories.swift
//  Plunge
//
//  One constructor per BehaviorClass. The plain `Behavior(…)`
//  initializers make operations; these make everything else, so a Behavior's
//  class follows from how it was built.
//

nonisolated extension Behavior {

    // MARK: - Control

    /// Control that writes the continuation by returning `Router`s onto `.exec`
    /// (the loops, `.execIf`, the code `Emit`/`Do`/`Iterate` instructions).
    static func control(
        _ label: PushInstruction,
        takes: [PushStack],
        alsoNeeds: [PushStack: Int] = [:],
        tags: Set<InstructionTag> = [],
        fxn: @escaping @Sendable ([any Item], ProvenanceRecording) -> [Router]
    ) -> Behavior {
        Behavior(label, requires: requirements(takes: takes, alsoNeeds: alsoNeeds),
                 tags: tags, behaviorClass: .control, body: .values(fxn), produces: .continuation)
    }

    /// Control over arguments it reads and leaves (`.codeEmitNth`, …).
    static func control(
        _ label: PushInstruction,
        reads: [PushStack],
        tags: Set<InstructionTag> = [],
        fxn: @escaping @Sendable ([any Item], ProvenanceRecording) -> [Router]
    ) -> Behavior {
        Behavior(label, requires: reads.map { Requirement.reads($0) },
                 tags: tags, behaviorClass: .control, body: .values(fxn), produces: .continuation)
    }

    /// Control with general requirements.
    static func control(
        _ label: PushInstruction,
        requires: [Requirement],
        tags: Set<InstructionTag> = [],
        fxn: @escaping @Sendable ([any Item], ProvenanceRecording) -> [Router]
    ) -> Behavior {
        Behavior(label, requires: requires, tags: tags, behaviorClass: .control, body: .values(fxn), produces: .continuation)
    }

    /// Control that needs more than a `Router` can say: placing a code block's contents
    /// (`.codeDo`) or burying a token under a payload (`.iteratorPlay`).
    static func control(
        _ label: PushInstruction,
        takes: [PushStack],
        tags: Set<InstructionTag> = [],
        effects: @escaping @Sendable ([any Item], ProvenanceRecording) -> [ControlEffect]
    ) -> Behavior {
        Behavior(label, requires: takes.map { Requirement.takes($0) },
                 tags: tags, behaviorClass: .control, body: .control(effects), produces: .continuation)
    }


    // MARK: - Structural

    /// A structural rule on `stack`: consume `takes` (an index or a count, if
    /// any), require `needs` items of `stack` without consuming them, and return
    /// what to do to its positions. `step` sees `stack` as it stands once the
    /// arguments are gone.
    static func structural(
        _ label: PushInstruction,
        on stack: PushStack,
        takes: [PushStack] = [],
        needs: Int = 0,
        tags: Set<InstructionTag> = [],
        step: @escaping @Sendable ([any Item], StackView) -> StructuralStep
    ) -> Behavior {
        Behavior(label, requires: requirements(takes: takes, alsoNeeds: needs > 0 ? [stack: needs] : [:]),
                 tags: tags, behaviorClass: .structural, body: .structural(stack, step),
                 produces: .positions(stack))
    }

    /// Performs a `PositionEffect` on `stack`, through the interpreter's
    /// weight-accounted mutators. A copy goes through the validated `push`, so it
    /// is refused, not forced, at `maxStackDepth`; moves and deletions change no
    /// size, or shrink it.
    static func apply(_ effect: PositionEffect, to stack: PushStack, in interpreter: Interpreter) {
        switch effect {
        case .delete(let count):
            interpreter.takeFirst(count, from: stack)

        case .copy(let from, let to):
            guard let item = interpreter.stacks.item(at: from, on: stack) else { return }
            let before = interpreter.stacks[stack]?.count ?? 0
            interpreter.push(item, to: stack)
            // Refused (and reported on `.error`): nothing landed to move.
            guard to > 0, interpreter.stacks[stack]?.count == before + 1,
                  let copy = interpreter.takeFirst(from: stack) else { return }
            interpreter.insert(copy, at: to, on: stack)

        case .move(let from, let to):
            guard from != to, let item = interpreter.take(at: from, from: stack) else { return }
            interpreter.insert(item, at: to, on: stack)

        case .remove(let depth):
            interpreter.take(at: depth, from: stack)
        }
    }


    // MARK: - Applying a function

    /// An operation that runs a function in a sub-interpreter (map, filter,
    /// reduce): it takes data, and reads the environment through a
    /// `ReadContext` that can also carry the work it did.
    static func applying(
        _ label: PushInstruction,
        takes: [PushStack],
        tags: Set<InstructionTag> = [],
        produces: Produces,
        body: @escaping @Sendable ([any Item], ReadContext) -> [Router]
    ) -> Behavior {
        Behavior(label, requires: takes.map { Requirement.takes($0) },
                 tags: tags, behaviorClass: .operation, body: .applying(body), produces: produces)
    }


    // MARK: - Context reads

    /// A source: consume `takes` (at most a count), read the arguments in `reads`
    /// and leave them, read the interpreter through a read-only `ReadContext`, and
    /// return results. The arguments arrive taken first, then read; on one stack
    /// each claims the topmost item left. `observes` names the stacks `read` looks
    /// at beyond its arguments (see `Behavior.observes`).
    static func contextRead(
        _ label: PushInstruction,
        takes: [PushStack] = [],
        reads: [PushStack] = [],
        observes: [PushStack] = [],
        tags: Set<InstructionTag> = [],
        produces: Produces,
        read: @escaping @Sendable ([any Item], ReadContext) -> [Router]
    ) -> Behavior {
        Behavior(label, requires: takes.map { Requirement.takes($0) } + reads.map { Requirement.reads($0) },
                 tags: tags, behaviorClass: .contextRead, body: .contextRead(read), produces: produces,
                 observes: observes)
    }


    // MARK: - Channels

    /// A print: take the top item of `stack` and move it to `.print`.
    ///
    /// The move crosses stacks, so the printed item records its argument and the
    /// instruction (provenance law 2): its crux rebuilds the item and prints it
    /// again.
    static func channel(
        _ label: PushInstruction,
        takes stack: PushStack,
        tags: Set<InstructionTag> = []
    ) -> Behavior {
        Behavior(label, requires: [.takes(stack)], tags: tags, behaviorClass: .channel,
                 body: .channel { args, recording in
                     var printed = args[0]
                     printed.call = recording([args[0], InstructionItem(label)])
                     return [printed]
                 },
                 produces: .printed)
    }
}
