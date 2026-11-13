//
//  ItemBindingCoding.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

/// Encodes and decodes maps from instructions to items, such as a training
/// case's inputs or an individual's constants.
///
/// A map is encoded as a dictionary from each instruction's name to an
/// ``AnyItem``. When decoding, a key that names no instruction is skipped.
/// ``Individual`` and ``TrainingCase`` use this for their own `Codable`
/// conformances; you need it only to encode such a map on its own.
public nonisolated enum ItemBindingCoding {

    /// The map as a dictionary from instruction names to wrapped items.
    public static func encode(_ bindings: [PushInstruction: any Item]) -> [String: AnyItem] {
        var encoded: [String: AnyItem] = [:]
        for (instruction, item) in bindings {
            encoded[instruction.rawValue] = AnyItem(item)
        }
        return encoded
    }

    /// The map a dictionary of names and wrapped items stands for, leaving out any key that names no instruction.
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
