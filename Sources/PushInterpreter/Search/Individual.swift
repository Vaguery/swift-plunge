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
