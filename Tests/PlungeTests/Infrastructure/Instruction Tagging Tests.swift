//
//  Instruction Tagging Tests.swift
//  PlungeTests
//
//  Tags are an open, descriptive vocabulary, not a fixed ontology, so the one
//  rule is that nothing goes unlabeled.
//

@testable import Plunge
import Testing

@Suite
struct InstructionTaggingTests {

    @Test func `every instruction carries at least one tag`() {
        let tagging = InstructionTagging.standard
        let untagged = Interpreter.language.keys.filter { tagging.tags(of: $0).isEmpty }.map(\.rawValue).sorted()
        #expect(untagged.isEmpty, "untagged: \(untagged)")
    }
}
