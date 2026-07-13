//
//  AnyItem Codable Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/13/26.
//

import Foundation
@testable import PushInterpreter
import Testing

@Suite
struct AnyItemCodableTests {

    private func roundTrip(_ item: any Item) throws -> any Item {
        let data = try JSONEncoder().encode(AnyItem(item))
        return try JSONDecoder().decode(AnyItem.self, from: data).item
    }

    // Every scalar and vector leaf type survives a JSON round-trip by value.
    @Test func `scalar and vector leaves round-trip by value`() throws {
        let leaves: [any Item] = [
            BoolItem(true),
            CharItem("z"),
            DoubleItem(3.5),
            InstructionItem(.intAdd),
            IntItem(-42),
            StringItem("hello"),
            VecBoolItem([true, false, true]),
            VecDoubleItem([1.0, 2.5]),
            VecIntItem([1, 2, 3]),
            VecStringItem(["a", "b"]),
            ErrorItem("boom"),
        ]
        for leaf in leaves {
            #expect(try roundTrip(leaf).isEqual(to: leaf))
        }
    }

    // A nested CodeItem (code is "just text too") round-trips recursively.
    @Test func `nested CodeItem round-trips recursively`() throws {
        let program = CodeItem([
            IntItem(1),
            InstructionItem(.intAdd),
            CodeItem([StringItem("x"), InstructionItem(.stringConcat)]),
        ])
        #expect(try roundTrip(program).isEqual(to: program))
    }

    // A whole program ([any Item]) transports as [AnyItem].
    @Test func `a program array transports as [AnyItem]`() throws {
        let program: [any Item] = [
            InstructionItem(.input0),
            IntItem(7),
            InstructionItem(.intAdd),
        ]
        let data = try JSONEncoder().encode(program.map(AnyItem.init))
        let restored = try JSONDecoder().decode([AnyItem].self, from: data).map(\.item)
        #expect(restored == program)
    }

    // Runtime-only fields are not serialized; they come back at their defaults.
    @Test func `runtime fields are dropped and reset to defaults on decode`() throws {
        let dirty = IntItem(
            5,
            call: [InstructionItem(.intAdd), IntItem(2)],
            isContingent: true,
            index: 3
        )
        let restored = try roundTrip(dirty)
        #expect((restored as? IntItem)?.value == 5)
        #expect(restored.call.isEmpty)
        #expect(restored.isContingent == false)
        #expect(restored.index == 0)
    }

    // A crux result — a flattened bag of pristine value items — is Codable-ready.
    @Test func `a crux result round-trips`() throws {
        let leaf = IntItem(9)
        let derived = IntItem(
            11,
            call: [InstructionItem(.intAdd), leaf, IntItem(2)]
        )
        let crux = derived.crux()
        let data = try JSONEncoder().encode(crux.map(AnyItem.init))
        let restored = try JSONDecoder().decode([AnyItem].self, from: data).map(\.item)
        #expect(restored == crux)
    }

    // The type tag is stable and human-readable in the JSON.
    @Test func `encoding uses a readable type tag`() throws {
        let data = try JSONEncoder().encode(AnyItem(IntItem(1)))
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"type\""))
        #expect(json.contains("\"int\""))
    }
}
