//
//  Individual.swift
//  Plunge
//
//  Created by Bill Tozier on 6/3/26.
//

/// A program to evaluate, with an identifier and the values of its constants,
/// and the genome it came from, if it has one.
///
/// A search edits genomes, so an individual made from one keeps it
/// (`init(id:genome:)`): the program and the constants are the genome's
/// translation, and the ``Runner`` runs those. An individual made from a program
/// has no genome; ``Genome/init(program:constants:)`` makes one when a search
/// needs it. Whatever else a search keeps about a candidate (its ancestry, its
/// scores, what it has cached) stays with the search.
///
/// Constants are keyed by their instruction, such as `.constant3`, so that a search
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
    /// The genome the program and constants were translated from, or nil for an
    /// individual made from a program.
    public let genome: Genome?

    /// Creates an individual from a program. Without constants, every constant
    /// instruction in the program leaves an error.
    public init(id: String,
                program: [any Item],
                constants: [PushInstruction: any Item] = [:]) {
        self.id = id
        self.program = program
        self.constants = constants
        self.genome = nil
    }

    /// Creates an individual from a genome: its program is the genome's
    /// translation, and its constants are the genome's.
    public init(id: String, genome: Genome) {
        self.init(id: id, program: genome.translate(), constants: genome.constants, genome: genome)
    }

    /// Every field as given: for decoding, which reads the program and the
    /// genome separately.
    init(id: String, program: [any Item], constants: [PushInstruction: any Item], genome: Genome?) {
        self.id = id
        self.program = program
        self.constants = constants
        self.genome = genome
    }
}


extension Individual: Codable {
    // `program` and `constants` hold `any Item`, so they bridge through AnyItem:
    // the program as an [AnyItem], the constants as an instruction-keyed map.
    private enum CodingKeys: String, CodingKey {
        case id, program, constants, genome
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // The program and constants are always encoded, so a reader that knows
        // nothing of genomes can run the individual; `genome` came later
        // (2026-11-19) and may be absent.
        self.init(
            id: try container.decode(String.self, forKey: .id),
            program: try container.decode([AnyItem].self, forKey: .program).map(\.item),
            constants: ItemBindingCoding.decode(
                try container.decode([String: AnyItem].self, forKey: .constants)
            ),
            genome: try container.decodeIfPresent(Genome.self, forKey: .genome)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(program.map(AnyItem.init), forKey: .program)
        try container.encode(ItemBindingCoding.encode(constants), forKey: .constants)
        try container.encodeIfPresent(genome, forKey: .genome)
    }
}
