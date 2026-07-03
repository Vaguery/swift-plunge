//
//  Combinator Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/7/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct CombinatorBehaviorTests {

    let inty = Interpreter()

    @Test func `combinator DeepDup works`() {
        loadInts(inty, ints: [2, 10, 0, -4, 4])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ 2 10 0 -4 4 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.2 2.2 3.3 4.4 ]")
        #expect(topItem(inty, .double).isContingent == false )

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.2 2.2 3.3 4.4 ]")
        #expect(
            (probeItemOnStack(inty, .double, index: 2) as! DoubleItem
            ).isContingent == true
        )

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.2 2.2 3.3 4.4 4.4 ]")
        #expect(topItem(inty, .double).isContingent == true )

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.2 2.2 3.3 4.4 4.4 4.4 ]")
        #expect(topItem(inty, .double).isContingent == true )

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.2 2.2 2.2 3.3 4.4 4.4 4.4 ]")
        #expect(topItem(inty, .double).isContingent == true )
    }

    @Test func `combinator Dup works`() {
        //MARK: verify this is what is expected
        loadInts(inty, ints: [11, 22])
        #expect(stackString(inty, .int) == "[ 11 22 ]")

        doThis(.intDup, to: inty)
        #expect(stackString(inty, .int) == "[ 11 11 22 ]")
    }

    // contingency
    @Test func `combinator DupItems works`() {
        loadInts(inty, ints: [2,0,-5, 9])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ 2 0 -5 9 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleDupItems, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.2 1.1 2.2 3.3 4.4 ]")
        #expect(topItem(inty, .double).isContingent == false )

        doThis(.doubleDupItems, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.2 1.1 2.2 3.3 4.4 ]")
        #expect(
            (probeItemOnStack(inty, .double, index: 1) as! DoubleItem
            ).isContingent == false
        )
        doThis(.doubleDupItems, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.2 1.1 2.2 3.3 4.4 ]")
        #expect(topItem(inty, .double).isContingent == false )
    }

    // contingency
    @Test func `combinator DupTimes works`() {
        loadInts(inty, ints: [2,0,-5])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ 2 0 -5 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 1.1 2.2 3.3 4.4 ]")
        #expect(topItem(inty, .double).isContingent == false )

        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 1.1 2.2 3.3 4.4 ]")
        #expect(topItem(inty, .double).isContingent == false )
    }

    // contingency
    @Test func `combinator DupTimes handles overflow`() {
        loadInts(inty, ints: [3_000_000_000])
        loadDoubles(inty, doubles: [1.1])
        #expect(stackString(inty, .int) == "[ 3000000000 ]")
        #expect(stackString(inty, .double) == "[ 1.1 ]")

        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 ]")
        #expect(stackString(inty, .error).contains("doubleDupTimes overflow") )
    }

    @Test func `combinator Empty works`() {
        loadBools(inty, bools: [])
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.boolEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.boolEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func `combinator Eq works`() {
        loadInts(inty, ints: [9, 38, 4, -4, -7, -7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 38 4 -4 -7 -7 ]")

        doThis(.intEq, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -4 -7 -7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.intEq, to: inty)
        #expect(stackString(inty, .int) == "[ -7 -7 ]")
        #expect(stackString(inty, .bool) == "[ false false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.intEq, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ true false false ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func `combinator Flush works`() {
        loadInts(inty, ints: [11, 22], contingent: [1])
        #expect(stackString(inty, .int) == "[ 11 22 ]")

        doThis(.intFlush, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `combinator Pop works`() {
        loadInts(inty, ints: [11, 22], contingent: [1])
        #expect(stackString(inty, .int) == "[ 11 22 ]")

        doThis(.intPop, to: inty)
        #expect(stackString(inty, .int) == "[ 22 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func `combinator Rot works`() {

        loadInts(inty, ints: [11, 55, 999], contingent: [1])
        #expect(stackString(inty, .int) == "[ 11 55 999 ]")

        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 999 11 55 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 55 999 11 ]")
        #expect(topItem(inty, .int).isContingent == true)

        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 11 55 999 ]")
        #expect(topItem(inty, .int).isContingent == false)

    }

    // contingency
    @Test func `combinator Shove works`() {
        loadInts(inty, ints: [-3, 2, 17, 0, 2])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ -3 2 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 2 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 2.2 3.3 1.1 4.4 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 0 2 ]")
        #expect(stackString(inty, .double) == "[ 3.3 1.1 2.2 4.4 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 2 ]")
        #expect(stackString(inty, .double) == "[ 3.3 1.1 2.2 4.4 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")
        #expect(topItem(inty, .double).isContingent == true )
    }

    // contingency
    @Test func `combinator StackDepth works`() {
        loadInts(inty, ints: [11, 22], contingent: [1])
        #expect(stackString(inty, .int) == "[ 11 22 ]")

        doThis(.intStackDepth, to: inty)
        #expect(stackString(inty, .int) == "[ 2 11 22 ]")
        #expect(topItem(inty, .int).isContingent == true)

        doThis(.intStackDepth, to: inty)
        #expect(stackString(inty, .int) == "[ 3 2 11 22 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func `combinator Swap works`() {
        loadInts(inty, ints: [11, 22], contingent: [1])
        #expect(stackString(inty, .int) == "[ 11 22 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intSwap, to: inty)
        #expect(stackString(inty, .int) == "[ 22 11 ]")
        #expect(topItem(inty, .int).isContingent == true)

        loadStrings(inty, strings: ["", "abcd", "efgh"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" \"efgh\" ]")

        doThis(.stringSwap, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcd\" \"\" \"efgh\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringPop, to: inty)
        doThis(.stringSwap, to: inty)
        #expect(stackString(inty, .string) == "[ \"efgh\" \"\" ]")
        #expect(topItem(inty, .string).isContingent == false)
    }

    // contingency
    @Test func `combinator Yank works`() {
        loadInts(inty, ints: [-3, 2, 17, 0, 2])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ -3 2 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 3.3 1.1 2.2 4.4 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4 3.3 1.1 2.2 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4 3.3 1.1 2.2 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 4.4 3.3 2.2 ]")
        #expect(topItem(inty, .double).isContingent == true )
    }

    // contingency
    @Test func `combinator YankDup works`() {
        loadInts(inty, ints: [-3, 2, 17, 0, 2])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ -3 2 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 2.2 1.1 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4 2.2 1.1 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4 4.4 2.2 1.1 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 2.2 4.4 4.4 2.2 1.1 1.1 2.2 3.3 4.4 ]")
        #expect(topItem(inty, .double).isContingent == true )
    }

}
