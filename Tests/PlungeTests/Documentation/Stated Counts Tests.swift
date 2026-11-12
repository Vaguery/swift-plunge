//
//  Stated Counts Tests.swift
//  PlungeTests
//
//  The README and the DocC landing page say how big the language is ("864
//  instructions over 13 typed stacks"). Those numbers are written by hand, and
//  went stale twice as the language grew. These tests read them back and compare
//  them with the language itself, so adding an instruction or a stack fails here
//  until the prose is updated.
//
//  The typed stacks are every `PushStack` but `.error`, which collects errors
//  rather than holding values of a type.
//

import Foundation
import Plunge
import Testing

@Suite
struct StatedCountsTests {

    static let packageRoot = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Every document that states the counts, relative to the package root.
    static let documents = ["README.md", "Sources/Plunge/Plunge.docc/Plunge.md"]

    @Test(arguments: documents)
    func `stated counts match the language`(document: String) throws {
        let text = try String(contentsOf: Self.packageRoot.appending(path: document), encoding: .utf8)
        // Prose wraps, so any run of whitespace may separate the words; a count
        // over 999 is written with a thousands comma (1,051).
        let pattern = #/(\d{1,3}(?:,\d{3})*)\s+instructions\s+over\s+(\d+)\s+typed\s+stacks/#
        let statements = text.matches(of: pattern)
        try #require(!statements.isEmpty, "\(document) no longer states the counts; update this test's list")

        let instructions = Runner().definedInstructions.count
        let typedStacks = PushStack.allCases.filter { $0 != .error }.count
        for statement in statements {
            #expect(Int(statement.output.1.filter(\.isNumber)) == instructions,
                    "\(document) says \(statement.output.1) instructions; the language has \(instructions)")
            #expect(Int(statement.output.2) == typedStacks,
                    "\(document) says \(statement.output.2) typed stacks; the language has \(typedStacks)")
        }
    }
}
