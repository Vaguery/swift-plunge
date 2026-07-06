//
//  VecBool Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/15/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct VecBoolBehaviorTests {
    
    var inty = Interpreter()
    
    @Test func vecBoolButLast() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, true, false]),
                         VecBoolItem([true], isContingent: true)
                        ])
        
        doThis(.vecBoolButLast, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, true, false] [true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)
        
        doThis(.vecBoolButLast, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true] [true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        
        doThis(.vecBoolPop, to: inty)
        
        doThis(.vecBoolButLast, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
    }
    
    @Test func vecBoolConcat() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([], isContingent: true),
                         VecBoolItem([false, false], isContingent: false),
                         VecBoolItem([true, true], isContingent: false)
                        ])
        
        doThis(.vecBoolConcat, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] [true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        
        doThis(.vecBoolConcat, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
    }

    @Test func vecBoolConj() {
        loadBools(inty, bools: [true, true, true], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false], isContingent: false)
                        ])

        doThis(.vecBoolConj, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] [false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolConj, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolConj, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
    }

    @Test func vecBoolContains() {
        loadBools(inty, bools: [true, true, false], contingent: [1,2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, true]),
                         VecBoolItem([false, true])
                        ])

        #expect(stackString(inty, .vecBool) == "[ [] [true, true] [false, true] ]")
        #expect(stackString(inty, .bool) == "[ true true false ]")

        doThis(.vecBoolContains, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolPop, to: inty)

        doThis(.vecBoolContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.boolPop, to: inty)

        doThis(.vecBoolContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func vecBoolDrop() {
        loadInts(inty, ints: [-3, 0, 1, -2], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, false], isContingent: false)
                        ])

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
    }

    @Test func vecBoolFirst() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false], isContingent: true)
                        ])

        doThis(.vecBoolFirst, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolFirst, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func vecBoolIndexOf() {
        loadBools(inty, bools: [true, false, false], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false]),
                         VecBoolItem([true, false])
                        ])

        #expect(stackString(inty, .vecBool) == "[ [] [false, false] [true, false] ]")
        #expect(stackString(inty, .bool) == "[ true false false ]")

        doThis(.vecBoolIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ -1 ]") // returns -1

        doThis(.vecBoolIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 -1 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.vecBoolIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -1 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func vecBoolItemIsEmpty() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false], isContingent: true)
                        ])
        
        doThis(.vecBoolItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.vecBoolItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func `vecBoolIterate produces valid index numbers for results`() {
        loadInts(inty, ints: [0])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([false, true]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.intInc),
                        ])

        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .vecBool) == "[ [false, true] ]")
        #expect(stackString(inty, .exec) == "[ .intInc ]")
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolIterate, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).index == 0)

        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .intInc [true] .vecBoolIterate .intInc ]")
        #expect(topItem(inty, .exec).index == 4)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 3)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 2)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 1)
    }

    @Test func `vecBoolIterate works for >1 item`() {
        loadInts(inty, ints: [17])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([false, true, false]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.intInc),
                        ])

        #expect(stackString(inty, .int) == "[ 17 ]")
        #expect(stackString(inty, .vecBool) == "[ [false, true, false] ]")
        #expect(stackString(inty, .exec) == "[ .intInc ]")
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolIterate, to: inty)
        #expect(stackString(inty, .int) == "[ 17 ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .intInc [true, false] .vecBoolIterate .intInc ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .int) == "[ 18 ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ [true, false] .vecBoolIterate .intInc ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .int) == "[ 18 ]")
        #expect(stackString(inty, .vecBool) == "[ [true, false] ]")
        #expect(stackString(inty, .exec) == "[ .vecBoolIterate .intInc ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .int) == "[ 18 ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .intInc [false] .vecBoolIterate .intInc ]")
        #expect(stackString(inty, .bool) == "[ true false ]")

        inty.step()
        #expect(stackString(inty, .int) == "[ 19 ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ [false] .vecBoolIterate .intInc ]")
        #expect(stackString(inty, .bool) == "[ true false ]")

        inty.step()
        #expect(stackString(inty, .int) == "[ 19 ]")
        #expect(stackString(inty, .vecBool) == "[ [false] ]")
        #expect(stackString(inty, .exec) == "[ .vecBoolIterate .intInc ]")
        #expect(stackString(inty, .bool) == "[ true false ]")

        inty.step()
        #expect(stackString(inty, .int) == "[ 19 ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .intInc ]")
        #expect(stackString(inty, .bool) == "[ false true false ]")

        inty.step()
        #expect(stackString(inty, .int) == "[ 20 ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false true false ]")
    }

    @Test func `vecBoolIterate works for empty`() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])

        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .vecBool) == "[ [] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")

        doThis(.vecBoolIterate, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")

    }

    @Test func `vecBoolIterate works for one item`() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([false]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])

        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .vecBool) == "[ [false] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")

        doThis(.vecBoolIterate, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
    }

    @Test func vecBoolLast() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false, true], isContingent: true)
                        ])

        doThis(.vecBoolLast, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolLast, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func vecBoolLength() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false, false], isContingent: true)
                        ])
        
        doThis(.vecBoolLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.vecBoolLength, to: inty)
        #expect(stackString(inty, .int) == "[ 3 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func vecBoolNth() {
        loadInts(inty, ints: [-3, 1, 7777], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, true]),
                         VecBoolItem([false, false, true])
                        ])

        #expect(stackString(inty, .vecBool) == "[ [] [true, false, true] [false, false, true] ]")
        #expect(stackString(inty, .int) == "[ -3 1 7777 ]")

        doThis(.vecBoolNth, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolNth, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.vecBoolNth, to: inty)
        #expect(stackString(inty, .bool) == "[ false false ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func vecBoolOccurrencesOf() {
        loadBools(inty, bools: [true, false, false], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, true, true, true, ]),
                         VecBoolItem([true, true, true, false])
                        ])

        doThis(.vecBoolOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.vecBoolOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 0 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.vecBoolOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func vecBoolPushAll() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, true, true], isContingent: true),
                        ])

        doThis(.vecBoolPushAll, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolPushAll, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(topItem(inty, .bool).index == 0)
        doThis(.boolPop, to: inty)
        #expect(topItem(inty, .bool).index == 1)
    }

    @Test func vecBoolRemove() {
        loadBools(inty, bools: [false, false, false], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, true, false]),
                         VecBoolItem([true, true, true])
                        ])

        doThis(.vecBoolRemove, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, true, false] [true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolRemove, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] [true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolRemove, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
    }

    @Test func vecBoolReplace() {
        loadBools(inty, bools: [false, true, true, false, false, true],contingent: [4])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false, true]),
                         VecBoolItem([true, false, true])
                        ])

        doThis(.vecBoolReplace, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, false, true] [true, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplace, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, true] [true, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplace, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
    }

    @Test func vecBoolReplaceFirst() {
        loadBools(inty, bools: [false, true, true, false, false, true],contingent: [4])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false]),
                         VecBoolItem([true, true])
                        ])

        doThis(.vecBoolReplaceFirst, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, false] [true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplaceFirst, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false] [true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplaceFirst, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
    }

    @Test func vecBoolRest() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, false], isContingent: true)
                        ])
        
        doThis(.vecBoolRest, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        
        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolRest, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
    }
    
    @Test func vecBoolReverse() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, true, false], isContingent: true)
                        ])
        
        doThis(.vecBoolReverse, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, true, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        
        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReverse, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
    }

    @Test func vecBoolSet() {
        loadBools(inty, bools: [false, false, false, false])
        loadInts(inty, ints: [1, 2, -8, 43])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true,true,true,true]),
                         VecBoolItem([true,true,true,true,]),
                         VecBoolItem([true,true,true,true,], isContingent: true),
                        ])

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, true, true, true] [true, true, true, true] [true, true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, false, true] [true, true, true, true] [true, true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true, true, true] [true, true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, true, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
    }

    @Test func vecBoolSubVec() {
        loadInts(inty, ints: [1,9,2,1,2,-1,1,1], contingent: [4])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, true, false, false, true]),
                         VecBoolItem([true, true, false, false, true]),
                         VecBoolItem([true, true, false, false, true])
                        ])

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, true, false, false, true] [true, true, false, false, true] [true, true, false, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false] [true, true, false, false, true] [true, true, false, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, false] [true, true, false, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
    }

    @Test func vecBoolTake() {
        loadInts(inty, ints: [-3, 99, 1, -1], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, false], isContingent: false)
                        ])
       
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        
        doThis(.vecBoolPop, to: inty)
        
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
    }

}
