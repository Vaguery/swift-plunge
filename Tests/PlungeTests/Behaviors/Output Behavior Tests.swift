//
//  Output Behavior Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 6/14/26.
//
//  Printing moves an item onto `.print` (since 2026-11-13; until then it appended
//  the item's text and a newline to a printout string). These check that the item
//  itself arrives there, unchanged, and leaves the stack it came from.
//


@testable import Plunge
import Testing
import DequeModule

@Suite
struct OutputBehaviorTests {

    var inty = Interpreter()

    /// `.print`'s items, top first, as `pretty()` shows them.
    var printed: [String] { inty.stacks[.print]!.map { $0.pretty() } }

    /// Loads one item on `stack`, prints it with `instruction`, and checks it moved.
    mutating func printsAndMoves(_ item: any Item, from stack: PushStack, with instruction: PushInstruction) {
        inty.load(inputs: [:], stacks: [stack: [item]], program: [])
        #expect(printed.isEmpty)

        doThis(instruction, to: inty)
        #expect(inty.stacks[.print]!.count == 1)
        #expect(inty.stacks[.print]!.first?.isEqual(to: item) == true, "the item itself is printed, not its text")
        #expect(inty.stacks[stack]!.isEmpty, "\(instruction) moves its item")
        #expect(inty.stacks[.error]!.isEmpty)
    }

    @Test mutating func boolPrint() {
        printsAndMoves(BoolItem(false), from: .bool, with: .boolPrint)
        #expect(printed == ["false"])
    }

    @Test mutating func charPrint() {
        printsAndMoves(CharItem(Character("x")), from: .char, with: .charPrint)
    }

    @Test mutating func codePrint() {
        printsAndMoves(CodeItem([VecStringItem(["foo", "bar"]), DoubleItem(3.14),
                                 CodeItem([BoolItem(false), IntItem(1964)])]),
                       from: .code, with: .codePrint)
        #expect(printed == ["( [\"foo\", \"bar\"] 3.14 ( false 1964 ) )"])
    }

    @Test mutating func doublePrint() {
        printsAndMoves(DoubleItem(3.14), from: .double, with: .doublePrint)
    }

    @Test mutating func intPrint() {
        printsAndMoves(IntItem(1964), from: .int, with: .intPrint)
        #expect(printed == ["1964"])
    }

    @Test mutating func stringPrint() {
        printsAndMoves(StringItem("purple"), from: .string, with: .stringPrint)
    }

    @Test mutating func vecBoolPrint() {
        printsAndMoves(VecBoolItem([true, true]), from: .vecBool, with: .vecBoolPrint)
    }

    @Test mutating func vecDoublePrint() {
        printsAndMoves(VecDoubleItem([98.6, 98.1]), from: .vecDouble, with: .vecDoublePrint)
    }

    @Test mutating func vecIntPrint() {
        printsAndMoves(VecIntItem([1066, 32]), from: .vecInt, with: .vecIntPrint)
    }

    @Test mutating func vecStringPrint() {
        printsAndMoves(VecStringItem(["foo", "bar"]), from: .vecString, with: .vecStringPrint)
    }

    @Test mutating func bindingPrint() {
        printsAndMoves(BindingItem(key: 3, bound: StringItem("x")), from: .binding, with: .bindingPrint)
    }

    @Test mutating func functionPrint() {
        printsAndMoves(FunctionItem(bare: InstructionItem(.intAdd)), from: .function, with: .functionPrint)
    }

    @Test mutating func `iteratorPrint prints a copy and leaves the loop`() {
        let loop = IteratorItem(kind: .counting(stride: 1), origin: IntItem(0), destination: IntItem(3),
                                body: CodeItem([]), emits: true)
        inty.load(inputs: [:], stacks: [.iterator: [loop]], program: [])
        doThis(.iteratorPrint, to: inty)
        #expect(inty.stacks[.print]!.first?.isEqual(to: loop) == true)
        #expect(inty.stacks[.iterator]!.count == 1, "the loop keeps running")
    }

    @Test mutating func `prints accumulate, latest on top`() {
        inty.load(inputs: [:], stacks: [.int: [IntItem(1), IntItem(2)], .string: [StringItem("a")]], program: [])
        doThis(.intPrint, to: inty)
        doThis(.stringPrint, to: inty)
        doThis(.intPrint, to: inty)
        #expect(printed == ["2", "\"a\"", "1"])
    }

    @Test mutating func `printing from an empty stack starves, like any instruction`() {
        inty.load(inputs: [:], stacks: [:], program: [])
        doThis(.intPrint, to: inty)
        #expect(printed.isEmpty)
        #expect(inty.stacks[.error]!.first?.exactly(ErrorItem.self)?.kind == .missingArgument)
    }

    @Test func `a printed item's crux prints it again`() {
        let inty = Interpreter()
        inty.config = .recordingProvenance
        inty.load(program: [IntItem(3), IntItem(4), InstructionItem(.intAdd), InstructionItem(.intPrint)])
        inty.run()
        let item = inty.stacks[.print]!.first
        #expect(item?.pretty() == "7")
        #expect(item.map { CodeItem($0.crux()).pretty() } == "( 3 4 .intAdd .intPrint )")

        let replay = Interpreter()
        replay.load(program: item?.crux() ?? [])
        replay.run()
        #expect(replay.stacks[.print]!.map { $0.pretty() } == ["7"])
        #expect(replay.stacks[.int]!.isEmpty)
    }
}
