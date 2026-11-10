//
//  PushStack Type Tests.swift
//  PlungeTests
//
//  Tests for the PushStack type-acceptance predicate (Proposal A, Piece 1).
//  These pin down the homogeneity invariant that the Behaviors' force-casts
//  rely on: .exec is the only heterogeneous stack; every other stack (including
//  .error, which holds only ErrorItem) accepts a single Item type.
//

@testable import Plunge
import Testing
import DequeModule

@Suite @MainActor
struct PushStackTypeTests {

    /// One representative Item per homogeneous stack, paired with its home stack.
    static let homogeneousSamples: [(item: any Item, home: PushStack)] = [
        (BoolItem(true), .bool),
        (IntItem(1), .int),
        (DoubleItem(1.0), .double),
        (CharItem(Character("a")), .char),
        (StringItem("x"), .string),
        (CodeItem([]), .code),
        (VecBoolItem([]), .vecBool),
        (VecIntItem([]), .vecInt),
        (VecDoubleItem([]), .vecDouble),
        (VecStringItem([]), .vecString),
        (IteratorItem(
            kind: .counting(stride: 1),
            origin: IntItem(0),
            destination: IntItem(3),
            body: CodeItem([]),
            emits: true
        ), .iterator),
        (ErrorItem("boom"), .error)
    ]

    /// Items that only ever live on the heterogeneous `.exec` stack.
    static let execOnlySamples: [any Item] = [
        InstructionItem(.intAdd)
    ]

    // MARK: isHeterogeneous

    @Test func `exec is the only heterogeneous stack`() {
        for stack in PushStack.allCases {
            #expect(stack.isHeterogeneous == (stack == .exec))
        }
    }

    // MARK: homogeneous stacks accept their own type

    @Test func `each homogeneous stack accepts its own item type`() {
        for (item, home) in Self.homogeneousSamples {
            #expect(home.accepts(item),
                    "\(home) should accept \(type(of: item))")
        }
    }

    // MARK: homogeneous stacks reject every other type

    @Test func `each homogeneous stack rejects every foreign item type`() {
        for (item, home) in Self.homogeneousSamples {
            for stack in PushStack.allCases where !stack.isHeterogeneous && stack != home {
                #expect(!stack.accepts(item),
                        "\(stack) must reject \(type(of: item))")
            }
        }
    }

    // MARK: .error is strictly ErrorItem

    @Test func `error accepts only ErrorItem`() {
        #expect(PushStack.error.accepts(ErrorItem("boom")))
        // a plain literal must not be allowed to masquerade as an error
        #expect(!PushStack.error.accepts(IntItem(1)))
        #expect(!PushStack.error.accepts(InstructionItem(.intAdd)))
    }

    // MARK: exec accepts everything

    @Test func `exec accepts every item type`() {
        let everything = Self.homogeneousSamples.map(\.item) + Self.execOnlySamples
        for item in everything {
            #expect(PushStack.exec.accepts(item))
        }
    }

    // MARK: instruction items belong only on exec

    @Test func `instruction items are rejected by every non-exec stack`() {
        for item in Self.execOnlySamples {
            for stack in PushStack.allCases where stack != .exec {
                #expect(!stack.accepts(item),
                        "\(stack) must reject \(type(of: item))")
            }
        }
    }
}
