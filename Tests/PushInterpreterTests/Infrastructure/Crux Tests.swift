//
//  Crux Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/23/26.
//


import DequeModule
import Testing
@testable import PropellerWithStructs

@Suite @MainActor
struct CruxTests {

    func stackString(_ interpreter:Interpreter, _ stack:PushStack) -> String {
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

    func doThis(_ instruction:PushInstruction, to interpreter: Interpreter) {
        Interpreter.language[instruction]!.act(on: interpreter)
    }

    var inty = Interpreter()

    @Test func `crux can be constructed`() {
        let plushy = [1, 2, PushInstruction.intAdd, 3, 4, PushInstruction.intMultiply, PushInstruction.intSubtract] as [Any]
        let program = Plushy.plushy2push(plushy)
        inty.load(program: program)
        inty.run()

        #expect(stackString(inty, .int) == "[ -9 ]")
        let answer = (topItem(inty, .int) as! IntItem)
        #expect(CodeItem(answer.crux()).pretty() == "( 1 2 .intAdd 3 4 .intMultiply .intSubtract )")
        #expect(answer.crux().compactMap({$0}) == answer.crux())
    }

    @Test func `crux can work on a flat tree`() {
        let tree1 = IntItem(1,
                           call:[
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
            PushInstruction.codeAppend,
        ] as [Any]
        let prog2 = Plushy.plushy2push(treeProg)
        let tree = CodeItem(prog2)
        #expect(CodeItem(tree.crux()).pretty() == "( ( 1 11 .intAdd 3 33 .intMultiply .intQuote .intQuote .codeAppend ) )")

        inty.load(program:prog2)
        inty.run()
        #expect(stackString(inty, .code) == "[ ( 99 12 ) ]")

        let answer1 = (topItem(inty, .code) as! CodeItem)
        #expect(CodeItem(answer1.crux()).pretty() == "( 3 33 .intMultiply .intQuote 1 11 .intAdd .intQuote .codeAppend )")

        inty.load(program:answer1.crux())
        inty.run()
        #expect(stackString(inty, .code) == "[ ( 99 12 ) ]")
        let answer2 = (topItem(inty, .code) as! CodeItem)
        #expect(CodeItem(answer2.crux()).pretty() == CodeItem(answer1.crux()).pretty()  )

    }

    @Test(.disabled("waiting for bug fix in code block handling in crux->push"))
    func `crux can work through contingent code`() {
        let treeProg = [
            false,
            PushInstruction.execIf,
            1,
            11,
            PushInstruction.intAdd,
            PlushyControl.close,
            2,
            22,
            PushInstruction.intSubtract,
            PlushyControl.close,
            3,
            33,
            PushInstruction.intMultiply,
            PushInstruction.intQuote,
            PushInstruction.intQuote,
            PushInstruction.codeAppend,
        ] as [Any]
        let prog2 = Plushy.plushy2push(treeProg)
        #expect(CodeItem(prog2).pretty() == "( false .execIf ( 1 11 .intAdd ) ( 2 22 .intSubtract ) 3 33 .intMultiply .intQuote .intQuote .codeAppend )")

        inty.load(program:prog2)
        inty.run()
        #expect(stackString(inty, .code) == "[ ( 99 -20 ) ]")

        let answer1 = (topItem(inty, .code) as! CodeItem)
        #expect(CodeItem(answer1.crux()).pretty() == "( 3 33 .intMultiply .intQuote .execIf ( 1 11 .intAdd ) ( 2 22 .intSubtract ) 22 .intSubtract .intQuote .codeAppend )")

//        inty.load(program:answer1.crux())
//        inty.run()
//        #expect(stackString(inty, .code) == "[ ( 99 -20 ) ]")
//        let answer2 = (topItem(inty, .code) as! CodeItem)
//        #expect(CodeItem(answer2.crux()).pretty() == CodeItem(answer1.crux()).pretty()  )

    }
}

