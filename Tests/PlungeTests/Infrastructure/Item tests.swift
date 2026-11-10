//
//  Item tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 5/30/26.
//

import DequeModule
@testable import PushInterpreter
import Testing


@Suite @MainActor
struct Item_tests {


    @Test func errorTest() {
        let e = ErrorItem("a bad thing")
        #expect(e.value == "a bad thing")
    }

    @Test func equality() {
        #expect(IntItem(1) == IntItem(1))
        #expect(IntItem(1) != IntItem(2))
    }

    @Test func anItemCanBeChanged() {
        var foo = StringItem("foo")
        #expect(foo.call.isEmpty)
        #expect( type(of: foo.call) == Array<any Item>.self)
        let newHistory = [InstructionItem(.input2)]
        foo.call = newHistory
    }
}

@Suite @MainActor
struct History_tests {

    var inty = Interpreter.recordingProvenance()


//    @Test func extractingEntireCrux() {
//        var littleGenome:[Any] = [
//            1,
//            PlushyControl.open, 2, 3, PlushyControl.close, //  code
//            PushInstruction.intAdd,
//            PlushyControl.open, 4, InstructionItem(.input0),PlushyControl.close, // code
//            PushInstruction.intSubtract,
//            PushInstruction.intMultiply,
//            PushInstruction.input1,
//            PushInstruction.intSubtract
//        ]
//
//        let littleProgram = Plushy.plushy2push(&littleGenome)
//        #expect(CodeItem(littleProgram).pretty() == "( 1 ( 2 3 ) .intAdd ( 4 ) .intSubtract .intMultiply .input1 .intSubtract )")
//
//        inty.load(inputs:[.input0:IntItem(99), .input1:IntItem(777)], program: littleProgram)
//        inty.run(stepLimit: 100)
//        #expect(stackString(inty, .int) == "[ -776 ]")
//
//        let answer = topItem(inty, .int)
//
//        #expect(CodeItem(answer.call).pretty() == "( 1 777 .intSubtract )")
//        #expect(answer.crux() == [])
//
//    }
}


@MainActor
struct Code_tests {

    @Test
    func `code calls create items`() {
        let stuff: [any Item] = [IntItem(34), DoubleItem(1.2)]
        let codey1 = CodeItem( stuff )
        let codey2 = CodeItem( stuff )

        #expect(codey1.value.count == 2)
        #expect(codey2.value.count == 2)
        #expect(codey1.value == codey2.value)
        #expect(codey1 == codey2)
    }


}
