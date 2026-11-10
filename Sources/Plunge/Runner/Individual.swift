//
//  Individual.swift
//  Plunge
//
//  Created by Bill Tozier on 6/3/26.
//

/// The execution-relevant payload for one candidate: a ready-to-run `program`
/// plus the constant bindings that parameterize it.
///
/// This is deliberately *not* the whole individual the Searcher works with. The
/// Searcher's individual also carries a source genome (in a `GenomeEncoding`
/// scheme) and other bookkeeping; only the parts that affect execution and
/// evaluation are sent here. The `program` is already translated — the Runner
/// slots it straight into an `Interpreter` and never translates a genome.
///
/// Constants are keyed by their instruction token (e.g. `.int3`), so they can be
/// optimized independently of the program's structure.
public nonisolated struct Individual: Identifiable, Sendable {
    public let id: String
    public let program: [any Item]
    public let constants: [PushInstruction: any Item]

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
