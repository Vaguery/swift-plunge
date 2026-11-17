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

    @Test func `flow tags count the items an instruction leaves against those it takes`() {
        let tagging = InstructionTagging.standard
        let flow: [InstructionTag] = [.consumer, .neutral, .producer]
        func flowTags(_ instruction: PushInstruction) -> Set<InstructionTag> {
            tagging.tags(of: instruction).intersection(flow)
        }
        #expect(flowTags(.intAdd) == [.consumer])
        #expect(flowTags(.stringReverse) == [.neutral])
        #expect(flowTags(.input0) == [.producer])
        #expect(flowTags(.int0) == [.producer])
        // Rearrangers and control declare no count.
        #expect(flowTags(.intDup).isEmpty && flowTags(.intPop).isEmpty && flowTags(.execIf).isEmpty)
        // At most one flow tag each, and the three are the flow facet.
        #expect(Interpreter.language.keys.allSatisfy { flowTags($0).count <= 1 })
        #expect(flow.allSatisfy { $0.facet == .flow && $0.provenance == .derived })
        #expect(flow.allSatisfy { !tagging.instructions(tagged: $0).isEmpty })
    }
}
