//
//  ProvenanceRecording.swift
//  Plunge
//

/// Whether this run records provenance — the `call` from which an item's `crux()`
/// rebuilds a runnable program. Handed to every Behavior alongside its arguments
/// (`InterpreterSettings.recordsProvenance` decides it, per interpreter).
///
/// **This is the seam between calculation and provenance.** A Behavior computes its
/// values in ordinary code, and writes every provenance expression inside
/// `recording(…)`:
///
/// ```swift
/// IntItem(y.value + x.value, call: recording([y, x, InstructionItem(.intAdd)]))
/// ```
///
/// The argument is an `@autoclosure`, so when recording is off it is **never
/// evaluated**: no array is built, no `Behavior.reading`/`selecting` sorts or
/// allocates, no iterator `reconstruction()` runs. The item gets an empty `call`,
/// which `crux()` treats as a literal. When recording is on, the expression runs
/// exactly as written, so the provenance is what it always was.
///
/// Nothing computes a *value* from `call` (equality, limits and encoding all
/// ignore it), so turning recording off cannot change what a program computes —
/// only whether its results can explain themselves.
public nonisolated struct ProvenanceRecording: Sendable {
    /// Whether provenance expressions are evaluated.
    public let isOn: Bool

    /// Creates a recording switch. Use ``on`` and ``off``.
    public init(isOn: Bool) {
        self.isOn = isOn
    }

    /// Recording on: provenance is built as written.
    public static let on = ProvenanceRecording(isOn: true)
    /// Recording off: provenance expressions are skipped, every `call` is empty.
    public static let off = ProvenanceRecording(isOn: false)

    /// `call` when recording, otherwise `[]` without evaluating `call` at all.
    @inline(__always)
    public func callAsFunction(_ call: @autoclosure () -> [any Item]) -> [any Item] {
        isOn ? call() : []
    }
}
