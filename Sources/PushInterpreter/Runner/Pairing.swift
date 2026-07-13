//
//  Pairing.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
//

/// A single unit of evaluation work: run one individual against one training
/// case, both named by id.
///
/// The search process chooses which pairings to request; the Runner never
/// generates the full individual×case grid itself. Lexicase selection and
/// down-sampling depend on evaluating deliberate, often sparse, subsets of
/// pairings.
public nonisolated struct Pairing: Sendable, Hashable, Codable {
    public let individual: String
    public let trainingCase: String

    public init(individual: String, trainingCase: String) {
        self.individual = individual
        self.trainingCase = trainingCase
    }
}
