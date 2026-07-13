//
//  Codable Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/23/26.
//


import DequeModule
import Foundation
import Testing
@testable import PushInterpreter

@Suite @MainActor
struct CodableTests {

    @Test func `a [any Item] array can be encoded and decoded`() throws {
        let p = [1, IntItem(2), DoubleItem(3)] as [Any]
        let program = Plushy.plushy2push(p)

        let data = try JSONEncoder().encode(program.map(AnyItem.init))
        let restored = try JSONDecoder().decode([AnyItem].self, from: data).map(\.item)

        #expect(restored == program)
    }
}

