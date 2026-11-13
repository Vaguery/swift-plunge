//
//  Pairing.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

/// A request to run one individual on one training case, each named by its
/// identifier.
///
/// The search chooses which pairings to ask for. The library never fills in the
/// whole grid of individuals and cases on its own, because methods such as
/// lexicase selection and down-sampling depend on evaluating deliberate, often
/// sparse, subsets.
public nonisolated struct Pairing: Sendable, Hashable, Codable {
    /// The identifier of the individual to run.
    public let individual: String
    /// The identifier of the training case to run it on.
    public let trainingCase: String

    /// Creates a pairing from two identifiers.
    public init(individual: String, trainingCase: String) {
        self.individual = individual
        self.trainingCase = trainingCase
    }
}
