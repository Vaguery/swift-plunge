//
//  Short Iterator Tests.swift
//  PushInterpreterTests
//
//  The two-argument iterator constructors (Behavior coverage audit, P3): a
//  collection and a body make an iterator a random program can build.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct ShortIteratorTests {

    static func run(_ program: [any Item]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: program)
        inty.run(stepLimit: 10_000)
        return inty
    }

    static let square = CodeItem([InstructionItem(.intDup), InstructionItem(.intMultiply)])

    @Test func `two arguments build an iterator that is not crux-only`() {
        let inty = Self.run([VecIntItem([1, 2, 3]), Self.square, InstructionItem(.iteratorOverVecInt)])
        #expect(inty.stacks[.iterator]!.count == 1)
        #expect(!Interpreter.language[.iteratorOverVecInt]!.tags.contains(.cruxOnly))
    }

    @Test func `playing it runs the body per element`() {
        let inty = Self.run([VecIntItem([1, 2, 3]), Self.square, InstructionItem(.iteratorOverVecInt),
                             InstructionItem(.iteratorPlay)])
        #expect(stackString(inty, .int) == "[ 9 4 1 ]")
    }

    @Test func `collecting it is the stack-fed map`() {
        let inty = Self.run([VecIntItem([1, 2, 3]), Self.square, InstructionItem(.iteratorOverVecInt),
                             InstructionItem(.vecFromIterator)])
        #expect(stackString(inty, .vecInt) == "[ [1, 4, 9] ]")

        let upper = Self.run([StringItem("abc"), CodeItem([InstructionItem(.charUpper)]),
                              InstructionItem(.iteratorOverString), InstructionItem(.vecFromIterator)])
        #expect(stackString(upper, .string) == "[ \"ABC\" ]")
    }

    @Test func `an empty body makes a sequence`() {
        let inty = Self.run([VecStringItem(["a", "b"]), CodeItem([]), InstructionItem(.iteratorOverVecString),
                             InstructionItem(.vecFromIterator)])
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\"] ]")
    }

    @Test func `a code iterator takes its origin before its body`() {
        let origin = CodeItem([IntItem(2), IntItem(5)])
        let inty = Self.run([origin, Self.square, InstructionItem(.iteratorOverCode),
                             InstructionItem(.vecFromIterator)])
        #expect(stackString(inty, .vecInt) == "[ [4, 25] ]")
    }

    @Test func `an empty collection is refused`() {
        let inty = Self.run([VecIntItem([]), Self.square, InstructionItem(.iteratorOverVecInt)])
        #expect(inty.stacks[.iterator]!.isEmpty)
        #expect(inty.stacks[.error]!.count == 1)
    }
}
