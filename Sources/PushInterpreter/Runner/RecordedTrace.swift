//
//  RecordedTrace.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
//

/// The per-step observations one recorder collected during a run, typed by its
/// target's value kind.
///
/// Item-valued targets (`top`, `second`, `constant`) keep the `any Item`, with
/// its `call` provenance (`crux`) while the trace is in memory, while scalar
/// targets keep their natural value. **Encoded, a trace keeps values only**:
/// `AnyItem` drops histories. To carry them across a process boundary, encode
/// the items as an `ItemArchive` (opt-in). A `nil` element is a step where the observed
/// position held nothing.
public nonisolated enum RecordedTrace: Sendable, Equatable, Codable {
    case items([AnyItem?])
    case ints([Int?])
    case strings([String?])
    case bools([Bool?])

    /// Repackages a recorder's type-erased `[Any?]` data into the typed case its
    /// target implies.
    init(target: RecorderTarget, raw: [Any?]) {
        switch target.valueKind {
        case .item:   self = .items(raw.map { ($0 as? any Item).map(AnyItem.init) })
        case .int:    self = .ints(raw.map { $0 as? Int })
        case .string: self = .strings(raw.map { $0 as? String })
        case .bool:   self = .bools(raw.map { $0 as? Bool })
        }
    }
}
