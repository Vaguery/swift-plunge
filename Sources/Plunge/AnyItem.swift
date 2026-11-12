//
//  AnyItem.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

/// The concrete `Item` types, used as a Codable type tag.
nonisolated enum ItemKind: String, Codable, Sendable {
    case bool, char, code, double, instruction, int, string
    case vecBool, vecDouble, vecInt, vecString, iterator, error, standIn, binding, function
}

/// Everything a `StandInItem` needs to be rebuilt: the literal it stands in for,
/// nested as an `AnyItem` (as an iterator's origin is), and its label. Value
/// content, not history: a stand-in *is* the marked literal, so encoding it does
/// not breach the envelope's rule against serializing provenance. Kept generic (a
/// nested item plus a label) so a future local-variable type can share the shape.
///
nonisolated struct StandInState: Codable, Sendable {
    var value: AnyItem
    var source: PushInstruction?
    var reason: StandInItem.Reason
}


/// Everything a `FunctionItem` needs to be rebuilt: its body, nested as
/// `AnyItem`s as a block's contents are, and, for a derived function, its holes
/// and output stack.
nonisolated struct FunctionState: Codable, Sendable {
    var body: [AnyItem]
    var holes: [FunctionItem.Hole]?
    var output: PushStack?

    /// The function, or nil for a bare one that does not hold exactly one item.
    var item: FunctionItem? {
        let items = body.map(\.item)
        if let holes, let output { return FunctionItem(body: items, holes: holes, output: output) }
        return items.count == 1 ? FunctionItem(bare: items[0]) : nil
    }
}

/// Everything a `BindingItem` needs to be rebuilt: its key and the item bound to
/// it, nested as an `AnyItem`.
nonisolated struct BindingState: Codable, Sendable {
    var key: Int
    var bound: AnyItem
}


/// Everything an `IteratorItem` needs to be rebuilt.
///
/// The only item whose envelope `value` is a structure rather than a scalar: an
/// iterator's `value` is just its cursor, but what it *is* — the loop it
/// describes — is the whole of this. All of it is value content (where the loop
/// starts, where it ends, its stride, how far it has come, what it emits), not
/// history, so carrying it does not breach the envelope's rule against
/// serializing provenance. `origin` and `body` nest as `AnyItem`s, exactly as a
/// `CodeItem`'s contents do.
nonisolated struct IteratorState: Codable, Sendable {
    var cursor: Int
    var kind: IteratorKind
    var origin: AnyItem
    var destination: AnyItem?
    /// Absent for a sequence — an iterator that only emits and has no body to run.
    var body: AnyItem?
    var emits: Bool
    var burial: Int
    /// Absent from anything encoded before 2026-11-08, which dropped it (a
    /// cycling walk came back as one lap); decoded as 1 then.
    var laps: Int?
}


/// A `Codable` envelope around the `any Item` existential, which cannot itself
/// carry a synthesized conformance.
///
/// Only an item's *type tag* and *value* are serialized. Its history (`call`,
/// and a container's members) is deliberately omitted: items in a program (or
/// a `crux` result) have none, and a decoded item comes back as a literal, its
/// crux itself. To keep histories, encode an `ItemArchive` instead (opt-in).
/// Every `Item.value` is a JSON-native type (or, for `CodeItem`, a nested array
/// of items), so the encoding is total.
///
/// Transport `[any Item]` as `program.map(AnyItem.init)` and recover it as
/// `decoded.map(\.item)`.
public nonisolated struct AnyItem: Codable, Sendable, Equatable {
    public let item: any Item

    public init(_ item: any Item) {
        self.item = item
    }

    public static func == (lhs: AnyItem, rhs: AnyItem) -> Bool {
        lhs.item.isEqual(to: rhs.item)
    }

    private enum CodingKeys: String, CodingKey {
        case type, value, errorKind
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(ItemKind.self, forKey: .type)
        switch kind {
        case .bool:
            item = BoolItem(try container.decode(Bool.self, forKey: .value))
        case .char:
            let string = try container.decode(String.self, forKey: .value)
            guard string.count == 1, let character = string.first else {
                throw DecodingError.dataCorruptedError(
                    forKey: .value, in: container,
                    debugDescription: "CharItem expects a single-character string, got \"\(string)\""
                )
            }
            item = CharItem(character)
        case .code:
            let nested = try container.decode([AnyItem].self, forKey: .value)
            item = CodeItem(nested.map(\.item))
        case .double:
            item = DoubleItem(try container.decode(Double.self, forKey: .value))
        case .instruction:
            item = InstructionItem(try container.decode(PushInstruction.self, forKey: .value))
        case .int:
            item = IntItem(try container.decode(Int.self, forKey: .value))
        case .string:
            item = StringItem(try container.decode(String.self, forKey: .value))
        case .vecBool:
            item = VecBoolItem(try container.decode([Bool].self, forKey: .value))
        case .vecDouble:
            item = VecDoubleItem(try container.decode([Double].self, forKey: .value))
        case .vecInt:
            item = VecIntItem(try container.decode([Int].self, forKey: .value))
        case .vecString:
            item = VecStringItem(try container.decode([String].self, forKey: .value))
        case .iterator:
            let state = try container.decode(IteratorState.self, forKey: .value)
            var body: CodeItem?
            if let encoded = state.body?.item {
                guard let block = encoded.exactly(CodeItem.self) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .value, in: container,
                        debugDescription: "an iterator's body must be a code block, got \(type(of: encoded))"
                    )
                }
                body = block
            }
            item = IteratorItem(
                kind: state.kind,
                origin: state.origin.item,
                destination: state.destination?.item,
                body: body,
                emits: state.emits,
                cursor: state.cursor,
                laps: state.laps ?? 1,
                burial: state.burial
            )
        case .binding:
            let state = try container.decode(BindingState.self, forKey: .value)
            item = BindingItem(key: state.key, bound: state.bound.item)
        case .function:
            guard let function = try container.decode(FunctionState.self, forKey: .value).item else {
                throw DecodingError.dataCorruptedError(forKey: .value, in: container,
                                                       debugDescription: "a bare function holds one item")
            }
            item = function
        case .standIn:
            let state = try container.decode(StandInState.self, forKey: .value)
            item = StandInItem(standingInFor: state.value.item, source: state.source, reason: state.reason)
        case .error:
            // `errorKind` is absent from anything encoded before it existed, so
            // decode it leniently and fall back to the same default `init` uses.
            item = ErrorItem(
                try container.decode(String.self, forKey: .value),
                kind: try container.decodeIfPresent(ErrorKind.self, forKey: .errorKind) ?? .other)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch item {
        case let concrete as BoolItem:
            try container.encode(ItemKind.bool, forKey: .type)
            try container.encode(concrete.value, forKey: .value)
        case let concrete as CharItem:
            try container.encode(ItemKind.char, forKey: .type)
            try container.encode(String(concrete.value), forKey: .value)
        case let concrete as CodeItem:
            try container.encode(ItemKind.code, forKey: .type)
            try container.encode(concrete.value.map(AnyItem.init), forKey: .value)
        case let concrete as DoubleItem:
            try container.encode(ItemKind.double, forKey: .type)
            try container.encode(concrete.value, forKey: .value)
        case let concrete as InstructionItem:
            try container.encode(ItemKind.instruction, forKey: .type)
            try container.encode(concrete.value, forKey: .value)
        case let concrete as IntItem:
            try container.encode(ItemKind.int, forKey: .type)
            try container.encode(concrete.value, forKey: .value)
        case let concrete as StringItem:
            try container.encode(ItemKind.string, forKey: .type)
            try container.encode(concrete.value, forKey: .value)
        case let concrete as VecBoolItem:
            try container.encode(ItemKind.vecBool, forKey: .type)
            try container.encode(concrete.value, forKey: .value)
        case let concrete as VecDoubleItem:
            try container.encode(ItemKind.vecDouble, forKey: .type)
            try container.encode(concrete.value, forKey: .value)
        case let concrete as VecIntItem:
            try container.encode(ItemKind.vecInt, forKey: .type)
            try container.encode(concrete.value, forKey: .value)
        case let concrete as VecStringItem:
            try container.encode(ItemKind.vecString, forKey: .type)
            try container.encode(concrete.value, forKey: .value)
        case let concrete as IteratorItem:
            try container.encode(ItemKind.iterator, forKey: .type)
            try container.encode(
                IteratorState(
                    cursor: concrete.value,
                    kind: concrete.kind,
                    origin: AnyItem(concrete.origin),
                    destination: concrete.destination.map(AnyItem.init),
                    body: concrete.body.map(AnyItem.init),
                    emits: concrete.emits,
                    burial: concrete.burial,
                    laps: concrete.laps
                ),
                forKey: .value
            )
        case let concrete as BindingItem:
            try container.encode(ItemKind.binding, forKey: .type)
            try container.encode(BindingState(key: concrete.key, bound: AnyItem(concrete.bound)), forKey: .value)
        case let concrete as FunctionItem:
            try container.encode(ItemKind.function, forKey: .type)
            try container.encode(
                FunctionState(body: concrete.value.map(AnyItem.init),
                              holes: concrete.isBare ? nil : concrete.holes,
                              output: concrete.isBare ? nil : concrete.output),
                forKey: .value)
        case let concrete as StandInItem:
            try container.encode(ItemKind.standIn, forKey: .type)
            try container.encode(
                StandInState(value: AnyItem(concrete.value), source: concrete.source, reason: concrete.reason),
                forKey: .value
            )
        case let concrete as ErrorItem:
            try container.encode(ItemKind.error, forKey: .type)
            try container.encode(concrete.value, forKey: .value)
            // Carried rather than dropped, unlike `call`. `kind` is a fact about
            // the error itself, not about how it came to be, and the introspection
            // instructions that count by kind would silently under-report on
            // anything that had crossed this boundary.
            try container.encode(concrete.kind, forKey: .errorKind)
        default:
            throw EncodingError.invalidValue(
                item,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unknown Item type \(type(of: item)) has no Codable envelope case"
                )
            )
        }
    }
}
