//
//  RecorderSpec.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 7/13/26.
//

/// A declarative, `Sendable` description of *what* an observer should read from
/// an `Interpreter` on each step, without hand-writing a closure.
///
/// A `RecorderSpec` carries no closure, so it can be constructed by a search
/// process (potentially across a process or network boundary) and resolved into
/// a concrete `Recorder` locally by the `Runner`/`Interpreter` that owns the
/// run. The closure it resolves into can read any interpreter state; these cases
/// name the observations that have proven useful so far, and the set is meant to
/// grow.
///
/// Item-valued targets (`top`, `second`, `constant`) collect the `any Item`
/// itself rather than an unwrapped scalar, so the observation retains the item's
/// `call` provenance (`crux`) for downstream analysis: in memory, and across a
/// process boundary when encoded as an `ItemArchive` (`AnyItem`, the default
/// encoding, keeps values only). Scalar targets that have
/// no underlying item (`count`, `isEmpty`, `printout`, `counter`) collect their
/// natural value type.
public nonisolated enum RecorderTarget: Sendable, Hashable, Codable {
    /// The top item of a stack, or `nil` when the stack is empty.
    case top(PushStack)
    /// The second item of a stack, or `nil` when it holds fewer than two items.
    case second(PushStack)
    /// The number of items currently on a stack (`Int`).
    case count(PushStack)
    /// Whether a stack is currently empty (`Bool`).
    case isEmpty(PushStack)
    /// The accumulated `printout` string of the interpreter (`String`).
    case printout
    /// The interpreter's step counter (`Int`).
    case counter
}


nonisolated extension RecorderTarget {
    /// The natural value type a target collects, used to repackage a recorder's
    /// type-erased data into a typed `RecordedTrace`.
    enum ValueKind: Sendable {
        case item, int, string, bool
    }

    var valueKind: ValueKind {
        switch self {
        case .top, .second: .item
        case .count, .counter: .int
        case .printout: .string
        case .isEmpty: .bool
        }
    }
}


/// How much of the per-step observation stream a recorder keeps.
///
/// The default `.everyStep` retains one reading per step — the longitudinal trace
/// needed to reconstruct behavior over time. `.finalOnly` keeps just the most
/// recent reading, overwriting each step, so the recorder holds a *single* value
/// no matter how long the run: when only the end-of-run result is wanted (error
/// scoring reads the final top-of-stack), this avoids retaining a full trace of
/// provenance-carrying items per run — the dominant cost when a whole population
/// is evaluated at once.
public nonisolated enum RecordingPolicy: Sendable, Hashable, Codable {
    /// Keep one reading for every step (the full longitudinal trace).
    case everyStep
    /// Keep only the most recent reading (a single value, overwritten each step).
    case finalOnly
}


/// A named `RecorderTarget`. The name identifies the collected data in an
/// `Interpreter`'s `recorders` dictionary and in the reported results.
public nonisolated struct RecorderSpec: Sendable, Hashable, Codable {
    public let name: String
    public let target: RecorderTarget
    public let policy: RecordingPolicy

    public init(_ name: String, observing target: RecorderTarget, keeping policy: RecordingPolicy = .everyStep) {
        self.name = name
        self.target = target
        self.policy = policy
    }
}


nonisolated extension AnyRecorder {
    /// Resolves a declarative `RecorderSpec` into a concrete, type-erased
    /// recorder whose closure reads the requested interpreter state each step.
    init(_ spec: RecorderSpec) {
        let name = spec.name
        let policy = spec.policy
        switch spec.target {
        case .top(let stack):
            self.init(Recorder<any Item>(name, keeping: policy) { interpreter in
                interpreter.stacks[stack]?.first
            })
        case .second(let stack):
            self.init(Recorder<any Item>(name, keeping: policy) { interpreter in
                guard let items = interpreter.stacks[stack], items.count > 1
                else { return nil }
                return items[1]
            })
        case .count(let stack):
            self.init(Recorder<Int>(name, keeping: policy) { interpreter in
                interpreter.stacks[stack]?.count ?? 0
            })
        case .isEmpty(let stack):
            self.init(Recorder<Bool>(name, keeping: policy) { interpreter in
                interpreter.stacks[stack]?.isEmpty ?? true
            })
        case .printout:
            self.init(Recorder<String>(name, keeping: policy) { interpreter in
                interpreter.printout
            })
        case .counter:
            self.init(Recorder<Int>(name, keeping: policy) { interpreter in
                interpreter.counter
            })
        }
    }
}


nonisolated extension Interpreter {
    /// Builds a recorder from a `RecorderSpec` and installs it, keyed by name.
    func addRecorder(_ spec: RecorderSpec) {
        recorders[spec.name] = AnyRecorder(spec)
    }

    /// Installs several recorders from their specifications.
    func addRecorders(_ specs: [RecorderSpec]) {
        for spec in specs { addRecorder(spec) }
    }

    /// The data a named recorder has collected, type-erased. `nil` when no
    /// recorder is installed under `name`.
    func recordedData(_ name: String) -> [Any?]? {
        recorders[name]?.dataAsAnyArray
    }
}
