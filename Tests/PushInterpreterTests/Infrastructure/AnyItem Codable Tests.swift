//
//  AnyItem Codable Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/13/26.
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

    /// The one item whose envelope `value` is a structure rather than a scalar:
    /// an iterator's `value` is only its cursor, but what it *is* is the whole
    /// loop. All of that is value content, not history, so the envelope carries it
    /// without breaking its own rule against serializing provenance.
    @Test func `an iterator round-trips its whole state`() throws {
        let iterator = IteratorItem(
            kind: .counting(stride: -3),
            origin: IntItem(40),
            destination: IntItem(4),
            body: CodeItem([IntItem(1), InstructionItem(.intAdd)]),
            emits: true,
            cursor: 7
        )
        let back = try roundTrip(iterator) as? IteratorItem
        #expect(back?.isEqual(to: iterator) == true)
        #expect(back?.value == 7)
        #expect(back?.kind == .counting(stride: -3))
        #expect(back?.emits == true)
        #expect((back?.destination as? IntItem)?.value == 4)
    }

    /// A collection iterator has no end bound of its own, and a sequence has no
    /// body. Both optionals have to survive as nil rather than becoming something
    /// else — and an empty body must come back as *no* body, since `init`
    /// normalizes the two together.
    @Test func `an iterator with no destination and no body round-trips`() throws {
        let iterator = IteratorItem(
            kind: .elements(into: nil),
            origin: VecBoolItem([true, false]),
            body: CodeItem([]),
            emits: true
        )
        let back = try roundTrip(iterator) as? IteratorItem
        #expect(back?.isEqual(to: iterator) == true)
        #expect(back?.destination == nil)
        #expect(back?.body == nil)
    }

    /// Burial is state — two iterators identical but for where they hide their
    /// next copy are different iterators, and behave differently.
    @Test func `an iterator's burial depth round-trips`() throws {
        let iterator = IteratorItem(
            kind: .elements(into: .exec),
            origin: CodeItem([IntItem(1), InstructionItem(.intAdd)]),
            body: CodeItem([BoolItem(true)]),
            emits: true,
            cursor: 1,
            burial: 4
        )
        let back = try roundTrip(iterator) as? IteratorItem
        #expect(back?.burial == 4)
        #expect(back?.kind == .elements(into: .exec))
        #expect(back?.isEqual(to: iterator) == true)
    }

    /// Provenance is dropped, as it is for every other item — the envelope's
    /// contract. The iterator's *state* is not provenance and must survive.
    @Test func `an iterator's provenance is dropped but its state is not`() throws {
        var iterator = IteratorItem(
            kind: .counting(stride: 1),
            origin: IntItem(0),
            destination: IntItem(9),
            body: CodeItem([]),
            emits: false,
            cursor: 3
        )
        iterator.call = iterator.reconstruction()
        #expect(!iterator.call.isEmpty)

        let back = try roundTrip(iterator) as? IteratorItem
        #expect(back?.call.isEmpty == true)
        #expect(back?.value == 3)
        #expect(back?.isEqual(to: iterator) == true)   // equality is about values
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
            call: [InstructionItem(.intAdd), IntItem(2)])
        let restored = try roundTrip(dirty)
        #expect((restored as? IntItem)?.value == 5)
        #expect(restored.call.isEmpty)
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
