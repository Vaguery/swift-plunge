//
//  TrainingCase.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
//

/// One fitness case: the input bindings a program is run against, keyed by input
/// token (e.g. `.input0`).
///
/// Expected outputs and the reduction of observations to an error are the search
/// process's concern, not the Runner's — the Runner returns raw observations and
/// lets the caller score them.
public nonisolated struct TrainingCase: Identifiable, Sendable {
    public let id: String
    public let inputs: [PushInstruction: any Item]

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
