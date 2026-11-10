//
//  Code Gap Tests.swift
//  PushInterpreterTests
//
//  The gap model (`CodeGaps.swift`) and the four instructions on it:
//  codeCutAtGap, codeInsertAtGap, codeWrapRange, codeFlattenRange.
//
//  The running example throughout is `( 1 ( 2 3 ) 4 )`:
//
//      tokens   1  open  2  3  close  4          6 tokens
//      gap    0    1   2  3  4     5    6        7 gaps
//
//  so gap 0 is before everything, gap 6 after everything, gap 2 is the head of
//  the nested block and gap 4 its tail.
//

@testable import PushInterpreter
import Testing
import DequeModule


@Suite @MainActor
struct CodeGapTests {

    /// `( 1 ( 2 3 ) 4 )` — the example in the file header.
    var nested: CodeItem {
        CodeItem([IntItem(1),
                  CodeItem([IntItem(2), IntItem(3)]),
                  IntItem(4)])
    }

    func leaves(_ item: any Item) -> [String] {
        ((item as? CodeItem)?.flattenedLeaves() ?? [item]).map { $0.pretty() }
    }


    // MARK: - The model itself

    @Test func `a tree has one more gap than it has tokens`() {
        #expect(nested.gapTokens.count == 6)
        #expect(nested.gapCount == 7, "before-first and after-last both count")

        // A flat block is exactly the root-array model codeCutRoot uses.
        #expect(CodeItem([IntItem(1), IntItem(2)]).gapCount == 3)
        #expect(CodeItem([]).gapCount == 1, "an empty block still has the one gap")
    }

    /// Clamped over the gaps, `0…gapCount−1`; it used to wrap.
    @Test func `the gap index clamps to the gaps`() {
        #expect(nested.gapIndex(0) == 0)
        #expect(nested.gapIndex(6) == 6)
        #expect(nested.gapIndex(7) == 6, "past the last gap is the last gap")
        #expect(nested.gapIndex(-1) == 0, "below the first gap is the first gap")
        #expect(nested.gapIndex(Int.min) == 0)
        #expect(nested.gapIndex(Int.max) == 6)
    }

    @Test func `rebuilding repairs an unbalanced token run`() {
        // Unmatched open: closed at the end.
        #expect(CodeItem.rebuilt(from: [.item(IntItem(1)), .open, .item(IntItem(2))]).pretty()
                == "( 1 ( 2 ) )")
        // Unmatched close: dropped.
        #expect(CodeItem.rebuilt(from: [.item(IntItem(3)), .close, .item(IntItem(4))]).pretty()
                == "( 3 4 )")
        // A balanced run is untouched — the round trip through tokens is exact.
        #expect(CodeItem.rebuilt(from: nested.gapTokens).pretty() == nested.pretty())
    }


    // MARK: - codeCutAtGap

    @Test func `cutAtGap splits inside a nested block, suffix on top`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(nested)
        inty.stacks[.int]!.prepend(IntItem(3))       // between 2 and 3
        doThis(.codeCutAtGap, to: inty)
        #expect(stackString(inty, .code) == "[ ( 3 4 ) ( 1 ( 2 ) ) ]",
                "prefix deeper with its open block closed, suffix on top with its stray close dropped")
    }

    /// **The law the repair exists to keep.** Nesting on the cut path changes;
    /// no leaf is lost, gained, or reordered.
    @Test func `cutAtGap preserves every leaf in order, at every gap`() {
        let want = leaves(nested)
        for gap in 0..<nested.gapCount {
            let inty = Interpreter.recordingProvenance()
            inty.stacks[.code]!.prepend(nested)
            inty.stacks[.int]!.prepend(IntItem(gap))
            doThis(.codeCutAtGap, to: inty)

            let top = topItem(inty, .code)
            let deep = probeItemOnStack(inty, .code, index: 1)!
            #expect(leaves(deep) + leaves(top) == want,
                    "gap \(gap): \(leaves(deep)) + \(leaves(top)) != \(want)")
        }
    }

    @Test func `cutAtGap reaches both extremes`() {
        let head = Interpreter.recordingProvenance()
        head.stacks[.code]!.prepend(nested)
        head.stacks[.int]!.prepend(IntItem(0))
        doThis(.codeCutAtGap, to: head)
        #expect(stackString(head, .code) == "[ ( 1 ( 2 3 ) 4 ) ( ) ]",
                "empty prefix deeper, whole suffix on top")

        let tail = Interpreter.recordingProvenance()
        tail.stacks[.code]!.prepend(nested)
        tail.stacks[.int]!.prepend(IntItem(6))
        doThis(.codeCutAtGap, to: tail)
        #expect(stackString(tail, .code) == "[ ( ) ( 1 ( 2 3 ) 4 ) ]",
                "whole prefix deeper, empty suffix on top")
    }

    /// A cut between root elements still round-trips, exactly as
    /// `codeCutRoot` does — the gap model generalizes that case rather than
    /// replacing it.
    @Test func `a root-level cut still rejoins under codeConcat`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(nested)
        inty.stacks[.int]!.prepend(IntItem(1))       // between 1 and the block
        doThis(.codeCutAtGap, to: inty)
        doThis(.codeConcat, to: inty)
        #expect(stackString(inty, .code) == "[ ( 1 ( 2 3 ) 4 ) ]")
    }

    /// **And an interior cut does not** — pinned so a later reader takes it for
    /// the documented limit it is rather than a bug. A block split in two cannot
    /// reassemble; the leaves survive, the nesting does not.
    @Test func `an interior cut does not rejoin, and that is the documented limit`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(nested)
        inty.stacks[.int]!.prepend(IntItem(3))       // inside ( 2 3 )
        doThis(.codeCutAtGap, to: inty)
        doThis(.codeConcat, to: inty)
        #expect(stackString(inty, .code) == "[ ( 1 ( 2 ) 3 4 ) ]",
                "the split block came back as one block and two loose leaves")
        #expect(stackString(inty, .code) != "[ ( 1 ( 2 3 ) 4 ) ]")
    }


    // MARK: - codeInsertAtGap

    @Test func `insertAtGap reaches head, tail, and inside a nested block`() {
        func insert(_ gap: Int) -> String {
            let inty = Interpreter.recordingProvenance()
            inty.stacks[.code]!.prepend(contentsOf:
                [CodeItem([IntItem(9)]), nested] as [any Item])   // insert on top, subject deeper
            inty.stacks[.int]!.prepend(IntItem(gap))
            doThis(.codeInsertAtGap, to: inty)
            return stackString(inty, .code)
        }
        #expect(insert(0) == "[ ( 9 1 ( 2 3 ) 4 ) ]", "head of the root")
        #expect(insert(6) == "[ ( 1 ( 2 3 ) 4 9 ) ]", "tail of the root")
        #expect(insert(2) == "[ ( 1 ( 9 2 3 ) 4 ) ]", "head of the nested block")
        #expect(insert(4) == "[ ( 1 ( 2 3 9 ) 4 ) ]", "tail of the nested block")
    }

    /// The `denotedItem` convention, shared with `codeContains`, `codePair` and
    /// the replace family: a one-element block contributes its bare element.
    @Test func `insertAtGap denotes its insertion`() {
        func insert(_ block: CodeItem) -> String {
            let inty = Interpreter.recordingProvenance()
            inty.stacks[.code]!.prepend(contentsOf:
                [block, CodeItem([IntItem(1)])] as [any Item])
            inty.stacks[.int]!.prepend(IntItem(0))
            doThis(.codeInsertAtGap, to: inty)
            return stackString(inty, .code)
        }
        #expect(insert(CodeItem([IntItem(5)])) == "[ ( 5 1 ) ]", "( 5 ) inserts the leaf")
        #expect(insert(CodeItem([CodeItem([IntItem(5)])])) == "[ ( ( 5 ) 1 ) ]",
                "( ( 5 ) ) inserts the block")
        #expect(insert(CodeItem([IntItem(5), IntItem(6)])) == "[ ( ( 5 6 ) 1 ) ]",
                "a multi-element block inserts whole")
    }


    // MARK: - codeWrapRange

    @Test func `wrapPoints opens at the lower gap and closes at the higher`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2), IntItem(3)]))
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(3), IntItem(1)] as [any Item])
        doThis(.codeWrapRange, to: inty)
        #expect(stackString(inty, .code) == "[ ( 1 ( 2 3 ) ) ]")
    }

    @Test func `wrapPoints sorts its indices, so a reversed pair wraps the same span`() {
        func wrap(_ n: Int, _ m: Int) -> String {
            let inty = Interpreter.recordingProvenance()
            inty.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2), IntItem(3)]))
            // a[1] is the top .int, a[2] the one beneath.
            inty.stacks[.int]!.prepend(contentsOf: [IntItem(n), IntItem(m)] as [any Item])
            doThis(.codeWrapRange, to: inty)
            return stackString(inty, .code)
        }
        #expect(wrap(3, 1) == wrap(1, 3))
    }

    @Test func `wrapPoints with equal indices inserts an empty block`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2)]))
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(1), IntItem(1)] as [any Item])
        doThis(.codeWrapRange, to: inty)
        #expect(stackString(inty, .code) == "[ ( 1 ( ) 2 ) ]")
    }

    /// A wrap crossing an existing boundary unbalances the token run; the repair
    /// in `rebuilt(from:)` is what makes it land as a tree rather than fail.
    @Test func `wrapPoints across a nested boundary is repaired`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(nested)
        // Open at gap 1 (before the block), close at gap 3 (inside it).
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(3), IntItem(1)] as [any Item])
        doThis(.codeWrapRange, to: inty)
        #expect(leaves(topItem(inty, .code)) == ["1", "2", "3", "4"],
                "the shape changes, but no leaf is lost")
    }


    // MARK: - codeFlattenRange

    /// `( a ( b ( c d ) e ) f )` — the case that decided the enclosing-block rule.
    var deep: CodeItem {
        CodeItem([IntItem(0),
                  CodeItem([IntItem(1),
                            CodeItem([IntItem(2), IntItem(3)]),
                            IntItem(4)]),
                  IntItem(5)])
    }

    @Test func `flattenRange flattens a block the range reaches into`() {
        // deep tokens: 0 open 1 open 2 3 close 4 close 5
        // gap:        0 1    2 3    4 5 6     7 8     9 10
        // inner block ( 2 3 ): head 4, tail 6.
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(deep)
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(6), IntItem(4)] as [any Item])
        doThis(.codeFlattenRange, to: inty)
        #expect(stackString(inty, .code) == "[ ( 0 ( 1 2 3 4 ) 5 ) ]",
                "the inner block goes; the one enclosing it stays")
    }

    /// **The decided semantics.** A block that merely encloses the range keeps its
    /// shape — otherwise a one-gap range would flatten the whole tree, since the
    /// root encloses every range.
    @Test func `flattenRange leaves an enclosing block alone`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(deep)
        // A range entirely inside ( 2 3 ) and touching neither of its ends.
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(5), IntItem(5)] as [any Item])
        doThis(.codeFlattenRange, to: inty)
        #expect(stackString(inty, .code) == "[ ( 0 ( 1 ( 2 3 ) 4 ) 5 ) ]",
                "nothing has a boundary in the range, so nothing changes")
    }

    @Test func `flattenRange leaves a block entirely outside the range alone`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(nested)
        // Gaps 5..6 are past the nested block entirely (its head 2, tail 4).
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(6), IntItem(5)] as [any Item])
        doThis(.codeFlattenRange, to: inty)
        #expect(stackString(inty, .code) == "[ ( 1 ( 2 3 ) 4 ) ]")
    }

    @Test func `flattenRange never loses a leaf`() {
        for lo in 0..<deep.gapCount {
            for hi in lo..<deep.gapCount {
                let inty = Interpreter.recordingProvenance()
                inty.stacks[.code]!.prepend(deep)
                inty.stacks[.int]!.prepend(contentsOf: [IntItem(hi), IntItem(lo)] as [any Item])
                doThis(.codeFlattenRange, to: inty)
                #expect(leaves(topItem(inty, .code)) == leaves(deep),
                        "range \(lo)...\(hi) changed the leaves")
            }
        }
    }


    // MARK: - Size guards

    /// Gap surgery grows trees, so it meets the same push-boundary caps as any
    /// other `.code` result. Nothing special is needed for that — the point of the
    /// test is that an over-large result is *refused and reported*, not that it
    /// crashes or silently lands.
    @Test func `an oversized result is refused at the push boundary`() {
        let inty = Interpreter.recordingProvenance()
        inty.config.maxCodePoints = 4
        inty.stacks[.code]!.prepend(contentsOf:
            [CodeItem([IntItem(7), IntItem(8), IntItem(9)]),          // insert (top)
             CodeItem([IntItem(1), IntItem(2), IntItem(3)])] as [any Item])   // subject
        inty.stacks[.int]!.prepend(IntItem(0))
        doThis(.codeInsertAtGap, to: inty)

        #expect(stackString(inty, .code) == "[ ]", "the 6-leaf result did not land")
        #expect(stackString(inty, .error) != "[ ]", "and it said why")
    }


    // MARK: - Provenance

    /// Law 3 — arguments in written order, instruction last. The cut is law 5 as
    /// well, and `Behavior.selecting` clears siblings in both directions, so both
    /// of its fragments compose. The round-trip and composition sweeps enroll all
    /// four automatically; these pin the recorded text.
    @Test func `the gap instructions record what rebuilds them`() {
        let cut = Interpreter.recordingProvenance()
        cut.stacks[.code]!.prepend(nested)
        cut.stacks[.int]!.prepend(IntItem(3))
        doThis(.codeCutAtGap, to: cut)
        #expect(callString(topItem(cut, .code))
                == "( ( 1 ( 2 3 ) 4 ) 3 .codeCutAtGap .codeSwap .codePop )",
                "the top piece clears the sibling beneath it")
        #expect(callString(probeItemOnStack(cut, .code, index: 1)!)
                == "( ( 1 ( 2 3 ) 4 ) 3 .codeCutAtGap 1 .codePopItems )")

        let wrap = Interpreter.recordingProvenance()
        wrap.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2)]))
        wrap.stacks[.int]!.prepend(contentsOf: [IntItem(2), IntItem(0)] as [any Item])
        doThis(.codeWrapRange, to: wrap)
        // `0 2`, not `2 0`: the record names the ints in *written* order, deepest
        // first. Recording them the other way round is invisible to the value —
        // the pair gets sorted — and shows up only as a crux that is not a fixed
        // point, which is how the fuzzer caught it.
        #expect(callString(topItem(wrap, .code)) == "( ( 1 2 ) 0 2 .codeWrapRange )")
    }
}
