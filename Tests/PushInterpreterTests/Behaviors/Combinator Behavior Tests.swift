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

    @Test func boolEmpty() {
        loadBools(inty, bools: [])
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.boolEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.boolEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func codeEq() {
        intyCode6IB(inty)
        #expect(stackString(inty, .code) == "[ ( 4 false ) ( 4 false ) ( 4 false ) ( 4 false ) ( 5 false ) ( 4 true ) ]")

        doThis(.codeEq, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.codeEq, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.codeEq, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func doubleDeepDup() {
        loadInts(inty, ints: [2,10,0,-4,4])
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

    // contingency
    @Test func doubleDupItems() {
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
    @Test func doubleDupTimes() {
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
    @Test func `doubleDupTimes does not overflow`() {
        loadInts(inty, ints: [3_000_000_000])
        loadDoubles(inty, doubles: [1.1])
        #expect(stackString(inty, .int) == "[ 3000000000 ]")
        #expect(stackString(inty, .double) == "[ 1.1 ]")

        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 ]")
        #expect(stackString(inty, .error).contains("doubleDupTimes overflow") )
    }

    // contingency
    @Test func doubleShove() {
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
    @Test func doubleYank() {
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
    @Test func doubleYankDup() {
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

    @Test func intFlush() {
        loadInts(inty, ints: [11, 22], contingent: [1])
        #expect(stackString(inty, .int) == "[ 11 22 ]")

        doThis(.intFlush, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
     }

    @Test func intPop() {
        loadInts(inty, ints: [11, 22], contingent: [1])
        #expect(stackString(inty, .int) == "[ 11 22 ]")

        doThis(.intPop, to: inty)
        #expect(stackString(inty, .int) == "[ 22 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func intRot() {
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
    @Test func intStackDepth() {
        loadInts(inty, ints: [11, 22], contingent: [1])
        #expect(stackString(inty, .int) == "[ 11 22 ]")

        doThis(.intStackDepth, to: inty)
        #expect(stackString(inty, .int) == "[ 2 11 22 ]")
        #expect(topItem(inty, .int).isContingent == true)

        doThis(.intStackDepth, to: inty)
        #expect(stackString(inty, .int) == "[ 3 2 11 22 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func intSwap() {
        loadInts(inty, ints: [11, 22], contingent: [1])
        #expect(stackString(inty, .int) == "[ 11 22 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intSwap, to: inty)
        #expect(stackString(inty, .int) == "[ 22 11 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

}
