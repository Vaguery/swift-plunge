//
//  VecDouble Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/15/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct VecDoubleBehaviorTests {

    var inty = Interpreter.recordingProvenance()

    @Test func vecDoubleButLast() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([1,2,3]),
                         VecDoubleItem([9,99,999])
                        ])
        
        doThis(.vecDoubleButLast, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [1.0, 2.0, 3.0] [9.0, 99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [] .vecDoubleButLast )")

        doThis(.vecDoublePop, to: inty)
        
        doThis(.vecDoubleButLast, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [1.0, 2.0] [9.0, 99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [1.0, 2.0, 3.0] .vecDoubleButLast )")
        
        doThis(.vecDoublePop, to: inty)
        
        doThis(.vecDoubleButLast, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] .vecDoubleButLast )")
    }
    
    @Test func vecDoubleConcat() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([1,2,3]),
                         VecDoubleItem([9,99,999])
                        ])
        
        doThis(.vecDoubleConcat, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [1.0, 2.0, 3.0] [9.0, 99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [1.0, 2.0, 3.0] [] .vecDoubleConcat )")
        
        doThis(.vecDoubleConcat, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0, 1.0, 2.0, 3.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] [1.0, 2.0, 3.0] .vecDoubleConcat )")
    }

    @Test func vecDoubleConj() {
        loadDoubles(inty, doubles: [-3, 0, 1])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999])
                        ])

        doThis(.vecDoubleConj, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [-3.0] [9.0, 99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [] -3.0 .vecDoubleConj )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleConj, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0, 0.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] 0.0 .vecDoubleConj )")

        doThis(.vecDoubleConj, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0, 0.0, 1.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0, 0.0] 1.0 .vecDoubleConj )")
    }

    @Test func vecDoubleContains() {
        // Non-destructive: reads the vector and the needle and leaves both, so the
        // crux pops both to reproduce just the bool.
        loadDoubles(inty, doubles: [9])
        inty.stacks[.vecDouble]!.prepend(VecDoubleItem([9, 99, 999]))
        doThis(.vecDoubleContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0] ]", "the vector survives the read")
        #expect(stackString(inty, .double) == "[ 9.0 ]", "the needle survives the read")
        #expect(callString(topItem(inty, .bool)) == "( [9.0, 99.0, 999.0] 9.0 .vecDoubleContains 1 .doublePopItems 1 .vecDoublePopItems )")

        let miss = Interpreter.recordingProvenance()
        miss.stacks[.vecDouble]!.prepend(VecDoubleItem([]))
        miss.stacks[.double]!.prepend(DoubleItem(7777))
        doThis(.vecDoubleContains, to: miss)
        #expect(stackString(miss, .bool) == "[ false ]")
    }

    @Test func vecDoubleDrop() {
        loadInts(inty, ints: [-3, 0, 1])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999])
                        ])

        doThis(.vecDoubleDrop, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [] -3 .vecDoubleDrop )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleDrop, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] 0 .vecDoubleDrop )")

        doThis(.vecDoubleDrop, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] 1 .vecDoubleDrop )")
    }

    @Test func vecDoubleFirst() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999])
                        ])

        doThis(.vecDoubleFirst, to: inty)
        #expect(stackString(inty, .double) == "[ ]")

        doThis(.vecDoubleFirst, to: inty)
        #expect(stackString(inty, .double) == "[ 9.0 ]")
        #expect(callString(topItem(inty, .double)) == "( [9.0, 99.0, 999.0] .vecDoubleFirst )")
    }

    @Test func vecDoubleIndexOf() {
        // The index lands on .int, a different stack from the .double needle, so a
        // plain PopItems cleans up each read stack.
        loadDoubles(inty, doubles: [99])
        inty.stacks[.vecDouble]!.prepend(VecDoubleItem([9, 99, 999]))
        doThis(.vecDoubleIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 ]", "the index")
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0] ]", "the vector survives")
        #expect(stackString(inty, .double) == "[ 99.0 ]", "the needle survives")
        #expect(callString(topItem(inty, .int)) == "( [9.0, 99.0, 999.0] 99.0 .vecDoubleIndexOf 1 .doublePopItems 1 .vecDoublePopItems )")

        let absent = Interpreter.recordingProvenance()
        absent.stacks[.vecDouble]!.prepend(VecDoubleItem([9, 99, 999]))
        absent.stacks[.double]!.prepend(DoubleItem(7777))
        doThis(.vecDoubleIndexOf, to: absent)
        #expect(stackString(absent, .int) == "[ ]", "absent: an error, not -1")
        #expect((topItem(absent, .error) as? ErrorItem)?.kind == .notFound)
    }

    @Test func vecDoubleItemIsEmpty() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999])
                        ])
        
        doThis(.vecDoubleItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]", "the vector survives")
        #expect(callString(topItem(inty, .bool)) == "( [] .vecDoubleItemIsEmpty 1 .vecDoublePopItems )")

        doThis(.vecDoublePop, to: inty)   // discard the empty to reach the next vector

        doThis(.vecDoubleItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( [9.0, 99.0, 999.0] .vecDoubleItemIsEmpty 1 .vecDoublePopItems )")
    }

    @Test func `vecDoubleIterate records provenance only for its derived results`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([4, 55]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [4.0, 55.0] ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        // The instruction only builds the iterator; `.iteratorPlay` does the work.
        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")

        // The whole vector goes INTO the iterator and stays there. It used to
        // re-push a *shrunken* copy every pass, which was the one derived value
        // here and recorded `[previous, .vecDoubleRest]` — a level deeper per
        // element, O(n) in the vector's length. There is no shrinking now, so
        // there is nothing to record: `.vecDoubleRest` is named by nothing.
        inty.step()
        #expect(stackString(inty, .double) == "[ 4.0 ]")
        #expect(inty.stacks[.exec]!.count == 3)
        #expect(inty.stacks[.exec]![0].call.isEmpty)   // mouse, to run
        #expect(inty.stacks[.exec]![1].call.isEmpty)   // .codeDo
        #expect(inty.stacks[.exec]![2].call.isEmpty)   // .iteratorPlay

        // The element is honestly the vector's 1st, and says so without depending
        // on how many passes have run.
        #expect(CodeItem(topItem(inty, .double).crux()).pretty()
            == "( [4.0, 55.0] 0 .vecDoubleNth )")
    }

    @Test func `vecDoubleIterate works for >1 item`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([4, 55]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [4.0, 55.0] ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()   // first pass: element 4.0, then the mouse
        #expect(stackString(inty, .double) == "[ 4.0 ]")
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .codeDo .iteratorPlay ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .boolNot .iteratorPlay ]")

        inty.step()   // the mouse runs
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()   // second and last pass: element 55.0, and the loop is done
        #expect(stackString(inty, .double) == "[ 55.0 4.0 ]")
        // The body waits under the last pass, and returns to .code after it.
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo ( .boolNot ) ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    @Test func `vecDoubleIterate works for empty`() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [] ]")
        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
    }

    @Test func `vecDoubleIterate works for one item`() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([55]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [55.0] ]")
        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")

        // One element, so one pass and no continuation: the iterator is spent as
        // soon as it is played, and never comes to rest.
        inty.step()
        #expect(stackString(inty, .double) == "[ 55.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        // The body waits under the last pass, and returns to .code after it.
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo ( .boolNot ) ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    @Test func vecDoubleLast() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999])
                        ])

        doThis(.vecDoubleLast, to: inty)
        #expect(stackString(inty, .double) == "[ ]")

        doThis(.vecDoubleLast, to: inty)
        #expect(stackString(inty, .double) == "[ 999.0 ]")
        #expect(callString(topItem(inty, .double)) == "( [9.0, 99.0, 999.0] .vecDoubleLast )")
    }

    @Test func vecDoubleLength() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999])
                        ])
        
        // Non-destructive: the vector is read, not consumed. It stays on
        // .vecDouble, and the crux pops what it read so it reproduces only the count.
        doThis(.vecDoubleLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]")   // both survive
        #expect(callString(topItem(inty, .int)) == "( [] .vecDoubleLength 1 .vecDoublePopItems )")

        doThis(.vecDoublePop, to: inty)   // discard the empty to reach the next vector

        doThis(.vecDoubleLength, to: inty)
        #expect(stackString(inty, .int) == "[ 3 0 ]")
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0] ]")   // still there
        #expect(callString(topItem(inty, .int)) == "( [9.0, 99.0, 999.0] .vecDoubleLength 1 .vecDoublePopItems )")
    }
    
    @Test func vecDoubleNth() {
        loadInts(inty, ints: [-3, 1, 7776])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999]),
                         VecDoubleItem([9,99,999])
                        ])

        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] [9.0, 99.0, 999.0] ]")
        #expect(stackString(inty, .int) == "[ -3 1 7776 ]")

        doThis(.vecDoubleNth, to: inty)
        #expect(stackString(inty, .double) == "[ ]")

        doThis(.vecDoubleNth, to: inty)
        #expect(stackString(inty, .double) == "[ 99.0 ]")
        #expect(callString(topItem(inty, .double)) == "( [9.0, 99.0, 999.0] 1 .vecDoubleNth )")

        doThis(.vecDoubleNth, to: inty)
        #expect(stackString(inty, .double) == "[ 999.0 99.0 ]", "past the end is the last element")
        #expect(callString(topItem(inty, .double)) == "( [9.0, 99.0, 999.0] 7776 .vecDoubleNth )")
    }

    @Test func vecDoubleOccurrencesOf() {
        loadDoubles(inty, doubles: [9])
        inty.stacks[.vecDouble]!.prepend(VecDoubleItem([9, 9, 9, 9, 9]))
        doThis(.vecDoubleOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 5 ]")
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 9.0, 9.0, 9.0, 9.0] ]", "the vector survives")
        #expect(stackString(inty, .double) == "[ 9.0 ]", "the needle survives")
        #expect(callString(topItem(inty, .int)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] 9.0 .vecDoubleOccurrencesOf 1 .doublePopItems 1 .vecDoublePopItems )")

        let none = Interpreter.recordingProvenance()
        none.stacks[.vecDouble]!.prepend(VecDoubleItem([9, 9, 9, 9, 9]))
        none.stacks[.double]!.prepend(DoubleItem(-99))
        doThis(.vecDoubleOccurrencesOf, to: none)
        #expect(stackString(none, .int) == "[ 0 ]")
    }

    @Test func vecDoublePushAll() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([1,22,333]),
                        ])

        // An empty vector yields nothing at all — not even an iterator.
        doThis(.vecDoublePushAll, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .iterator) == "[ ]")

        // It emits one element per pass now, so nothing appears until it runs.
        doThis(.vecDoublePushAll, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        inty.run(stepLimit: 10_000)

        // Front to back, so 333.0 was pushed last and is on top — the reverse of
        // what it used to be, deliberately: collections are walked
        // front-to-back.
        #expect(stackString(inty, .double) == "[ 333.0 22.0 1.0 ]")

        // Each element names its own index rather than how far down a pile it
        // landed, so this record says nothing about the other two.
        #expect(callString(topItem(inty, .double)) == "( [1.0, 22.0, 333.0] 2 .vecDoubleNth )")
        doThis(.doublePop, to: inty)
        #expect(CodeItem(topItem(inty, .double).crux()).pretty()
            == "( [1.0, 22.0, 333.0] 1 .vecDoubleNth )")
    }

    @Test func vecDoubleRemove() {
        loadDoubles(inty, doubles: [9, 9, -99])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,8,7,6,9]),
                         VecDoubleItem([9,9,9,9,9])
                        ])

        doThis(.vecDoubleRemove, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [] 9.0 .vecDoubleRemove )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleRemove, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [8.0, 7.0, 6.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 8.0, 7.0, 6.0, 9.0] 9.0 .vecDoubleRemove )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleRemove, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] -99.0 .vecDoubleRemove )")
    }

    @Test func vecDoubleReplace() {
        loadDoubles(inty, doubles: [1, 9, 1.0, 9.0, 2, 9])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9.0,8.0,7.0,6.0,9.0]),
                         VecDoubleItem([9,9,9,9,9])
                        ])

        doThis(.vecDoubleReplace, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [] 9.0 1.0 .vecDoubleReplace )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplace, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [1.0, 8.0, 7.0, 6.0, 1.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 8.0, 7.0, 6.0, 9.0] 9.0 1.0 .vecDoubleReplace )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplace, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [2.0, 2.0, 2.0, 2.0, 2.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] 9.0 2.0 .vecDoubleReplace )")
    }

    @Test func vecDoubleReplaceFirst() {
        loadDoubles(inty, doubles: [1, 9, 1.0, 9.0, 3, 9])
       inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,8,7,6,9]),
                         VecDoubleItem([9,9,9,9,9])
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1), DoubleItem(9),
                         DoubleItem(1), DoubleItem(9),
                         DoubleItem(3), DoubleItem(9),
                        ])

        doThis(.vecDoubleReplaceFirst, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [] 9.0 1.0 .vecDoubleReplaceFirst )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplaceFirst, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [1.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 8.0, 7.0, 6.0, 9.0] 9.0 1.0 .vecDoubleReplaceFirst )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplaceFirst, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [3.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] 9.0 3.0 .vecDoubleReplaceFirst )")
    }

    @Test func vecDoubleRest() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999])
                        ])
        
        doThis(.vecDoubleRest, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [] .vecDoubleRest )")
        
        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleRest, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] .vecDoubleRest )")
    }
    
    @Test func vecDoubleReverse() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999])
                        ])
        
        doThis(.vecDoubleReverse, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [] .vecDoubleReverse )")
        
        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReverse, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [999.0, 99.0, 9.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] .vecDoubleReverse )")
    }

    @Test func vecDoubleSet() {
        loadDoubles(inty, doubles: [9, 3, -1])
        loadInts(inty, ints: [1, 2222, 2])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,8,7,6,9]),
                         VecDoubleItem([9,9,9,9,9])
                        ])


        // An empty vector has no element to replace: an error, arguments consumed.
        doThis(.vecDoubleSet, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect((topItem(inty, .error) as? ErrorItem)?.kind == .emptyCollection)
        #expect(callString(topItem(inty, .error)) == "( [] 9.0 1 .vecDoubleSet )")

        doThis(.vecDoubleSet, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 8.0, 7.0, 6.0, 3.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]", "2222 clamps to the last")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 8.0, 7.0, 6.0, 9.0] 3.0 2222 .vecDoubleSet )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSet, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 9.0, -1.0, 9.0, 9.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] -1.0 2 .vecDoubleSet )")
    }

    @Test func vecDoubleSubVec() {
        loadInts(inty, ints: [1, 9, 3, 2, 2, -1, 1, 1])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,8,7,6,9]),
                         VecDoubleItem([9,9,9,9,9]),
                         VecDoubleItem([1,11,111,1111])
                        ])

        doThis(.vecDoubleSubVec, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] [1.0, 11.0, 111.0, 1111.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [] 9 1 .vecDoubleSubVec )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSubVec, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [7.0, 6.0] [9.0, 9.0, 9.0, 9.0, 9.0] [1.0, 11.0, 111.0, 1111.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 8.0, 7.0, 6.0, 9.0] 2 3 .vecDoubleSubVec )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSubVec, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 9.0, 9.0] [1.0, 11.0, 111.0, 1111.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] -1 2 .vecDoubleSubVec )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSubVec, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [11.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [1.0, 11.0, 111.0, 1111.0] 1 1 .vecDoubleSubVec )")
    }

    @Test func vecDoubleTake() {
        loadInts(inty, ints: [-3, 99, 1])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999])
                        ])

        doThis(.vecDoubleTake, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [] -3 .vecDoubleTake )")
        
        doThis(.vecDoublePop, to: inty)
        
        doThis(.vecDoubleTake, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] 99 .vecDoubleTake )")
        
        doThis(.vecDoubleTake, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0] ]")
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] 1 .vecDoubleTake )")
    }

}
