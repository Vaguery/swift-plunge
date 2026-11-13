//
//  TrainingCase.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

/// One set of inputs to run a program on, with an identifier.
///
/// A training case holds inputs only. What the right answer is, and how far an
/// observed answer is from it, are the search's concern: the library returns
/// what it observed and leaves the scoring to the caller. See
/// <doc:InputsAndConstants>.
public nonisolated struct TrainingCase: Identifiable, Sendable {
    /// An identifier, unique among the training cases evaluated together. Pairings
    /// and results refer to the training case by it.
    public let id: String
    /// The value of each input, keyed by its instruction, such as `.input0`. An
    /// input can be an item of any type.
    public let inputs: [PushInstruction: any Item]

    /// Creates a training case. Without inputs, every input instruction in a program leaves an error.
    public init(id: String, inputs: [PushInstruction: any Item] = [:]) {
        self.id = id
        self.inputs = inputs
    }
}


extension TrainingCase: Codable {
    // `inputs` holds `any Item`, so it bridges through AnyItem as an
    // instruction-keyed map.
    private enum CodingKeys: String, CodingKey {
        case id, inputs
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            inputs: ItemBindingCoding.decode(
                try container.decode([String: AnyItem].self, forKey: .inputs)
            )
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ItemBindingCoding.encode(inputs), forKey: .inputs)
    }
}
