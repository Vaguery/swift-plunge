//
//  Individual.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/3/26.
//

/// A candidate program to evaluate: a genome plus the constant bindings that
/// parameterize it.
///
/// Constants are keyed by their instruction token (e.g. `.int3`), the same
/// representation the interpreter uses, so they can be optimized independently
/// of the genome's structure — the separation a constant-search inner loop
/// relies on.
nonisolated struct Individual: Identifiable, Sendable {
    let id: String
    let genome: [any Item]
    let constants: [PushInstruction: any Item]

    init(id: String,
         genome: [any Item],
         constants: [PushInstruction: any Item] = [:]) {
        self.id = id
        self.genome = genome
        self.constants = constants
    }
}


extension Individual: Codable {
    // `genome` and `constants` hold `any Item`, so they bridge through AnyItem:
    // the genome as an [AnyItem], the constants as an instruction-keyed map.
    private enum CodingKeys: String, CodingKey {
        case id, genome, constants
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            genome: try container.decode([AnyItem].self, forKey: .genome).map(\.item),
            constants: ItemBindingCoding.decode(
                try container.decode([String: AnyItem].self, forKey: .constants)
            )
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(genome.map(AnyItem.init), forKey: .genome)
        try container.encode(ItemBindingCoding.encode(constants), forKey: .constants)
    }
}
