//
//  RecorderSpec Codable Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 7/13/26.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct RecorderSpecCodableTests {

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // Exercise every target shape: item-valued (with and without an index),
    // scalar-per-stack, and the stack-free scalars.
    @Test(arguments: [
        RecorderTarget.top(.int),
        RecorderTarget.second(.vecDouble),
        RecorderTarget.second(.string),
        RecorderTarget.nth(.int, depth: 3),
        RecorderTarget.count(.error),
        RecorderTarget.isEmpty(.exec),
        RecorderTarget.stack(.print),
        RecorderTarget.counter
    ])
    func `every RecorderTarget round-trips through JSON`(target: RecorderTarget) throws {
        #expect(try roundTrip(target) == target)
    }

    @Test func `a RecorderSpec round-trips through JSON`() throws {
        let spec = RecorderSpec("errCount", observing: .count(.error))
        let restored = try roundTrip(spec)
        #expect(restored == spec)
        #expect(restored.name == "errCount")
        #expect(restored.target == .count(.error))
    }

    @Test func `a batch of specs round-trips as an array`() throws {
        let specs = [
            RecorderSpec("topInt", observing: .top(.int)),
            RecorderSpec("count", observing: .count(.int)),
            RecorderSpec("out", observing: .stack(.print))
        ]
        #expect(try roundTrip(specs) == specs)
    }

    @Test func `PushStack round-trips through JSON`() throws {
        for stack in PushStack.allCases {
            #expect(try roundTrip(stack) == stack)
        }
    }
}
