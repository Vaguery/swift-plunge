//
//  Crux Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 6/23/26.
//


import DequeModule
import Testing
@testable import Plunge

@Suite @MainActor
struct CruxTests {

    func stackString(_ interpreter: Interpreter, _ stack: PushStack) -> String {
        var result = "["
        let s = interpreter.stacks[stack]!
        for item in s {
            result += " \(item.pretty() )"
        }
        result += " ]"
        return result
    }

    func topItem(_ interpreter: Interpreter, _ stack: PushStack) -> any Item {
        interpreter.stacks[stack]!.first!
    }

    func doThis(_ instruction: PushInstruction, to interpreter: Interpreter) {
        Interpreter.language[instruction]!.act(on: interpreter)
    }

    var inty = Interpreter.recordingProvenance()

    @Test func `crux can be constructed`() {
        let tokens = [1, 2, PushInstruction.intAdd, 3, 4, PushInstruction.intMultiply, PushInstruction.intSubtract] as [Any]
        let program = buildProgram(tokens)
        inty.load(program: program)
        inty.run()

        #expect(stackString(inty, .int) == "[ -9 ]")
        let answer = (topItem(inty, .int) as! IntItem)
        #expect(CodeItem(answer.crux()).pretty() == "( 1 2 .intAdd 3 4 .intMultiply .intSubtract )")
        #expect(answer.crux().compactMap({$0}) == answer.crux())
    }

    @Test func `crux can work on a flat tree`() {
        let tree1 = IntItem(1,
                           call: [
                            IntItem(1),
                            IntItem(2),
                            CodeItem([
                                IntItem(3),
                                IntItem(4)
                            ]),
                            IntItem(5)
                            ])


        #expect(CodeItem(tree1.crux()).pretty() == "( 1 2 ( 3 4 ) 5 )")
        #expect(tree1.crux().count == 4 )
    }

    @Test func `crux can work on a nested tree with CodeItems`() {
        let treeProg = [
            1,
            11,
            PushInstruction.intAdd,
            3,
            33,
            PushInstruction.intMultiply,
            PushInstruction.intQuote,
            PushInstruction.intQuote,
            PushInstruction.codeConcat
        ] as [Any]
        let prog2 = buildProgram(treeProg)
        let tree = CodeItem(prog2)
        #expect(CodeItem(tree.crux()).pretty() == "( ( 1 11 .intAdd 3 33 .intMultiply .intQuote .intQuote .codeConcat ) )")

        inty.load(program: prog2)
        inty.run()
        #expect(stackString(inty, .code) == "[ ( 99 12 ) ]")

        let answer1 = (topItem(inty, .code) as! CodeItem)
        #expect(CodeItem(answer1.crux()).pretty() == "( 3 33 .intMultiply .intQuote 1 11 .intAdd .intQuote .codeConcat )")

        inty.load(program: answer1.crux())
        inty.run()
        #expect(stackString(inty, .code) == "[ ( 99 12 ) ]")
        let answer2 = (topItem(inty, .code) as! CodeItem)
        #expect(CodeItem(answer2.crux()).pretty() == CodeItem(answer1.crux()).pretty()  )

    }

    @Test
    func `crux can work through conditional code`() {
        // Built directly rather than through a bracketing builder. `execIf` takes
        // its branches from `.code` now, so they have to reach it before the
        // instruction fires. (The old Plushy `extraOpens` emitted the opposite
        // shape — blocks immediately *after* `.execIf`, where `.code` was still
        // empty — which is exactly why it was retired.) The source order is written
        // out here instead. Only the order moves: every expectation below is the
        // one this test has always made, including the crux text.
        let prog2: [any Item] = [
            CodeItem([IntItem(1), IntItem(11), InstructionItem(.intAdd)]),
            CodeItem([IntItem(2), IntItem(22), InstructionItem(.intSubtract)]),
            BoolItem(false),
            InstructionItem(.execIf),
            IntItem(3), IntItem(33), InstructionItem(.intMultiply),
            InstructionItem(.intQuote),
            InstructionItem(.intQuote),
            InstructionItem(.codeConcat)
        ]
        #expect(CodeItem(prog2).pretty() == "( ( 1 11 .intAdd ) ( 2 22 .intSubtract ) false .execIf 3 33 .intMultiply .intQuote .intQuote .codeConcat )")

        inty.load(program: prog2)
        inty.run()
        #expect(stackString(inty, .code) == "[ ( 99 -20 ) ]")

        let answer1 = (topItem(inty, .code) as! CodeItem)
        #expect(CodeItem(answer1.crux()).pretty() == "( 3 33 .intMultiply .intQuote 2 22 .intSubtract .intQuote .codeConcat )")

        inty.load(program: answer1.crux())
        inty.run()
        #expect(stackString(inty, .code) == "[ ( 99 -20 ) ]")
        let answer2 = (topItem(inty, .code) as! CodeItem)
        #expect(CodeItem(answer2.crux()).pretty() == CodeItem(answer1.crux()).pretty()  )

    }
}
