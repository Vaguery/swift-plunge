//
//  VecInt Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/12/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct VecIntBehaviorTests {

    var inty = Interpreter()
    
    
    @Test func vecIntButLast() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([1,2,3]),
                         VecIntItem([9,99,999])
                        ])
        
        doThis(.vecIntButLast, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [1, 2, 3] [9, 99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [] .vecIntButLast )")

        doThis(.vecIntPop, to: inty)
        
        doThis(.vecIntButLast, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 2] [9, 99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [1, 2, 3] .vecIntButLast )")
        
        doThis(.vecIntPop, to: inty)
        
        doThis(.vecIntButLast, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] .vecIntButLast )")
    }
    
    @Test func vecIntConcat() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([1,2,3]),
                         VecIntItem([9,99,999])
                        ])
        
        doThis(.vecIntConcat, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 2, 3] [9, 99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [1, 2, 3] [] .vecIntConcat )")
        
        doThis(.vecIntConcat, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999, 1, 2, 3] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] [1, 2, 3] .vecIntConcat )")
    }

    @Test func vecIntConj() {
        loadInts(inty, ints: [-3, 0, 1])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999])
                        ])

        doThis(.vecIntConj, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [-3] [9, 99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [] -3 .vecIntConj )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntConj, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999, 0] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] 0 .vecIntConj )")

        doThis(.vecIntConj, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999, 0, 1] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999, 0] 1 .vecIntConj )")
    }

    @Test func vecIntContains() {
        // Non-destructive: reads the vector and the needle and leaves both, so the
        // crux pops both to reproduce just the bool.
        loadInts(inty, ints: [9])
        inty.stacks[.vecInt]!.prepend(VecIntItem([9, 99, 999]))
        doThis(.vecIntContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999] ]", "the vector survives the read")
        #expect(stackString(inty, .int) == "[ 9 ]", "the needle survives the read")
        #expect(callString(topItem(inty, .bool)) == "( [9, 99, 999] 9 .vecIntContains 1 .intPopItems 1 .vecIntPopItems )")

        // A miss on an empty vector.
        let miss = Interpreter()
        miss.stacks[.vecInt]!.prepend(VecIntItem([]))
        miss.stacks[.int]!.prepend(IntItem(7777))
        doThis(.vecIntContains, to: miss)
        #expect(stackString(miss, .bool) == "[ false ]")
        #expect(callString(topItem(miss, .bool)) == "( [] 7777 .vecIntContains 1 .intPopItems 1 .vecIntPopItems )")
    }

    @Test func vecIntDrop() {
        loadInts(inty, ints: [-3, 0, 1])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999])
                        ])

        doThis(.vecIntDrop, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [] -3 .vecIntDrop )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntDrop, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] 0 .vecIntDrop )")

        doThis(.vecIntDrop, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] 1 .vecIntDrop )")
    }

    @Test func vecIntFirst() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999])
                        ])

        doThis(.vecIntFirst, to: inty)
        #expect(stackString(inty, .int) == "[ ]")

        doThis(.vecIntFirst, to: inty)
        #expect(stackString(inty, .int) == "[ 9 ]")
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] .vecIntFirst )")
    }

    @Test func vecIntIndexOf() {
        // The index lands back on .int, on top of the needle it read — so the crux
        // swaps the result up past the needle (rather than a plain PopItems, which
        // would discard the result) and then pops the vector.
        loadInts(inty, ints: [99])
        inty.stacks[.vecInt]!.prepend(VecIntItem([9, 99, 999]))
        doThis(.vecIntIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 99 ]", "the index, atop the surviving needle")
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999] ]", "the vector survives")
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] 99 .vecIntIndexOf .intSwap .intPop 1 .vecIntPopItems )")

        // Absent → -1.
        let absent = Interpreter()
        absent.stacks[.vecInt]!.prepend(VecIntItem([9, 99, 999]))
        absent.stacks[.int]!.prepend(IntItem(7777))
        doThis(.vecIntIndexOf, to: absent)
        #expect(stackString(absent, .int) == "[ -1 7777 ]")
    }

    @Test func vecIntItemIsEmpty() {
        // Non-destructive: reads the vector, leaves it, and the crux pops it.
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999])
                        ])

        doThis(.vecIntItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]", "the vector survives")
        #expect(callString(topItem(inty, .bool)) == "( [] .vecIntItemIsEmpty 1 .vecIntPopItems )")

        doThis(.vecIntPop, to: inty)   // discard the empty to reach the next vector

        doThis(.vecIntItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( [9, 99, 999] .vecIntItemIsEmpty 1 .vecIntPopItems )")
    }

    @Test func `vecIntIterate records provenance only for its derived results`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([4, 55]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .vecInt) == "[ [4, 55] ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        // The instruction only builds the iterator; `.iteratorPlay` does the work.
        doThis(.vecIntIterate, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «[4, 55] @0 ( .boolNot )» ]")
        #expect(inty.stacks[.exec]!.count == 1)

        // The whole vector goes INTO the iterator and stays there. It used to
        // re-push a *shrunken* copy every pass, which was the one derived value
        // here and recorded `[previous, .vecIntRest]` — a level deeper per
        // element, O(n) in the vector's length. There is no shrinking now, so
        // there is nothing to record: `.vecIntRest` is named by nothing.
        inty.step()
        #expect(stackString(inty, .int) == "[ 4 ]")
        #expect(inty.stacks[.exec]![0].call.isEmpty)   // mouse, to run
        #expect(inty.stacks[.exec]![1].call.isEmpty)   // .codeDo
        #expect(inty.stacks[.exec]![2].call.isEmpty)   // .iteratorPlay

        // The element is honestly the vector's 2nd item, and says so in a way
        // that does not depend on how many passes have run.
        #expect(CodeItem(topItem(inty, .int).crux()).pretty()
            == "( [4, 55] 0 .vecIntNth )")
    }

    /// Each element names its own index, so the last one costs no more to explain
    /// than the first — which is the point of holding the vector still and moving
    /// a cursor instead of shrinking a copy.
    @Test func `vecIntIterate elements record their own index`() {
        inty.stacks[.vecInt]!.prepend(VecIntItem([4, 55, 666]))
        inty.stacks[.code]!.prepend(CodeItem([]))
        doThis(.vecIntIterate, to: inty)
        inty.run(stepLimit: 10_000)

        #expect(stackString(inty, .int) == "[ 666 55 4 ]")
        #expect(CodeItem(topItem(inty, .int).crux()).pretty()
            == "( [4, 55, 666] 2 .vecIntNth )")
        #expect(topItem(inty, .int).callWeight == inty.stacks[.int]![2].callWeight)
    }

    @Test func `vecIntIterate works for >1 item`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([4, 55]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .vecInt) == "[ [4, 55] ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecIntIterate, to: inty)
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()   // first pass: element 4, then the mouse
        #expect(stackString(inty, .int) == "[ 4 ]")
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «[4, 55] @1 ( .boolNot )» ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .code) == "[ ( .boolNot ) ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .boolNot .iteratorPlay ]")

        inty.step()   // the mouse runs
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()   // second and last pass: element 55, and the loop is done
        #expect(stackString(inty, .int) == "[ 55 4 ]")
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    @Test func `vecIntIterate works for empty`() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .vecInt) == "[ [] ]")
        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.vecIntIterate, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")

    }

    @Test func `vecIntIterate works for one item`() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([88]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .vecInt) == "[ [88] ]")
        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.vecIntIterate, to: inty)
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")

        // One element, so one pass and no continuation: the iterator is spent as
        // soon as it is played, and never comes to rest.
        inty.step()
        #expect(stackString(inty, .int) == "[ 88 ]")
        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    @Test func vecIntLast() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999])
                        ])

        doThis(.vecIntLast, to: inty)
        #expect(stackString(inty, .int) == "[ ]")

        doThis(.vecIntLast, to: inty)
        #expect(stackString(inty, .int) == "[ 999 ]")
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] .vecIntLast )")
    }

    @Test func vecIntLength() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999])
                        ])
        
        // Non-destructive: the vector is read, not consumed. It stays on .vecInt,
        // and the crux pops what it read so it still reproduces only the count.
        doThis(.vecIntLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]")   // both survive the read
        #expect(callString(topItem(inty, .int)) == "( [] .vecIntLength 1 .vecIntPopItems )")

        doThis(.vecIntPop, to: inty)   // discard the empty to reach the next vector

        doThis(.vecIntLength, to: inty)
        #expect(stackString(inty, .int) == "[ 3 0 ]")
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999] ]")   // still there after the read
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] .vecIntLength 1 .vecIntPopItems )")
    }

    @Test func vecIntNth() {
        loadInts(inty, ints: [-3, 1, 7777])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999]),
                         VecIntItem([9,99,999])
                        ])

        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] [9, 99, 999] ]")
        #expect(stackString(inty, .int) == "[ -3 1 7777 ]")

        doThis(.vecIntNth, to: inty)
        #expect(stackString(inty, .int) == "[ 1 7777 ]")
        #expect(callString(topItem(inty, .int)) == "( )")

        doThis(.vecIntNth, to: inty)
        #expect(stackString(inty, .int) == "[ 99 7777 ]")
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] 1 .vecIntNth )")

        doThis(.intPop, to: inty)

        doThis(.vecIntNth, to: inty)
        #expect(stackString(inty, .int) == "[ 99 ]")
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] 7777 .vecIntNth )")
    }

    @Test func `vecIntNth handles Int.min index without trapping`() {
        // abs(Int.min) traps; .magnitude does not. magnitude(Int.min) % 3 == 2
        loadInts(inty, ints: [Int.min])
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem([9, 99, 999])])

        doThis(.vecIntNth, to: inty)
        #expect(stackString(inty, .int) == "[ 999 ]")
    }

    @Test func `vecIntSet handles Int.min index without trapping`() {
        // position is popped first (top), replacement second.
        // magnitude(Int.min) % 5 == 3
        loadInts(inty, ints: [Int.min, 42])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([9, 99, 999, 9999, 99999])])

        doThis(.vecIntSet, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999, 42, 99999] ]")
    }

    @Test func vecIntOccurrencesOf() {
        // The count lands back on .int atop the surviving needle, so the crux
        // swaps it up past the needle (like indexOf) and pops the vector.
        loadInts(inty, ints: [9])
        inty.stacks[.vecInt]!.prepend(VecIntItem([9, 9, 9, 9, 9]))
        doThis(.vecIntOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 5 9 ]", "the count, atop the surviving needle")
        #expect(stackString(inty, .vecInt) == "[ [9, 9, 9, 9, 9] ]", "the vector survives")
        #expect(callString(topItem(inty, .int)) == "( [9, 9, 9, 9, 9] 9 .vecIntOccurrencesOf .intSwap .intPop 1 .vecIntPopItems )")

        // None present → 0.
        let none = Interpreter()
        none.stacks[.vecInt]!.prepend(VecIntItem([9, 9, 9, 9, 9]))
        none.stacks[.int]!.prepend(IntItem(-99))
        doThis(.vecIntOccurrencesOf, to: none)
        #expect(stackString(none, .int) == "[ 0 -99 ]")
    }

    @Test func vecIntPushAll() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([1,22,333]),
                        ])

        // An empty vector yields nothing at all — not even an iterator.
        doThis(.vecIntPushAll, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .iterator) == "[ ]")

        // It emits one element per pass now, so nothing appears until it runs.
        doThis(.vecIntPushAll, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        inty.run(stepLimit: 10_000)

        // Front to back, so 333 was pushed last and is on top — this order is the
        // reverse of what it used to be, deliberately. See "Collections are walked
        // front-to-back" in "Notes on Push/Design Principles.md".
        #expect(stackString(inty, .int) == "[ 333 22 1 ]")

        // Each element names its own index rather than how far down a pile it
        // landed, so this record says nothing about the other two.
        #expect(callString(topItem(inty, .int)) == "( [1, 22, 333] 2 .vecIntNth )")
        doThis(.intPop, to: inty)
        #expect(CodeItem(topItem(inty, .int).crux()).pretty()
            == "( [1, 22, 333] 1 .vecIntNth )")
    }

    /// Builds a vector from computed scalars, using an existing vector purely as a
    /// **shape** — it never looks at the template's contents.
    ///
    /// The order is the inverse of `pushAll`, which is where it comes from: the
    /// first item popped becomes the LAST element. Read as source, `1 22 333`
    /// yields `[1, 22, 333]` — the order you wrote them.
    @Test func vecIntConstruct() {
        loadInts(inty, ints: [1, 22, 333])
        inty.stacks[.vecInt]!.prepend(VecIntItem([0, 0, 0]))   // a shape, not data
        #expect(stackString(inty, .int) == "[ 1 22 333 ]")

        doThis(.vecIntConstruct, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [333, 22, 1] ]")
        #expect(stackString(inty, .int) == "[ ]")   // all three consumed
        #expect(callString(topItem(inty, .vecInt))
            == "( [0, 0, 0] 333 22 1 .vecIntConstruct )")
    }

    /// The property that fixes the order: Construct undoes PushAll exactly.
    @Test func `vecIntConstruct is the inverse of vecIntPushAll`() {
        let original = VecIntItem([1, 22, 333])
        let inty = Interpreter()
        inty.load(program: [original, InstructionItem(.vecIntPushAll)])
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .int) == "[ 333 22 1 ]")

        // Any 3-element vector will do as the shape — it is never read.
        inty.stacks[.vecInt]!.prepend(VecIntItem([9, 9, 9]))
        inty.stacks[.exec]!.prepend(InstructionItem(.vecIntConstruct))
        inty.run(stepLimit: 10_000)

        #expect((topItem(inty, .vecInt) as? VecIntItem)?.value == original.value)
        #expect(stackString(inty, .int) == "[ ]")
    }

    /// Too few scalars and nothing happens.
    ///
    /// This once kept the all-or-nothing bargain by hand — the only Behavior that
    /// had to, because `takes:` could not say "N of these, where N depends on
    /// another argument". `.takesMany` says it, so the refusal now comes from
    /// `act` like every other, and reads like every other. The old wording
    /// counted ("wants 4 from .int, found 2"); the shared one does not, which is
    /// the price of no longer being a special case.
    @Test func `vecIntConstruct refuses rather than half-build`() {
        loadInts(inty, ints: [1, 2])
        inty.stacks[.vecInt]!.prepend(VecIntItem([0, 0, 0, 0]))   // wants 4, has 2

        doThis(.vecIntConstruct, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [0, 0, 0, 0] ]")   // never taken
        #expect(stackString(inty, .int) == "[ 1 2 ]")               // untouched
        #expect(errorStrings(inty).contains { $0.contains("vecIntConstruct missing args: .int") })
    }

    /// An empty template is the one case that needs nothing at all — and is how a
    /// program makes an empty vector.
    @Test func `vecIntConstruct with an empty template consumes nothing`() {
        loadInts(inty, ints: [7])
        inty.stacks[.vecInt]!.prepend(VecIntItem([]))

        doThis(.vecIntConstruct, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] ]")
        #expect(stackString(inty, .int) == "[ 7 ]")
    }

    /// The point of it: a vector's contents can now be **computed**, where before
    /// they could only ever be rearranged.
    @Test func `vecIntConstruct builds a vector out of computed elements`() {
        let inty = Interpreter()
        inty.load(program: [
            IntItem(2), IntItem(3), InstructionItem(.intAdd),      // 5
            IntItem(10), IntItem(4), InstructionItem(.intSubtract), // 6
            VecIntItem([0, 0]),
            InstructionItem(.vecIntConstruct),
        ])
        inty.run(stepLimit: 10_000)

        #expect((topItem(inty, .vecInt) as? VecIntItem)?.value == [5, 6])
        // …and each element's own derivation survives into the vector's crux.
        #expect(CodeItem(topItem(inty, .vecInt).crux()).pretty()
            == "( [0, 0] 2 3 .intAdd 10 4 .intSubtract .vecIntConstruct )")
    }

    func errorStrings(_ inty: Interpreter) -> [String] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.value }
    }

    @Test func vecIntRemove() {
        loadInts(inty, ints: [9, 9, -99])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])

        doThis(.vecIntRemove, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 8, 7, 6, 9] [9, 9, 9, 9, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [] 9 .vecIntRemove )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntRemove, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [8, 7, 6] [9, 9, 9, 9, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 8, 7, 6, 9] 9 .vecIntRemove )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntRemove, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 9, 9, 9, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 9, 9, 9, 9] -99 .vecIntRemove )")
    }

    @Test func vecIntReplace() {
        loadInts(inty, ints: [1, 9, 1, 9, 2, 9])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])

        doThis(.vecIntReplace, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 8, 7, 6, 9] [9, 9, 9, 9, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [] 9 1 .vecIntReplace )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplace, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 8, 7, 6, 1] [9, 9, 9, 9, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 8, 7, 6, 9] 9 1 .vecIntReplace )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplace, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [2, 2, 2, 2, 2] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 9, 9, 9, 9] 9 2 .vecIntReplace )")
    }

    @Test func vecIntReplaceFirst() {
        loadInts(inty, ints: [1, 9, 1, 9, 3, 9])
       inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])

        doThis(.vecIntReplaceFirst, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 8, 7, 6, 9] [9, 9, 9, 9, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [] 9 1 .vecIntReplaceFirst )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplaceFirst, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 8, 7, 6, 9] [9, 9, 9, 9, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 8, 7, 6, 9] 9 1 .vecIntReplaceFirst )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplaceFirst, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [3, 9, 9, 9, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 9, 9, 9, 9] 9 3 .vecIntReplaceFirst )")
    }

    @Test func vecIntRest() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999])
                        ])
        
        doThis(.vecIntRest, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [] .vecIntRest )")
        
        doThis(.vecIntPop, to: inty)

        doThis(.vecIntRest, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] .vecIntRest )")
    }

    @Test func vecIntReverse() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999])
                        ])
        
        doThis(.vecIntReverse, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [] .vecIntReverse )")
        
        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReverse, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [999, 99, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] .vecIntReverse )")
    }

    @Test func vecIntSet() {
        loadInts(inty, ints: [1, 9, 3, 2222, 7, -1])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])

        doThis(.vecIntSet, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 8, 7, 6, 9] [9, 9, 9, 9, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [] 9 1 .vecIntSet )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSet, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 8, 7, 2222, 9] [9, 9, 9, 9, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 8, 7, 6, 9] 2222 3 .vecIntSet )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSet, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 9, -1, 9, 9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 9, 9, 9, 9] -1 7 .vecIntSet )")
    }

    @Test func vecIntSubVec() {
        loadInts(inty, ints: [1, 9, 3, 2, 2, -1, 1, 1])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9]),
                         VecIntItem([1,11,111,1111])
                        ])

        doThis(.vecIntSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 8, 7, 6, 9] [9, 9, 9, 9, 9] [1, 11, 111, 1111] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [] 9 1 .vecIntSubVec )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [7, 6] [9, 9, 9, 9, 9] [1, 11, 111, 1111] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 8, 7, 6, 9] 2 3 .vecIntSubVec )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 9, 9] [1, 11, 111, 1111] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 9, 9, 9, 9] -1 2 .vecIntSubVec )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [11] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [1, 11, 111, 1111] 1 1 .vecIntSubVec )")
    }

    @Test func vecIntTake() {
        loadInts(inty, ints: [-3, 99, 1])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999])
                        ])

        doThis(.vecIntTake, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [] -3 .vecIntTake )")
        
        doThis(.vecIntPop, to: inty)
        
        doThis(.vecIntTake, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] 99 .vecIntTake )")
        
        doThis(.vecIntTake, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9] ]")
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] 1 .vecIntTake )")
    }
    
}
