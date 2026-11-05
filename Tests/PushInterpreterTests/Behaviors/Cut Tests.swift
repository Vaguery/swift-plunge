//
//  Cut Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/17/26.
//
//  `.vecXCut` (all four vectors) and `.stringCut`: snip the argument in two at an
//  index taken modulo its length, pushing both pieces to the same stack.
//
//  Two things carry the weight here and neither is the happy-path value:
//
//  1. **Order.** The prefix goes deeper, the suffix on top, *so that `cut` then
//     `concat` is the identity* — `concat` consumes the deeper piece first. Every
//     cut test checks which piece landed where, and a round-trip test proves the
//     identity.
//  2. **The deep piece's provenance.** Two results on one stack is law 5
//     (`Behavior.selecting`): the top piece records just the cut, but the deeper
//     one records the discard that surfaces it — `… .vecIntCut 1 .vecIntPopItems`.
//     The crux round-trip sweep only ever checks a stack's *top* item, so the deep
//     piece's crux is verified **here** or nowhere.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct CutTests {

    var inty = Interpreter.recordingProvenance()

    /// Load a vector and an index, cut, and return `(deeperPiece, topPiece)`.
    func cut(_ vector: any Item, at index: Int, _ instruction: PushInstruction, on stack: PushStack)
        -> (deep: any Item, top: any Item) {
        inty.stacks[stack]!.prepend(vector)
        inty.stacks[.int]!.prepend(IntItem(index))
        doThis(instruction, to: inty)
        return (inty.stacks[stack]![1], inty.stacks[stack]![0])
    }

    /// Reconstruct an item from its crux on a fresh interpreter, and return the
    /// top of its resting stack. This is the check the sweep does not do for the
    /// deep piece.
    func reproduced(_ item: any Item, on stack: PushStack) -> (any Item)? {
        let redo = Interpreter.recordingProvenance()
        redo.load(program: item.crux())
        redo.run()
        return redo.stacks[stack]!.first
    }


    // MARK: - vecInt: the reference type, tested exhaustively

    @Test mutating func `vecIntCut splits at the index, suffix on top`() {
        let (deep, top) = cut(VecIntItem([1, 2, 3, 4, 5]), at: 2, .vecIntCut, on: .vecInt)

        #expect(stackString(inty, .vecInt) == "[ [3, 4, 5] [1, 2] ]")
        #expect((deep as? VecIntItem)?.value == [1, 2], "the prefix is the deeper piece")
        #expect((top as? VecIntItem)?.value == [3, 4, 5], "the suffix is on top")
    }

    @Test mutating func `both vecInt pieces reproduce from their crux`() {
        let (deep, top) = cut(VecIntItem([1, 2, 3, 4, 5]), at: 2, .vecIntCut, on: .vecInt)

        // Each piece clears the other: the deep one pops the suffix off the top,
        // the top one lifts the prefix out from under itself and pops that.
        #expect(callString(top) == "( [1, 2, 3, 4, 5] 2 .vecIntCut .vecIntSwap .vecIntPop )")
        #expect(callString(deep) == "( [1, 2, 3, 4, 5] 2 .vecIntCut 1 .vecIntPopItems )")

        #expect(reproduced(top, on: .vecInt)?.pretty() == "[3, 4, 5]")
        #expect(reproduced(deep, on: .vecInt)?.pretty() == "[1, 2]",
                "the deep piece's crux must pop the suffix to surface itself")
    }

    /// Both cruxes must be fixed points, or "the crux" is not well defined — the
    /// property the crux fuzzer exists to protect.
    @Test mutating func `both vecInt cruxes are fixed points`() {
        let (deep, top) = cut(VecIntItem([7, 8, 9]), at: 1, .vecIntCut, on: .vecInt)
        for piece in [deep, top] {
            let once = CodeItem(piece.crux()).pretty()
            let twice = CodeItem(reproduced(piece, on: .vecInt)!.crux()).pretty()
            #expect(once == twice, "re-running \(once) reworded it to \(twice)")
        }
    }

    /// **The reason for the order.** Cut, then concat the two pieces, and the
    /// original comes back.
    @Test mutating func `vecIntCut then vecIntConcat is the identity`() {
        _ = cut(VecIntItem([1, 2, 3, 4, 5]), at: 2, .vecIntCut, on: .vecInt)
        doThis(.vecIntConcat, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 2, 3, 4, 5] ]")
    }

    @Test mutating func `the vecInt index wraps modulo the length`() {
        // 7 % 5 == 2, so this is the same cut as index 2.
        let (deep, top) = cut(VecIntItem([1, 2, 3, 4, 5]), at: 7, .vecIntCut, on: .vecInt)
        #expect((deep as? VecIntItem)?.value == [1, 2])
        #expect((top as? VecIntItem)?.value == [3, 4, 5])
        // And the crux records the *given* index, not the reduced one — it re-runs
        // through the same modulo, so it reproduces without pre-reducing.
        #expect(callString(top) == "( [1, 2, 3, 4, 5] 7 .vecIntCut .vecIntSwap .vecIntPop )")
        #expect(reproduced(top, on: .vecInt)?.pretty() == "[3, 4, 5]")
    }

    /// A negative index cannot trap (that is why `.magnitude` is used, not `abs`),
    /// and `Int.min` is the case `abs` would have crashed on.
    @Test mutating func `a negative vecInt index uses magnitude, and Int_min does not trap`() {
        // (-3).magnitude % 5 == 3
        let (deep, _) = cut(VecIntItem([1, 2, 3, 4, 5]), at: -3, .vecIntCut, on: .vecInt)
        #expect((deep as? VecIntItem)?.value == [1, 2, 3])

        inty = Interpreter.recordingProvenance()
        let (d2, t2) = cut(VecIntItem([1, 2, 3, 4, 5]), at: .min, .vecIntCut, on: .vecInt)
        // Int.min.magnitude % 5 == 3
        #expect((d2 as? VecIntItem)?.value == [1, 2, 3])
        #expect((t2 as? VecIntItem)?.value == [4, 5])
    }

    /// The wrap means an index of exactly `count` folds to 0, so you can never cut
    /// off the whole vector and leave nothing: **the suffix is never empty**.
    @Test mutating func `cutting at the length wraps to zero, never leaving an empty suffix`() {
        let (deep, top) = cut(VecIntItem([1, 2, 3]), at: 3, .vecIntCut, on: .vecInt)
        #expect((deep as? VecIntItem)?.value == [], "index 3 % 3 == 0: empty prefix")
        #expect((top as? VecIntItem)?.value == [1, 2, 3], "the whole vector on top")
    }

    @Test mutating func `cutting an empty vector gives two empty vectors`() {
        let (deep, top) = cut(VecIntItem([]), at: 4, .vecIntCut, on: .vecInt)
        #expect((deep as? VecIntItem)?.value == [])
        #expect((top as? VecIntItem)?.value == [])
        // Both still reproduce — the modulo-by-zero guard does not break provenance.
        #expect(reproduced(deep, on: .vecInt)?.pretty() == "[]")
        #expect(reproduced(top, on: .vecInt)?.pretty() == "[]")
    }

    @Test mutating func `a singleton cuts into empty and itself`() {
        // Any index modulo 1 is 0, so a one-element vector has only one cut.
        let (deep, top) = cut(VecIntItem([42]), at: 9, .vecIntCut, on: .vecInt)
        #expect((deep as? VecIntItem)?.value == [])
        #expect((top as? VecIntItem)?.value == [42])
    }



    // MARK: - the other three vector types

    @Test mutating func `vecBoolCut splits and reproduces`() {
        let (deep, top) = cut(VecBoolItem([true, false, true]), at: 1, .vecBoolCut, on: .vecBool)
        #expect((deep as? VecBoolItem)?.value == [true])
        #expect((top as? VecBoolItem)?.value == [false, true])
        #expect(callString(deep) == "( [true, false, true] 1 .vecBoolCut 1 .vecBoolPopItems )")
        #expect(reproduced(deep, on: .vecBool)?.pretty() == "[true]")
        #expect(reproduced(top, on: .vecBool)?.pretty() == "[false, true]")
    }

    @Test mutating func `vecDoubleCut splits and reproduces`() {
        let (deep, top) = cut(VecDoubleItem([1.5, 2.5, 3.5]), at: 2, .vecDoubleCut, on: .vecDouble)
        #expect((deep as? VecDoubleItem)?.value == [1.5, 2.5])
        #expect((top as? VecDoubleItem)?.value == [3.5])
        #expect(reproduced(deep, on: .vecDouble)?.pretty() == "[1.5, 2.5]")
        #expect(reproduced(top, on: .vecDouble)?.pretty() == "[3.5]")
    }

    @Test mutating func `vecStringCut splits and reproduces`() {
        let (deep, top) = cut(VecStringItem(["a", "b", "c", "d"]), at: 3, .vecStringCut, on: .vecString)
        #expect((deep as? VecStringItem)?.value == ["a", "b", "c"])
        #expect((top as? VecStringItem)?.value == ["d"])
        #expect(reproduced(deep, on: .vecString)?.pretty() == "[\"a\", \"b\", \"c\"]")
        #expect(reproduced(top, on: .vecString)?.pretty() == "[\"d\"]")
    }

    @Test mutating func `every vector cut then concat is the identity`() {
        let cases: [(any Item, PushStack, PushInstruction, PushInstruction)] = [
            (VecBoolItem([true, false, true, false]), .vecBool, .vecBoolCut, .vecBoolConcat),
            (VecDoubleItem([1, 2, 3, 4]), .vecDouble, .vecDoubleCut, .vecDoubleConcat),
            (VecStringItem(["w", "x", "y", "z"]), .vecString, .vecStringCut, .vecStringConcat),
        ]
        for (vector, stack, cutInstr, concatInstr) in cases {
            inty = Interpreter.recordingProvenance()
            let before = vector.pretty()
            _ = cut(vector, at: 3, cutInstr, on: stack)
            doThis(concatInstr, to: inty)
            #expect(stackString(inty, stack) == "[ \(before) ]", "\(cutInstr) then \(concatInstr)")
        }
    }


    // MARK: - stringCut

    @Test mutating func `stringCut splits at the index, suffix on top`() {
        let (deep, top) = cut(StringItem("hello"), at: 2, .stringCut, on: .string)
        #expect(stackString(inty, .string) == "[ \"llo\" \"he\" ]")
        #expect((deep as? StringItem)?.value == "he", "the prefix is deeper")
        #expect((top as? StringItem)?.value == "llo", "the suffix is on top")
    }

    @Test mutating func `both string pieces reproduce from their crux`() {
        let (deep, top) = cut(StringItem("hello"), at: 2, .stringCut, on: .string)
        #expect(callString(top) == "( \"hello\" 2 .stringCut .stringSwap .stringPop )")
        #expect(callString(deep) == "( \"hello\" 2 .stringCut 1 .stringPopItems )")
        #expect(reproduced(top, on: .string)?.pretty() == "\"llo\"")
        #expect(reproduced(deep, on: .string)?.pretty() == "\"he\"")
    }

    @Test mutating func `stringCut then stringConcat is the identity`() {
        _ = cut(StringItem("hello"), at: 2, .stringCut, on: .string)
        doThis(.stringConcat, to: inty)
        #expect(stackString(inty, .string) == "[ \"hello\" ]")
    }

    @Test mutating func `the string index wraps, and an empty string gives two empties`() {
        // 8 % 5 == 3
        let (deep, top) = cut(StringItem("hello"), at: 8, .stringCut, on: .string)
        #expect((deep as? StringItem)?.value == "hel")
        #expect((top as? StringItem)?.value == "lo")

        inty = Interpreter.recordingProvenance()
        let (d2, t2) = cut(StringItem(""), at: 3, .stringCut, on: .string)
        #expect((d2 as? StringItem)?.value == "")
        #expect((t2 as? StringItem)?.value == "")
        #expect(reproduced(d2, on: .string)?.pretty() == "\"\"")
    }

    /// Counting is by grapheme, like the rest of the string instructions, so a
    /// multi-scalar character is one position and never split down the middle.
    @Test mutating func `stringCut counts graphemes, not scalars`() {
        // "e\u{301}" is one grapheme (é); the string is 3 graphemes.
        let (deep, top) = cut(StringItem("a\u{65}\u{301}z"), at: 2, .stringCut, on: .string)
        #expect((deep as? StringItem)?.value.count == 2)
        #expect((top as? StringItem)?.value.count == 1)
        #expect((top as? StringItem)?.value == "z")
    }


    // MARK: - the language

    @Test func `all five cut instructions are registered`() {
        for instruction: PushInstruction in
            [.vecBoolCut, .vecDoubleCut, .vecIntCut, .vecStringCut, .stringCut] {
            #expect(Interpreter.language[instruction] != nil, "\(instruction) missing")
        }
    }

    /// Each cut takes its own collection and one int, and consumes nothing more.
    @Test func `each cut declares collection-plus-int`() {
        let expected: [(PushInstruction, PushStack)] = [
            (.vecBoolCut, .vecBool), (.vecDoubleCut, .vecDouble),
            (.vecIntCut, .vecInt), (.vecStringCut, .vecString), (.stringCut, .string),
        ]
        for (instruction, stack) in expected {
            #expect(Interpreter.language[instruction]?.parameters == [stack, .int],
                    "\(instruction) parameters")
        }
    }

    /// Short an int and it refuses like any other instruction, taking nothing —
    /// the all-or-nothing bargain the Planner keeps for the whole language.
    @Test mutating func `cut refuses without its index and keeps its collection`() {
        inty.stacks[.vecInt]!.prepend(VecIntItem([1, 2, 3]))   // no .int
        doThis(.vecIntCut, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 2, 3] ]", "the vector is untouched")
        #expect(inty.stacks[.error]!.contains { ($0 as? ErrorItem)?.value.contains("missing args: .int") == true })
    }
}
