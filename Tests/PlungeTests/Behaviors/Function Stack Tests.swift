//
//  Function Stack Tests.swift
//  PlungeTests
//
//  The `.function` stack's two sources, and the function item itself:
//  - starvation shelves the starved instruction, bare, as a function;
//  - `codePushAllFunctions` converts a block into the functions its pushes
//    compute, a hole for every missing argument;
//  - a function is data: it routes to `.function` and encodes as itself.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct FunctionStackTests {

    static func run(_ program: [any Item], stepLimit: Int = 10_000) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: program)
        inty.run(stepLimit: stepLimit)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    // MARK: - Starvation

    @Test func `a starved instruction is shelved bare, beside its error`() {
        let inty = Self.run([IntItem(4), Self.op(.intAdd)])
        #expect(stackString(inty, .int) == "[ 4 ]", "the argument it found is not taken")
        #expect(stackString(inty, .function) == "[ ƒ( ⟨int⟩ ⟨int⟩ .intAdd ) ]", "nor bound into the function")
        #expect((inty.stacks[.error]!.first as? ErrorItem)?.kind == .missingArgument)
    }

    @Test func `combinators are shelved too`() {
        let inty = Self.run([Self.op(.intDup)])
        #expect(stackString(inty, .function) == "[ ƒ( ⟨int⟩ .intDup ) ]")
        let bare = inty.stacks[.function]!.first?.exactly(FunctionItem.self)
        #expect(bare?.isBare == true && bare?.output == .int)
    }

    @Test func `misses and unbound inputs are not starvation`() {
        let inty = Self.run([Self.op(.input3), IntItem(42), Self.op(.bindingDeref)])
        #expect(inty.stacks[.function]!.isEmpty)
        let kinds = inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.kind }
        #expect(Set(kinds) == [.missingInput, .notFound])
    }

    // MARK: - codePushAllFunctions

    @Test func `a block yields its functions in the order made`() {
        let inty = Self.run([CodeItem([IntItem(2), Self.op(.intAdd), Self.op(.intMultiply)]),
                             Self.op(.codePushAllFunctions)])
        #expect(stackString(inty, .function)
                == "[ ƒ( ⟨int⟩ ⟨int⟩ 2 .intAdd .intMultiply ) ƒ( ⟨int⟩ 2 .intAdd ) ]")
        #expect(inty.stacks[.code]!.isEmpty, "the block is consumed")
        #expect(inty.stacks[.error]!.isEmpty)
    }

    @Test func `one hole can fill several places`() {
        let inty = Self.run([CodeItem([Self.op(.intDup), Self.op(.intMultiply)]), Self.op(.codePushAllFunctions),
                             VecIntItem([1, 2, 3]), Self.op(.vecIntMap)])
        #expect(stackString(inty, .vecInt) == "[ [1, 4, 9] ]", "x .intDup .intMultiply squares its one argument")
    }

    @Test func `a block that only rearranges yields nothing`() {
        let inty = Self.run([CodeItem([Self.op(.intSwap)]), Self.op(.codePushAllFunctions)])
        #expect(inty.stacks[.function]!.isEmpty && inty.stacks[.error]!.isEmpty)
    }

    @Test func `errors inside the derivation stay there`() {
        // The placeholder divided by zero refuses, in the sandbox.
        let inty = Self.run([CodeItem([IntItem(0), Self.op(.intQuot)]), Self.op(.codePushAllFunctions)])
        #expect(inty.stacks[.error]!.isEmpty)
    }

    @Test func `a block that runs too long yields nothing and one error`() {
        let loop = CodeItem([IntItem(1_000_000), CodeItem([IntItem(1)]), Self.op(.execDoTimes)])
        let inty = Self.run([loop, Self.op(.codePushAllFunctions)])
        #expect(inty.stacks[.function]!.isEmpty)
        #expect(inty.stacks[.error]!.count == 1)
        #expect(inty.stacks[.code]!.isEmpty, "the block is still consumed")
    }

    @Test func `a repeated block costs its derivation once`() {
        let block = CodeItem([IntItem(2), Self.op(.intAdd), Self.op(.intMultiply)])
        let once = Self.run([block, Self.op(.codePushAllFunctions)])
        let twice = Self.run([block, Self.op(.codePushAllFunctions), block, Self.op(.codePushAllFunctions)])
        #expect(twice.counter == once.counter + 2, "the second copy costs only its own two steps")
        #expect(twice.stacks[.function]!.count == 2 * once.stacks[.function]!.count)
    }

    @Test func `derivations nested past the sandbox limit are refused, not a crash`() {
        var block: [any Item] = [IntItem(2), Self.op(.intAdd)]
        for _ in 0..<300 { block = [CodeItem(block), Self.op(.codePushAllFunctions)] }
        let inty = Self.run([CodeItem(block), Self.op(.codePushAllFunctions)])
        #expect(inty.stacks[.exec]!.isEmpty, "the run finished")
    }

    // MARK: - The item

    @Test func `a function on exec comes to rest on the function stack`() {
        let function = FunctionItem(bare: Self.op(.intAdd))
        let inty = Self.run([function])
        #expect(stackString(inty, .function) == "[ ƒ( ⟨int⟩ ⟨int⟩ .intAdd ) ]")
    }

    @Test func `functions encode and decode as themselves`() throws {
        let derived = FunctionItem(body: [IntItem(2), Self.op(.intAdd)],
                                   holes: [FunctionItem.Hole(stack: .int, positions: [0])], output: .int)
        for function in [FunctionItem(bare: Self.op(.intSwap)), derived] {
            let data = try JSONEncoder().encode(AnyItem(function))
            let back = try JSONDecoder().decode(AnyItem.self, from: data).item
            #expect(back.isEqual(to: function), "\(function.pretty()) did not survive coding")
        }
    }

    @Test func `filling puts each filler at all of its hole's places`() {
        let function = FunctionItem(body: [Self.op(.intMultiply)],
                                    holes: [FunctionItem.Hole(stack: .int, positions: [0, 0])], output: .int)
        #expect(CodeItem(function.filled(with: [IntItem(7)])).pretty() == "( 7 7 .intMultiply )")
    }
}
