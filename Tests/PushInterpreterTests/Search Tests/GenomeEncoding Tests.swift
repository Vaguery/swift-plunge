//
//  GenomeEncoding Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/13/26.
//

import Foundation
@testable import PushInterpreter
import Testing

@Suite
struct GenomeEncodingTests {

    @Test func `plushy encoding dispatches to Plushy translation`() {
        let genome: [Any] = [1, IntItem(2), InstructionItem(.intAdd)]
        #expect(GenomeEncoding.plushy.translate(genome) == Plushy.plushy2push(genome))
    }

    @Test func `encoding is Codable by name`() throws {
        for encoding in GenomeEncoding.allCases {
            let data = try JSONEncoder().encode(encoding)
            let restored = try JSONDecoder().decode(GenomeEncoding.self, from: data)
            #expect(restored == encoding)
        }
    }
}
