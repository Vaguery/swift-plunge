//
//  Containment Tests.swift
//  PlungeTests
//
//  The containment law: an item taken out of a container keeps its own history,
//  and one born inside a container that has a history records its address. See
//  `Containment`.
//

@testable import Plunge
import Testing

@Suite
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
        let inty = run([InstructionItem(.input3), CodeItem([]), InstructionItem(.codeIterateEmit)])
        let six = topItem(inty, .int)
        #expect(six.crux().contains { ($0 as? InstructionItem)?.value == .codeEmitNth })
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
                        InstructionItem(.codeWrapRange), InstructionItem(.codeDo)])
        let inner = topItem(inty, .code)
        #expect(inner.pretty() == "( 2 3 )")
        #expect(!inner.call.isEmpty)
        #expect(holds(inner))
    }

    // MARK: Members: vector and string elements

    private let five: [any Item] = [IntItem(2), IntItem(3), InstructionItem(.intAdd)]
    private let letterFromInt: [any Item] = [IntItem(65), InstructionItem(.charFromInt)]

    @Test func `a vector element that went in with a history comes out with it`() {
        let inty = run([VecIntItem([])] + five
                       + [InstructionItem(.vecIntConj), IntItem(0), InstructionItem(.vecIntNth)])
        let element = topItem(inty, .int)
        #expect(CodeItem(element.crux()).pretty() == "( 2 3 .intAdd )")
        #expect(holds(element))
    }

    @Test func `members travel with their elements through rearrangement and iteration`() {
        // [ 9 5 ] reversed is [ 5 9 ]; its first element is the computed 5.
        let reversed = run([VecIntItem([9])] + five + [InstructionItem(.vecIntConj),
                           InstructionItem(.vecIntReverse), InstructionItem(.vecIntFirst)])
        #expect(CodeItem(topItem(reversed, .int).crux()).pretty() == "( 2 3 .intAdd )")
        // Pushed out one per pass by the iterator: the last element ends up on top.
        let pushed = run([VecIntItem([9])] + five + [InstructionItem(.vecIntConj), InstructionItem(.vecIntPushAll)])
        #expect(stackString(pushed, .int) == "[ 5 9 ]")
        #expect(CodeItem(topItem(pushed, .int).crux()).pretty() == "( 2 3 .intAdd )")
        #expect(pushed.stacks[.int]!.allSatisfy { holds($0) })
    }

    @Test func `an element with no member is addressed from its vector`() {
        let inty = run([VecIntItem([7])] + five
                       + [InstructionItem(.vecIntConj), IntItem(0), InstructionItem(.vecIntNth)])
        let seven = topItem(inty, .int)
        #expect(seven.pretty() == "7")
        #expect(seven.crux().contains { ($0 as? InstructionItem)?.value == .vecIntNth })
        #expect(holds(seven))
    }

    @Test func `a string's characters keep their members, letters included`() {
        let last = run([StringItem("x")] + letterFromInt
                       + [InstructionItem(.stringConj), InstructionItem(.stringLast)])
        #expect(CodeItem(topItem(last, .char).crux()).pretty() == "( 65 .charFromInt )")
        let letters = run([StringItem("x")] + letterFromInt + [InstructionItem(.stringConj),
                          InstructionItem(.stringPushAllLetters)])
        #expect(stackString(letters, .string) == "[ \"A\" \"x\" ]", "65 is 'A' (its Unicode scalar value)")
        #expect(CodeItem(topItem(letters, .string).crux()).pretty() == "( 65 .charFromInt .stringFromChar )")
        #expect(letters.stacks[.string]!.allSatisfy { holds($0) })
    }

    @Test func `members that do not line up with the characters are dropped`() {
        let acute = CharItem("\u{301}", call: [IntItem(769), InstructionItem(.charFromInt)])
        let pieces = Pieces([.item(CharItem("e")), .item(acute)])
        // "e" and a combining acute are one character, "é", not two.
        #expect(Containment.aligned(pieces, with: Array("e\u{301}")) == nil)
        #expect(Containment.aligned(pieces, with: ["e", "\u{301}"]) != nil)
        #expect(Containment.aligned(pieces, with: ["e", "x"]) == nil)
    }

    // MARK: The piece table

    @Test func `an element is addressed from the source it was born in, through any rearrangement`() {
        // Concatenated, reversed, then the first: the 4 that was born in [3, 4].
        let inty = run([VecIntItem([1, 2]), VecIntItem([3, 4]), InstructionItem(.vecIntConcat),
                        InstructionItem(.vecIntReverse), InstructionItem(.vecIntFirst)])
        let four = topItem(inty, .int)
        #expect(four.pretty() == "4")
        #expect(CodeItem(four.crux()).pretty() == "( [3, 4] 1 .vecIntNth )")
        #expect(holds(four))
    }

    @Test func `a bound constant's element names the constant`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: [:], constants: [.vecInt3: VecIntItem([10, 20, 30])],
                  program: [InstructionItem(.vecInt3), VecIntItem([5]), InstructionItem(.vecIntConcat),
                            InstructionItem(.vecIntPushAll)])
        inty.run(stepLimit: 1_000)
        #expect(stackString(inty, .int) == "[ 5 30 20 10 ]")
        #expect(CodeItem(inty.stacks[.int]![2].crux()).pretty() == "( .vecInt3 1 .vecIntNth )")
    }

    @Test func `runs merge where positions continue, and lookups cross runs`() {
        let source = VecIntItem(Array(0..<100), call: [InstructionItem(.vecInt3)])
        // Reversed whole: one run, stepping back.
        let reversed = Pieces(source.origins().reversed())
        #expect(reversed.runs.count == 1)
        if case .element(_, let position, _)? = reversed.origin(at: 0) { #expect(position == 99) }
        // A source, an item, the source again: three runs, and each lookup lands.
        let five = IntItem(5, call: [IntItem(2), IntItem(3), InstructionItem(.intAdd)])
        let mixed = Pieces(Array(source.origins(0)[0..<10]) + [.item(five)] + Array(source.origins(1)[50..<60]))
        #expect(mixed.runs.count == 3)
        #expect(mixed.count == 21)
        if case .item(let item)? = mixed.origin(at: 10) { #expect(item.pretty() == "5") }
        if case .element(_, let position, _)? = mixed.origin(at: 15) { #expect(position == 54) }
        #expect(mixed.origin(at: 21) == nil)
    }

    @Test func `with recording off nothing is built`() {
        let inty = run([InstructionItem(.input3), InstructionItem(.codeDo)], recording: false)
        #expect(stackString(inty, .int) == "[ 6 5 ]")
        #expect(inty.stacks[.int]!.allSatisfy { $0.call.isEmpty })
        let vector = run([VecIntItem([])] + five + [InstructionItem(.vecIntConj)], recording: false)
        #expect((topItem(vector, .vecInt) as? VecIntItem)?.members == nil)
    }
}
