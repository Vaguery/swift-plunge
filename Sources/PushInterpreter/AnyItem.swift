//
//  AnyItem.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
//

/// The concrete `Item` types, used as a Codable type tag.
nonisolated enum ItemKind: String, Codable, Sendable {
    case bool, char, code, double, instruction, int, string
    case vecBool, vecDouble, vecInt, vecString, error
}


/// A `Codable` envelope around the `any Item` existential, which cannot itself
/// carry a synthesized conformance.
///
/// Only an item's *type tag* and *value* are serialized. The runtime-only
/// fields — `call` (provenance), `isContingent`, and `index` — are deliberately
/// omitted: items in a program (or a `crux` result) are pristine on those
/// fronts, and they are reconstructed with their defaults on decode. Every
/// `Item.value` is a JSON-native type (or, for `CodeItem`, a nested array of
/// items), so the encoding is total.
///
/// Transport `[any Item]` as `program.map(AnyItem.init)` and recover it as
/// `decoded.map(\.item)`.
nonisolated struct AnyItem: Codable, Sendable {
    let item: any Item

    init(_ item: any Item) {
        self.item = item
    }

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    init(from decoder: any Decoder) throws {
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
        case .error:
            item = ErrorItem(try container.decode(String.self, forKey: .value))
        }
    }

    func encode(to encoder: any Encoder) throws {
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
        case let concrete as ErrorItem:
            try container.encode(ItemKind.error, forKey: .type)
            try container.encode(concrete.value, forKey: .value)
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
