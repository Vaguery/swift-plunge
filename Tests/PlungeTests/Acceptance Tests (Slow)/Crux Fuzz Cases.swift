//
//  Crux Fuzz Cases.swift
//  PlungeTests
//
//  Writing a failing crux fuzz case to disk, kept apart from the fuzz itself.
//

import Foundation
@testable import Plunge

extension CruxFuzzTests {
    /// A failing case as a replayable request in `$TMPDIR/push-crux-fuzz`.
    static func save(_ caseId: String, _ program: [any Item], _ inputs: [PushInstruction: any Item],
                     _ constants: [PushInstruction: any Item], _ settings: InterpreterSettings) -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "push-crux-fuzz")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let request = EvaluationRequest(
            individuals: [Individual(id: caseId, program: program, constants: constants)],
            trainingCases: [TrainingCase(id: caseId, inputs: inputs)],
            pairings: [Pairing(individual: caseId, trainingCase: caseId)],
            configuration: RunnerConfiguration(settings: settings)
        )
        let url = dir.appending(path: "\(caseId).json")
        try? JSONEncoder().encode(request).write(to: url)
        return url
    }
}
