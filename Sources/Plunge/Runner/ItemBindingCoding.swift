//
//  ItemBindingCoding.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 7/13/26.
//

/// Shared Codable bridging for instruction-keyed item maps (`inputs`,
/// `constants`), which hold the non-Codable `any Item` existential.
///
/// A binding map serializes as a `[String: AnyItem]` keyed by the instruction's
/// raw name. On decode, a key that is not a valid instruction token is skipped
/// (it cannot name a real input or constant), consistent with the Runner's
/// degrade-don't-crash handling of malformed input.
public nonisolated enum ItemBindingCoding {

    public static func encode(_ bindings: [PushInstruction: any Item]) -> [String: AnyItem] {
        var encoded: [String: AnyItem] = [:]
        for (instruction, item) in bindings {
            encoded[instruction.rawValue] = AnyItem(item)
        }
        return encoded
    }

    public static func decode(_ encoded: [String: AnyItem]) -> [PushInstruction: any Item] {
        var bindings: [PushInstruction: any Item] = [:]
        for (name, wrapper) in encoded {
            if let instruction = PushInstruction(rawValue: name) {
                bindings[instruction] = wrapper.item
            }
        }
        return bindings
    }
}
