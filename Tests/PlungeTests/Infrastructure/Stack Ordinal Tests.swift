//
//  Stack Ordinal Tests.swift
//  PlungeTests
//
//  Pins what the array-backed stacks and behavior table rely on: a payload-free
//  enum's stored value is its case's position in `allCases`. If a compiler ever
//  changed that, `ordinal` would silently address the wrong slot — so it is
//  checked here for every case, rather than trusted.
//

@testable import Plunge
import Testing
import DequeModule

@Suite
struct StackOrdinalTests {

    @Test func `every stack's ordinal is its position in allCases`() {
        for (position, stack) in PushStack.allCases.enumerated() {
            #expect(stack.ordinal == position, "\(stack)")
        }
    }

    @Test func `every instruction's ordinal is its position in allCases`() {
        let mismatches = PushInstruction.allCases.enumerated().filter { $1.ordinal != $0 }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(5).map(\.element))")
    }

    /// Interpolation reads the description; it must stay the case name, which is
    /// what every message and crux rendering printed before the enums had one.
    @Test func `descriptions are the raw values`() {
        #expect(PushStack.allCases.allSatisfy { "\($0)" == $0.rawValue })
        #expect(PushInstruction.allCases.allSatisfy { "\($0)" == $0.rawValue })
    }

    @Test func `the stack set has one independent slot per stack`() {
        var stacks = StackSet()
        #expect(stacks.keys == PushStack.allCases)
        for (position, stack) in PushStack.allCases.enumerated() {
            stacks[stack]!.prepend(IntItem(position))
        }
        for (position, stack) in PushStack.allCases.enumerated() {
            #expect(stacks[stack]!.count == 1)
            #expect((stacks[stack]!.first as? IntItem)?.value == position)
        }
    }

    @Test func `the behavior table agrees with the language for every instruction`() {
        let table = Interpreter.languageTable
        for instruction in PushInstruction.allCases {
            #expect(table[instruction] === Interpreter.language[instruction], "\(instruction)")
        }
    }

    @Test func `a table built with disabled instructions leaves exactly those out`() {
        let table = BehaviorTable(Interpreter.language, disabling: [.intAdd, .stringConcat])
        #expect(table[.intAdd] == nil)
        #expect(table[.stringConcat] == nil)
        #expect(table[.intSubtract] === Interpreter.language[.intSubtract])
    }

    /// Looked up once at launch now; each must be the instruction named for it.
    /// The channels, `.error` and `.print`, have none: nothing may pop them.
    @Test func `per-stack cleanup instructions are named for their stack`() {
        for stack in PushStack.allCases where !stack.isChannel {
            #expect(stack.popItemsInstruction.rawValue == "\(stack.rawValue)PopItems")
            #expect(stack.swapInstruction.rawValue == "\(stack.rawValue)Swap")
            #expect(stack.popInstruction.rawValue == "\(stack.rawValue)Pop")
        }
    }

    /// The lazily-rendered refusal reads exactly as the eager one did.
    @Test func `a missing-arguments error renders the familiar message`() {
        let error = ErrorItem(missingArgumentsFor: .intAdd, on: .int)
        #expect(error.value == "intAdd missing args: .int")
        #expect(error.kind == .missingArgument)
        #expect(error == ErrorItem("intAdd missing args: .int"))
    }
}
