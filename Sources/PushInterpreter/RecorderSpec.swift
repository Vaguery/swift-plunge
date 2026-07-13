//
//  RecorderSpec.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
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
/// `call` provenance (`crux`) for downstream analysis. Scalar targets that have
/// no underlying item (`count`, `isEmpty`, `printout`, `counter`) collect their
/// natural value type.
nonisolated enum RecorderTarget: Sendable, Hashable, Codable {
    /// The top item of a stack, or `nil` when the stack is empty.
    case top(PushStack)
    /// The second item of a stack, or `nil` when it holds fewer than two items.
    case second(PushStack)
    /// A bound constant slot, or `nil` when the slot is unset or out of range.
    case constant(PushStack, Int)
    /// The number of items currently on a stack (`Int`).
    case count(PushStack)
    /// Whether a stack is currently empty (`Bool`).
    case isEmpty(PushStack)
    /// The accumulated `printout` string of the interpreter (`String`).
    case printout
    /// The interpreter's step counter (`Int`).
    case counter
}


/// A named `RecorderTarget`. The name identifies the collected data in an
/// `Interpreter`'s `recorders` dictionary and in the reported results.
nonisolated struct RecorderSpec: Sendable, Hashable, Codable {
    let name: String
    let target: RecorderTarget

    init(_ name: String, observing target: RecorderTarget) {
        self.name = name
        self.target = target
    }
}


nonisolated extension AnyRecorder {
    /// Resolves a declarative `RecorderSpec` into a concrete, type-erased
    /// recorder whose closure reads the requested interpreter state each step.
    init(_ spec: RecorderSpec) {
        let name = spec.name
        switch spec.target {
        case .top(let stack):
            self.init(Recorder<any Item>(name) { interpreter in
                interpreter.stacks[stack]?.first
            })
        case .second(let stack):
            self.init(Recorder<any Item>(name) { interpreter in
                guard let items = interpreter.stacks[stack], items.count > 1
                else { return nil }
                return items[1]
            })
        case .constant(let stack, let index):
            self.init(Recorder<any Item>(name) { interpreter in
                guard let slots = interpreter.constants[stack],
                      slots.indices.contains(index)
                else { return nil }
                return slots[index]
            })
        case .count(let stack):
            self.init(Recorder<Int>(name) { interpreter in
                interpreter.stacks[stack]?.count ?? 0
            })
        case .isEmpty(let stack):
            self.init(Recorder<Bool>(name) { interpreter in
                interpreter.stacks[stack]?.isEmpty ?? true
            })
        case .printout:
            self.init(Recorder<String>(name) { interpreter in
                interpreter.printout
            })
        case .counter:
            self.init(Recorder<Int>(name) { interpreter in
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
