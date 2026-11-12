//
//  Output Behavior Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 6/14/26.
//


@testable import Plunge
import Testing
import DequeModule

@Suite
struct OutputBehaviorTests {

    var inty = Interpreter()

    @Test func boolPrint() {
        inty.load(inputs: [:],
                  stacks: [.bool: [BoolItem(false)]],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.boolPrint, to: inty)
        #expect(inty.printout == "false\n")
    }

    @Test func charPrint() {
        inty.load(inputs: [:],
                  stacks: [.char: [CharItem(Character("x"))]],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.charPrint, to: inty)
        #expect(inty.printout == "'x'\n")
    }

    @Test func codePrint() {
        inty.load(inputs: [:],
                  stacks: [.code: [CodeItem([
                    VecStringItem(["foo", "bar"]),
                    DoubleItem(3.14),
                    CodeItem([
                        BoolItem(false),
                        IntItem(1964)
                    ])
                  ])
                  ]],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.codePrint, to: inty)
        #expect(inty.printout == "( [\"foo\", \"bar\"] 3.14 ( false 1964 ) )\n")
    }

    @Test func doublePrint() {
        inty.load(inputs: [:],
                  stacks: [.double: [DoubleItem(3.14)]],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.doublePrint, to: inty)
        #expect(inty.printout == "3.14\n")
    }

    @Test func execPrint() {
        inty.load(inputs: [:],
                  stacks: [.exec: [CharItem(Character("x"))]],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.execPrint, to: inty)
        #expect(inty.printout == "'x'\n")
    }

    @Test func intPrint() {
        inty.load(inputs: [:],
                  stacks: [.int: [IntItem(1964)]],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.intPrint, to: inty)
        #expect(inty.printout == "1964\n")
    }

    @Test func printNewline() {
        inty.load(inputs: [:],
                  stacks: [:],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.printNewline, to: inty)
        #expect(inty.printout == "\n")
    }

    @Test func stringPrint() {
        inty.load(inputs: [:],
                  stacks: [.string: [StringItem("purple")]],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.stringPrint, to: inty)
        #expect(inty.printout == "\"purple\"\n")
    }

    @Test func vecBoolPrint() {
        inty.load(inputs: [:],
                  stacks: [.vecBool: [VecBoolItem([true, true])]],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.vecBoolPrint, to: inty)
        #expect(inty.printout == "[true, true]\n")
    }

    @Test func vecDoublePrint() {
        inty.load(inputs: [:],
                  stacks: [.vecDouble: [VecDoubleItem([98.6, 98.1])]],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.vecDoublePrint, to: inty)
        #expect(inty.printout == "[98.6, 98.1]\n")
    }

    @Test func vecIntPrint() {
        inty.load(inputs: [:],
                  stacks: [.vecInt: [VecIntItem([1066, 32])]],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.vecIntPrint, to: inty)
        #expect(inty.printout == "[1066, 32]\n")
    }

    @Test func vecStringPrint() {
        inty.load(inputs: [:],
                  stacks: [.vecString: [VecStringItem(["foo", "bar"])]],
                  program: [])
        #expect(inty.printout.isEmpty)

        doThis(.vecStringPrint, to: inty)
        #expect(inty.printout == "[\"foo\", \"bar\"]\n")
    }
}
