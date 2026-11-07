//
//  Containment Tests.swift
//  PushInterpreterTests
//
//  The containment law: an item taken out of a container keeps its own history,
//  and one born inside a container that has a history records its address. See
//  `Containment` and Roadmap §P step 4 (2026-11-07).
//

@testable import PushInterpreter
import Testing

@MainActor @Suite
struct ContainmentTests {

    private let bound: [PushInstruction: any Item] = [.input3: CodeItem([IntItem(5), IntItem(6)])]

    /// Runs `program` on a fresh interpreter, with `.input3` bound to `( 5 6 )`.
    private func run(_ program: [any Item], recording: Bool = true) -> Interpreter {
        let inty = recording ? Interpreter.recordingProvenance() : Interpreter()
        inty.load(inputs: bound, constants: [:], program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    /// Replays `item`'s crux with the same bindings, and checks the claim.
    private func holds(_ item: any Item) -> Bool {
        if case .holds = inspectCrux(of: item, inputs: bound, constants: [:],
                                     settings: Interpreter.recordingProvenance().config) {
            return true
        }
        return false
    }

    @Test func `a bound block's contents record their address, and replay`() {
        let inty = run([InstructionItem(.input3), InstructionItem(.codeDo)])
        #expect(stackString(inty, .int) == "[ 6 5 ]")
        let six = topItem(inty, .int)
        let crux = CodeItem(six.crux()).pretty()
        // The address, then the clean-up every non-destructive read records.
        #expect(crux == "( .input3 1 .codeEmitNthRoot 1 .codePopItems .intSwap .intPop )")
        #expect(holds(six))
        #expect(holds(inty.stacks[.int]![1]))
    }

    @Test func `the address is what the emit instruction records`() {
        let unwrapped = topItem(run([InstructionItem(.input3), InstructionItem(.codeDo)]), .int)
        let emitted = topItem(run([InstructionItem(.input3), IntItem(1), InstructionItem(.codeEmitNthRoot)]), .int)
        #expect(callString(emitted) == callString(unwrapped))
        let walked = run([InstructionItem(.input3), CodeItem([]), InstructionItem(.codeIterateRoot)])
        #expect(callString(topItem(walked, .int)) == callString(unwrapped))
    }

    @Test func `a tree walk addresses by pre-order point`() {
        let inty = run([InstructionItem(.input3), CodeItem([]), InstructionItem(.codeIterateEmitPoints)])
        let six = topItem(inty, .int)
        #expect(six.crux().contains { ($0 as? InstructionItem)?.value == .codeEmitNthPoint })
        #expect(holds(six))
    }

    @Test func `a literal block's contents stay literals of the program`() {
        let inty = run([CodeItem([IntItem(5), IntItem(6)]), InstructionItem(.codeDo)])
        #expect(stackString(inty, .int) == "[ 6 5 ]")
        #expect(topItem(inty, .int).call.isEmpty)
    }

    @Test func `an item that went in with a history comes out with it`() {
        let inty = run([IntItem(2), IntItem(3), InstructionItem(.intAdd),
                        InstructionItem(.intQuote), InstructionItem(.codeDo)])
        #expect(CodeItem(topItem(inty, .int).crux()).pretty() == "( 2 3 .intAdd )")
    }

    @Test func `a block a structural edit rebuilt is addressed when it comes out`() {
        // `( 1 2 3 )` wrapped between gaps 1 and 3 is `( 1 ( 2 3 ) )`; the inner
        // block is new, and has no history of its own.
        let inty = run([CodeItem([IntItem(1), IntItem(2), IntItem(3)]), IntItem(1), IntItem(3),
                        InstructionItem(.codeWrapPoints), InstructionItem(.codeDo)])
        let inner = topItem(inty, .code)
        #expect(inner.pretty() == "( 2 3 )")
        #expect(!inner.call.isEmpty)
        #expect(holds(inner))
    }

    @Test func `with recording off nothing is built`() {
        let inty = run([InstructionItem(.input3), InstructionItem(.codeDo)], recording: false)
        #expect(stackString(inty, .int) == "[ 6 5 ]")
        #expect(inty.stacks[.int]!.allSatisfy { $0.call.isEmpty })
    }
}
