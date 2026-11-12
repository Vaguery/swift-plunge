//
//  ReadContext.swift
//  Plunge
//
//  The read-only view a context read gets of the interpreter.
//

import DequeModule

/// **The interpreter, read-only**: everything a context read may consult — the
/// environment (constants and inputs), the clock, and the shape and contents of
/// the stacks — and nothing it could change. A context read is a source: what it
/// returns goes through the same `Router`s as any result.
///
/// It holds the interpreter rather than copying from it, so building one costs
/// nothing; what it exposes is only ever read.
nonisolated struct ReadContext {
    private let interpreter: Interpreter

    init(_ interpreter: Interpreter) { self.interpreter = interpreter }

    /// Work an `applying` body did that the step counter should see: steps run
    /// in a sub-interpreter by map, filter and reduce. The body only reports it;
    /// `Behavior.act` adds it to the counter, so no body mutates the interpreter.
    let meter = WorkMeter()

    /// The steps left in this run's budget, less what this read has charged.
    var remainingSteps: Int { max(0, interpreter.config.stepLimit - interpreter.counter - meter.steps) }

    /// Reports `steps` of work done (see `meter`).
    func charge(_ steps: Int) { meter.steps += steps }
    /// A fresh `.binding` key: the interpreter's next, counting those this read has
    /// already drawn. `Behavior.act` advances the counter past them.
    func freshKey() -> Int {
        defer { meter.keysDrawn += 1 }
        return interpreter.nextRefKey + meter.keysDrawn
    }

    /// The typed constant bindings (`.int3`, `.vecDouble8`).
    var constants: [PushInstruction: any Item] { interpreter.constants }
    /// The input bindings (`.input0` …).
    var inputs: [PushInstruction: any Item] { interpreter.inputs }
    /// Steps completed before this one (`pushStepCount`).
    var stepCount: Int { interpreter.counter }
    /// Whether the step before this one placed anything on `.error`.
    var previousStepErred: Bool { interpreter.lastErrorStep == interpreter.counter - 1 }
    /// How many sandboxes deep this run is (`Interpreter.sandboxDepth`).
    var sandboxDepth: Int { interpreter.sandboxDepth }
    /// Whether this run may start a sandbox of its own (`Interpreter.maxSandboxDepth`).
    var maySandbox: Bool { interpreter.sandboxDepth < Interpreter.maxSandboxDepth }
    /// Whether provenance is being recorded.
    var recording: ProvenanceRecording { interpreter.recording }

    /// How many items `stack` holds.
    func depth(of stack: PushStack) -> Int {
        noteLooking(at: stack)
        return interpreter.stacks[stack]?.count ?? 0
    }

    /// The whole of `stack`, top first. A copy-on-write value: reading it copies
    /// nothing.
    func items(of stack: PushStack) -> Deque<any Item> {
        noteLooking(at: stack)
        return interpreter.stacks[stack] ?? []
    }

    #if DEBUG
    /// Collects the stacks a body looks at on one interpreter (not the
    /// sub-interpreters a map runs), so a test can hold each Behavior's
    /// `observes` to what it reads. Debug builds only.
    final class StackWatch: @unchecked Sendable {
        let target: ObjectIdentifier
        var stacks: Set<PushStack> = []
        init(_ interpreter: Interpreter) { target = ObjectIdentifier(interpreter) }
    }
    @TaskLocal static var watch: StackWatch?
    private func noteLooking(at stack: PushStack) {
        if let watch = Self.watch, watch.target == ObjectIdentifier(interpreter) { watch.stacks.insert(stack) }
    }
    #else
    @inline(__always) private func noteLooking(at stack: PushStack) {}
    #endif

    /// How many errors of `kind` are on `.error`, from the running tally.
    func errorCount(of kind: ErrorKind) -> Int { interpreter.stacks.errorCount(of: kind) }
}


/// The work a context read reports (`ReadContext.meter`).
nonisolated final class WorkMeter {
    var steps = 0
    /// Fresh `.binding` keys drawn (`freshKey`).
    var keysDrawn = 0
}
