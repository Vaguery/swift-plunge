//
//  SubVector Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/18/26.
//
//  Whole-subsequence search and replace on vectors — the analog of string's
//  `stringContains`/`stringReplace` (as opposed to the element-wise forms).
//  Search is a non-destructive query (both vectors survive, crux pops both);
//  replace is a transform (consumes all three).
//
//  All operands share one vecX stack, so the crux records them reversed (like
//  `concat`) — the tests pin the exact crux to catch a regression there.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct SubVectorTests {

    /// haystack on top (a[0]=haystack), needle beneath (a[1]=needle) — matching
    /// the element `contains`, where the collection is the top argument.
    func loadSearch(_ hay: [Int], _ needle: [Int]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem(hay), VecIntItem(needle)] as [any Item])
        return inty
    }


    // MARK: - search (queries)

    @Test func `containsSubVec finds a contiguous run and survives both operands`() {
        let inty = loadSearch([1, 2, 3, 4], [2, 3])
        doThis(.vecIntContainsSubVec, to: inty)
        #expect((topItem(inty, .bool) as! BoolItem).value)
        #expect(stackString(inty, .vecInt) == "[ [1, 2, 3, 4] [2, 3] ]", "both survive the read")
        #expect(callString(topItem(inty, .bool))
                == "( [2, 3] [1, 2, 3, 4] .vecIntContainsSubVec 2 .vecIntPopItems )")

        // Non-contiguous → not found.
        let miss = loadSearch([1, 2, 3, 4], [2, 4])
        doThis(.vecIntContainsSubVec, to: miss)
        #expect((topItem(miss, .bool) as! BoolItem).value == false)

        // Empty needle is a vacuous prefix → contained.
        let empty = loadSearch([1, 2], [])
        doThis(.vecIntContainsSubVec, to: empty)
        #expect((topItem(empty, .bool) as! BoolItem).value)
    }

    @Test func `indexOfSubVec returns the start, or -1`() {
        let inty = loadSearch([5, 1, 2, 3], [1, 2])
        doThis(.vecIntIndexOfSubVec, to: inty)
        #expect((topItem(inty, .int) as! IntItem).value == 1)

        let miss = loadSearch([5, 1, 2, 3], [9, 9])
        doThis(.vecIntIndexOfSubVec, to: miss)
        #expect((topItem(miss, .int) as! IntItem).value == -1)
    }

    @Test func `occurrencesOfSubVec counts non-overlapping runs`() {
        let inty = loadSearch([1, 1, 1, 1], [1, 1])
        doThis(.vecIntOccurrencesOfSubVec, to: inty)
        #expect((topItem(inty, .int) as! IntItem).value == 2, "non-overlapping: [1,1][1,1]")

        // Overlapping pattern counted non-overlapping: [1,2,1,2,1] contains [1,2] twice.
        let overlap = loadSearch([1, 2, 1, 2, 1], [1, 2])
        doThis(.vecIntOccurrencesOfSubVec, to: overlap)
        #expect((topItem(overlap, .int) as! IntItem).value == 2)

        // Empty needle counts 0.
        let empty = loadSearch([1, 2], [])
        doThis(.vecIntOccurrencesOfSubVec, to: empty)
        #expect((topItem(empty, .int) as! IntItem).value == 0)
    }

    @Test func `a subvector search crux reproduces debris-free`() {
        let inty = loadSearch([1, 2, 3], [2, 3])
        doThis(.vecIntIndexOfSubVec, to: inty)
        let result = topItem(inty, .int)

        let redo = Interpreter.recordingProvenance()
        redo.load(program: result.crux())
        redo.run()
        #expect(stackString(redo, .int) == "[ 1 ]")
        #expect(redo.stacks[.vecInt]!.isEmpty, "the crux popped both operands")
    }


    // MARK: - replace (transforms)

    /// subject deepest, needle, replacement on top (a[0]=repl, a[1]=needle, a[2]=subject).
    func loadReplace(_ subject: [Int], _ needle: [Int], _ repl: [Int]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.vecInt]!.prepend(contentsOf:
            [VecIntItem(repl), VecIntItem(needle), VecIntItem(subject)] as [any Item])
        return inty
    }

    @Test func `replaceSubVec substitutes every occurrence and consumes`() {
        let inty = loadReplace([1, 2, 3, 2, 3], [2, 3], [9])
        doThis(.vecIntReplaceSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 9, 9] ]", "both runs replaced, args consumed")
        #expect(callString(topItem(inty, .vecInt))
                == "( [1, 2, 3, 2, 3] [2, 3] [9] .vecIntReplaceSubVec )")
    }

    @Test func `replaceFirstSubVec substitutes only the first`() {
        let inty = loadReplace([1, 2, 3, 2, 3], [2, 3], [9])
        doThis(.vecIntReplaceFirstSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 9, 2, 3] ]")
    }

    @Test func `replace with a longer or empty replacement`() {
        // Longer replacement (a splice).
        let grow = loadReplace([1, 2, 1], [2], [7, 7])
        doThis(.vecIntReplaceSubVec, to: grow)
        #expect(stackString(grow, .vecInt) == "[ [1, 7, 7, 1] ]")

        // Empty replacement deletes the needle.
        let shrink = loadReplace([1, 2, 3], [2], [])
        doThis(.vecIntReplaceSubVec, to: shrink)
        #expect(stackString(shrink, .vecInt) == "[ [1, 3] ]")

        // Empty needle is a no-op (never matches).
        let noop = loadReplace([1, 2, 3], [], [9])
        doThis(.vecIntReplaceSubVec, to: noop)
        #expect(stackString(noop, .vecInt) == "[ [1, 2, 3] ]")
    }

    @Test func `a replace crux reproduces the vector`() {
        let inty = loadReplace([1, 2, 3, 2, 3], [2, 3], [9])
        doThis(.vecIntReplaceSubVec, to: inty)
        let result = topItem(inty, .vecInt)

        let redo = Interpreter.recordingProvenance()
        redo.load(program: result.crux())
        redo.run()
        #expect(stackString(redo, .vecInt) == "[ [1, 9, 9] ]")
    }


    // MARK: - the other types exist and work

    @Test func `the family is generic across all four vector types`() {
        // string subvectors — haystack on top
        let s = Interpreter.recordingProvenance()
        s.stacks[.vecString]!.prepend(contentsOf:
            [VecStringItem(["a", "b", "c"]), VecStringItem(["b"])] as [any Item])
        doThis(.vecStringContainsSubVec, to: s)
        #expect((topItem(s, .bool) as! BoolItem).value)

        // bool subvectors — haystack on top
        let b = Interpreter.recordingProvenance()
        b.stacks[.vecBool]!.prepend(contentsOf:
            [VecBoolItem([false, true, false, true]), VecBoolItem([true, false])] as [any Item])
        doThis(.vecBoolIndexOfSubVec, to: b)
        #expect((topItem(b, .int) as! IntItem).value == 1)

        // double replace
        let d = Interpreter.recordingProvenance()
        d.stacks[.vecDouble]!.prepend(contentsOf:
            [VecDoubleItem([0.0]), VecDoubleItem([2.0]), VecDoubleItem([1.0, 2.0, 3.0])] as [any Item])
        doThis(.vecDoubleReplaceSubVec, to: d)
        #expect(stackString(d, .vecDouble) == "[ [1.0, 0.0, 3.0] ]")
    }
}
