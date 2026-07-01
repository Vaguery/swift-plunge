//
//  Codable Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/23/26.
//


import DequeModule
import Testing
@testable import PropellerWithStructs

@Suite @MainActor
struct CodableTests {

    @Test(.disabled("until we add Codable conformance to Item")) func `a [any Item] array can be encoded and decoded`() {
        var p = [1, IntItem(2), DoubleItem(3)] as [Any]
        _ = Plushy.plushy2push( p )


    }
}

