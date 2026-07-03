//
//  Plushy Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/23/26.
//


import DequeModule
import Testing
@testable import PropellerWithStructs

@Suite @MainActor
struct PlushyTests {

    @Test func `plushy works for explicit items`() {
        let p = [1, IntItem(2), DoubleItem(3)] as [Any]
        let prog = Plushy.plushy2push( p )

        #expect(prog[0] is IntItem)
        #expect(prog[1] is IntItem)
        #expect(prog[2] is DoubleItem)
    }

    @Test func `plushy works for code and plushy controls`() {
        let p = [CodeItem([IntItem(7), BoolItem(false)]), PlushyControl.open, DoubleItem(1.23)] as [Any]
        let prog = Plushy.plushy2push( p )

        #expect(prog.count == 2)
        #expect(CodeItem(prog).pretty() == "( ( 7 false ) ( 1.23 ) )")
    }

    @Test func `plushy works for instructions in both forms`() {
        let p = [PushInstruction.intAdd, InstructionItem(.boolNand), PushInstruction.execDoCount, DoubleItem(1.23)] as [Any]
        let prog = Plushy.plushy2push( p )

        #expect(prog.count == 4)
        #expect(CodeItem(prog).pretty() == "( .intAdd .boolNand .execDoCount ( 1.23 ) )")
        #expect(prog[0] is InstructionItem)
        #expect(prog[1] is InstructionItem)
        #expect(prog[2] is InstructionItem)
        #expect(prog[3] is CodeItem)
    }

    @Test func `plushy inserts blocks after InstructionItems from the list`() {
        let p = [
            InstructionItem(.execDup),
            StringItem("explicit"),
            PlushyControl.close,
            PushInstruction.execDup,
            StringItem("implicit"),
        ] as [Any]

        let prog = Plushy.plushy2push( p )

        #expect(prog.count == 4)
        #expect(CodeItem(prog).pretty() == "( .execDup ( \"explicit\" ) .execDup ( \"implicit\" ) )")
        #expect(prog[0] is InstructionItem)
        #expect(prog[1] is CodeItem)
        #expect(prog[2] is InstructionItem)
        #expect(prog[3] is CodeItem)
    }



    @Test func `plushy can recognize nested Code items from [Any] arrays`() {
        let p = [
            1, false, [ 2, [false, 3] ]
        ] as [Any]

        let prog = Plushy.plushy2push( p )

        #expect(prog.count == 3)
        #expect(CodeItem(prog).pretty() == "( 1 false ( 2 ( false 3 ) ) )")
        #expect(prog[0] is IntItem)
        #expect(prog[1] is BoolItem)
        #expect(prog[2] is CodeItem)
    }

}

