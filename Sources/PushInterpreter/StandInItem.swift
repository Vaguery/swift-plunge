//
//  StandInItem.swift
//  PushInterpreter
//
//  A literal standing in for a history the interpreter could not, or chose not
//  to, keep. Added 2026-11-07 for provenance completeness.
//

/// A literal that **stands in for a lost history**, and says so.
///
/// The crux rule is: running an item's crux reproduces the item's value on its
/// stack, and every literal that stands in for a history is marked. A bare
/// literal would reproduce the value too, but it can't be told apart from a
/// literal the program really contained, so nothing could count how much of a
/// run's provenance is actually derived. A stand-in is that mark.
///
/// **It runs as the literal it replaces.** On `.exec`, `Interpreter.step` pushes a
/// copy of `value` whose `call` is this stand-in, so a replay reproduces the
/// original item exactly, history included. It never rests on a stack of its own
/// (`PushStack.defaultStack(for:)` is `nil`, as for `InstructionItem`).
///
/// **It names its cause.** `source` is the instruction that observed or produced
/// the value (`nil` for the interpreter's own diagnostics), and `reason` says why
/// the history is missing:
///
/// - `.observed`: the value was read from transient execution state, such as a
///   stack's depth or the step count, so re-running the instruction on a fresh
///   interpreter would find a different world (provenance law 4b). Prints as
///   `.boolStackDepth_actuallyWas_4`.
/// - `.elided`: the history existed but was over the `maxCallWeight` or
///   `maxCallDepth` budget, so it was dropped at the push boundary. Prints as
///   `.intAdd_elidedAs_4537`.
/// - `.minted`: a constant the instruction supplies itself, such as the 0 a
///   `.execDoTimes` counts from. No history is lost (the instruction *is* the
///   cause), but without the mark it would be indistinguishable from a
///   substitution. Prints as `.execDoTimes_minted_0`.
///
/// **It is a literal leaf.** Its own `call` is always empty, so `crux()` emits it
/// unchanged and every downstream crux carries it, which is what lets a probe
/// count stand-ins. Assigning a `call` is ignored.
///
/// **It is not forbidden anywhere.** A stand-in in evolved code is just a
/// labelled constant, so there's no need for a category of instruction that
/// programs may not contain.
public nonisolated struct StandInItem: Item, Equatable, Pretty {

    /// Why the history is missing.
    public enum Reason: String, Sendable, Codable {
        /// Read from transient execution state (provenance law 4b).
        case observed
        /// Over the provenance budget, and dropped at the push boundary.
        case elided
        /// A constant the instruction supplies itself; nothing is lost.
        case minted
    }

    /// The literal this stands in for, without a history of its own.
    public var value: any Item
    /// The instruction that observed or produced the value; `nil` for the
    /// interpreter's own diagnostics.
    public let source: PushInstruction?
    /// Why the history is missing.
    public let reason: Reason

    /// Always empty: a stand-in is a literal. Assignment is ignored.
    public var call: [any Item] {
        get { [] }
        // swiftlint:disable:next unused_setter_value
        set { }
    }
    public var callWeight: Int { Int(CallMeasure.literal.weight) }
    public var callDepth: Int { Int(CallMeasure.literal.depth) }
    public var weight: Int { value.weight }
    public var nestingDepth: Int { value.nestingDepth }

    /// A stand-in for `value`, which is stored without its history.
    public init(standingInFor value: any Item, source: PushInstruction?, reason: Reason) {
        var bare = value
        bare.call = []
        self.value = bare
        self.source = source
        self.reason = reason
    }

    /// The item this stand-in releases when it runs: `value`, whose `call` is
    /// this stand-in when recording, so a replay reproduces the original exactly.
    func released(_ recording: ProvenanceRecording) -> any Item {
        var item = value
        item.call = recording([self])
        return item
    }

    public static func == (lhs: StandInItem, rhs: StandInItem) -> Bool {
        lhs.value.isEqual(to: rhs.value) && lhs.source == rhs.source && lhs.reason == rhs.reason
    }

    public func pretty() -> String {
        let name = source.map(\.rawValue) ?? "interpreter"
        let verb = switch reason {
        case .observed: "actuallyWas"
        case .elided: "elidedAs"
        case .minted: "minted"
        }
        return ".\(name)_\(verb)_\(value.pretty())"
    }
}

nonisolated extension Item {
    /// This item, recorded as **observed** by `source`: its `call` is a single
    /// stand-in when recording, empty otherwise.
    ///
    /// For results read from transient execution state (provenance law 4b), such
    /// as `.boolStackDepth`, `.pushStepCount`, the "missing args" errors and the
    /// interpreter's own diagnostics. Re-running the instruction on a fresh
    /// interpreter would not find the same state, so the value is recorded as a
    /// literal, and the stand-in marks it as one and names its cause.
    @inline(__always)
    func observed(by source: PushInstruction?, _ recording: ProvenanceRecording) -> Self {
        marked(.observed, by: source, recording)
    }

    /// This item, recorded as a constant `source` supplies itself (`.minted`): its
    /// `call` is a single stand-in when recording, empty otherwise.
    @inline(__always)
    func minted(by source: PushInstruction, _ recording: ProvenanceRecording) -> Self {
        marked(.minted, by: source, recording)
    }

    @inline(__always)
    private func marked(_ reason: StandInItem.Reason, by source: PushInstruction?,
                        _ recording: ProvenanceRecording) -> Self {
        // The "missing args" error is the commonest event in a random program, so
        // the search (recording off) must pay nothing here, not even a copy.
        guard recording.isOn else { return self }
        var marked = self
        marked.call = [StandInItem(standingInFor: self, source: source, reason: reason)]
        return marked
    }
}
