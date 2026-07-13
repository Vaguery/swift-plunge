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
nonisolated struct TrainingCase: Identifiable, Sendable {
    let id: String
    let inputs: [PushInstruction: any Item]

    init(id: String, inputs: [PushInstruction: any Item] = [:]) {
        self.id = id
        self.inputs = inputs
    }
}
