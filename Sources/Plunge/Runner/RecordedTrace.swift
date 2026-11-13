//
//  RecordedTrace.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

/// What one recorder collected during one run: an array of readings, of the
/// type its target observes.
///
/// There is one reading for each step with ``RecordingPolicy/everyStep``, and
/// one in all with ``RecordingPolicy/finalOnly``. A run that took no steps has
/// no readings. A reading is `nil` when there was nothing to observe, such as
/// the top of an empty stack.
///
/// In memory, an item reading keeps the item's history, so you can ask it for
/// its crux. **Encoded, a trace keeps values only**: ``AnyItem`` leaves
/// histories out. To keep them, encode the items as an ``ItemArchive``. See
/// <doc:ObservingARun>.
public nonisolated enum RecordedTrace: Sendable, Equatable, Codable {
    /// Readings from a target that observes an item: `top`, `second` or `nth`.
    case items([AnyItem?])
    /// Readings from `count` or `counter`.
    case ints([Int?])
    /// Readings from `printout`.
    case strings([String?])
    /// Readings from `isEmpty`.
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
