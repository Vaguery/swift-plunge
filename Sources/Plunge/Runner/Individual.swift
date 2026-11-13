//
//  Individual.swift
//  Plunge
//
//  Created by Bill Tozier on 6/3/26.
//

/// A program to evaluate, with an identifier and the values of its constants.
///
/// This is only the part of a candidate that affects how it runs. Whatever else
/// a search keeps about it (a genome it was translated from, its ancestry, its
/// scores) stays with the search. The library is given a program that is ready
/// to run, and never translates one.
///
/// Constants are keyed by their instruction, such as `.int3`, so that a search
/// can tune them without changing the program's structure. See
/// <doc:InputsAndConstants>.
public nonisolated struct Individual: Identifiable, Sendable {
    /// An identifier, unique among the individuals evaluated together. Pairings and
    /// results refer to the individual by it.
    public let id: String
    /// The items to run, first to last.
    public let program: [any Item]
    /// The value of each constant the program may use, keyed by its instruction. A
    /// value of the wrong type for its instruction is ignored when the run is
    /// loaded.
    public let constants: [PushInstruction: any Item]

    /// Creates an individual. Without constants, every constant instruction in the program leaves an error.
    public init(id: String,
         program: [any Item],
         constants: [PushInstruction: any Item] = [:]) {
        self.id = id
        self.program = program
        self.constants = constants
    }
}


extension Individual: Codable {
    // `program` and `constants` hold `any Item`, so they bridge through AnyItem:
    // the program as an [AnyItem], the constants as an instruction-keyed map.
    private enum CodingKeys: String, CodingKey {
        case id, program, constants
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            program: try container.decode([AnyItem].self, forKey: .program).map(\.item),
            constants: ItemBindingCoding.decode(
                try container.decode([String: AnyItem].self, forKey: .constants)
            )
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(program.map(AnyItem.init), forKey: .program)
        try container.encode(ItemBindingCoding.encode(constants), forKey: .constants)
    }
}
