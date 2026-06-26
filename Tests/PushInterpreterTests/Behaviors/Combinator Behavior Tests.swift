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
        intyBoolE(inty)
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

    // contingency
    @Test func doubleDeepDup() {
        intyInt5(inty)
        intyDouble4(inty)

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 1111111.11 66.6 -33.0 -33.0 ]")

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 1111111.11 66.6 66.6 -33.0 -33.0 ]")

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 0.0 1111111.11 66.6 66.6 -33.0 -33.0 ]")

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 0.0 1111111.11 66.6 66.6 -33.0 -33.0 -33.0 ]")

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 0.0 1111111.11 66.6 66.6 -33.0 -33.0 -33.0 -33.0 ]")
        #expect(topItem(inty, .double).isContingent == true )
    }

    // contingency
    @Test func doubleDupItems() {
        intyInt3(inty)
        intyDouble4(inty)

        doThis(.doubleDupItems, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 1111111.11 66.6 -33.0 ]")

        doThis(.doubleDupItems, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 1111111.11 0.0 1111111.11 66.6 -33.0 ]")

        doThis(.doubleDupItems, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 1111111.11 0.0 1111111.11 66.6 -33.0 ]")
    }

    // contingency
    @Test func doubleDupTimes() {
        intyInt3(inty)
        intyDouble4(inty)

        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 1111111.11 66.6 -33.0 ]")

        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 0.0 0.0 1111111.11 66.6 -33.0 ]")

        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 0.0 0.0 1111111.11 66.6 -33.0 ]")
    }

    // contingency
    @Test func `doubleDupTimes does not overflow`() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(3_000_000_000),
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.1),
                        ])
        inty.config.stackCapacity = 7

        #expect(stackString(inty, .double) == "[ 1.1 ]")

        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 ]")
        #expect(stackString(inty, .error).contains("doubleDupTimes overflow") )
    }

    // contingency
    @Test func doubleShove() {
        intyInt5(inty)
        loadDoubles(inty, doubles: [1.1, 2.22, 3.333, 4.4444])


        #expect(stackString(inty, .int) == "[ -3 2 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 2 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 2.22 3.333 1.1 4.4444 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 0 2 ]")
        #expect(stackString(inty, .double) == "[ 3.333 1.1 2.22 4.4444 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 2 ]")
        #expect(stackString(inty, .double) == "[ 3.333 1.1 2.22 4.4444 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")
        #expect(topItem(inty, .double).isContingent == true )
    }

    // contingency
    @Test func doubleYank() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),IntItem(2),IntItem(17),IntItem(0),IntItem(2),
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.1),
                         DoubleItem(2.22),
                         DoubleItem(3.333),
                         DoubleItem(4.4444),
                        ])

//        intyDouble4(inty, [1.1, 2.22, 3.333, 4.4444])


        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 3.333 1.1 2.22 4.4444 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4444 3.333 1.1 2.22 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4444 3.333 1.1 2.22 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 4.4444 3.333 2.22 ]")
        #expect(topItem(inty, .double).isContingent == true )
    }

    // contingency
    @Test func doubleYankDup() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),IntItem(2),IntItem(17),IntItem(0),IntItem(2),
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.1),
                         DoubleItem(2.22),
                         DoubleItem(3.333),
                         DoubleItem(4.4444),
                        ])

        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.22 3.333 4.4444 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 2.22 1.1 1.1 2.22 3.333 4.4444 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4444 2.22 1.1 1.1 2.22 3.333 4.4444 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4444 4.4444 2.22 1.1 1.1 2.22 3.333 4.4444 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 2.22 4.4444 4.4444 2.22 1.1 1.1 2.22 3.333 4.4444 ]")
        #expect(topItem(inty, .double).isContingent == true )
    }

    @Test func intFlush() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(88, isContingent: true)
                        ]
        )

        #expect(stackString(inty, .int) == "[ 11 88 ]")

        doThis(.intFlush, to: inty)
        #expect(stackString(inty, .int) == "[ ]")

        doThis(.intFlush, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func intPop() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(88, isContingent: true)
                        ]
        )

        #expect(stackString(inty, .int) == "[ 11 88 ]")

        doThis(.intPop, to: inty)
        #expect(stackString(inty, .int) == "[ 88 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func intRot() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(55, isContingent: true),
                         IntItem(999)
                        ]
        )

        #expect(stackString(inty, .int) == "[ 11 55 999 ]")

        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 999 11 55 ]")

        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 55 999 11 ]")

        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 11 55 999 ]")
    }

    // contingency
    @Test func intStackDepth() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(88, isContingent: true)
                        ]
        )

        #expect(stackString(inty, .int) == "[ 11 88 ]")

        doThis(.intStackDepth, to: inty)
        #expect(stackString(inty, .int) == "[ 2 11 88 ]")
        #expect(topItem(inty, .int).isContingent == true)

        doThis(.intStackDepth, to: inty)
        #expect(stackString(inty, .int) == "[ 3 2 11 88 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func intSwap() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(88, isContingent: true)
                        ]
        )

        #expect(stackString(inty, .int) == "[ 11 88 ]")

        doThis(.intSwap, to: inty)
        #expect(stackString(inty, .int) == "[ 88 11 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

}
