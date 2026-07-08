//
//  VecDouble Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/14/26.
//

import DequeModule

extension Interpreter {

    // returns a new vecDouble with the old value's last element removed
    // if the argument was empty, an empty vector is pushed
    static let vecDoubleButLast_Behavior =
        butLastBehavior(.vecDoubleButLast, making: VecDoubleItem.self)

    static let vecDoubleConcat_Behavior =
        concatBehavior(.vecDoubleConcat, making: VecDoubleItem.self)

    static let vecDoubleItemIsEmpty_Behavior =
        itemIsEmptyBehavior(.vecDoubleItemIsEmpty, making: VecDoubleItem.self)

    static let vecDoubleLength_Behavior =
        lengthBehavior(.vecDoubleLength, making: VecDoubleItem.self)

    static let vecDoubleRest_Behavior =
        restBehavior(.vecDoubleRest, making: VecDoubleItem.self)

    static let vecDoubleReverse_Behavior =
        reverseBehavior(.vecDoubleReverse, making: VecDoubleItem.self)

    static let vecDoubleTake_Behavior =
        takeBehavior(.vecDoubleTake, making: VecDoubleItem.self)

    static let vecDoubleDrop_Behavior =
        dropBehavior(.vecDoubleDrop, making: VecDoubleItem.self)

    static let vecDoubleConj_Behavior =
        conjBehavior(.vecDoubleConj, making: VecDoubleItem.self)

    static let vecDoubleContains_Behavior =
        containsBehavior(.vecDoubleContains, making: VecDoubleItem.self)

    static let vecDoubleFirst_Behavior =
        firstBehavior(.vecDoubleFirst, making: VecDoubleItem.self)

    static let vecDoubleLast_Behavior =
        lastBehavior(.vecDoubleLast, making: VecDoubleItem.self)

    static let vecDoubleNth_Behavior =
        nthBehavior(.vecDoubleNth, making: VecDoubleItem.self)

    static let vecDoubleIndexOf_Behavior =
        indexOfBehavior(.vecDoubleIndexOf, making: VecDoubleItem.self)

    static let vecDoubleOccurrencesOf_Behavior =
        occurrencesOfBehavior(.vecDoubleOccurrencesOf, making: VecDoubleItem.self)

    static let vecDoubleRemove_Behavior =
        removeBehavior(.vecDoubleRemove, making: VecDoubleItem.self)

    // ( [1,2,3] 2 9 .vecDoubleReplace)
    //
    // replace every occurrence of 2 in the argument (above) with 9
    //
    static let vecDoubleReplace_Behavior =
        replaceBehavior(.vecDoubleReplace, making: VecDoubleItem.self)

    // ( [1,1,2,3] 1 9 .vecDoubleReplaceFirst)
    //
    // replace the first occurrence of 1 in the argument (above) with 9
    //
    static let vecDoubleReplaceFirst_Behavior =
        replaceFirstBehavior(.vecDoubleReplaceFirst, making: VecDoubleItem.self)

    // ( [1,1,2,3] 1 9 .vecDoubleSet)
    //
    // replace the element at position 1 in the argument (above) with 9
    //
    static let vecDoubleSet_Behavior =
        setBehavior(.vecDoubleSet, making: VecDoubleItem.self)

    // ( [1,1,2,3] 1 2 .vecDoubleSubVec)
    //
    // return a stretch of the original vector from positions 1...2
    // if idx1 is negative, make it zero
    // if idx2 < idx1, return an empty vector
    //
    static let vecDoubleSubVec_Behavior =
        subVecBehavior(.vecDoubleSubVec, making: VecDoubleItem.self)

    // ( [1,1,2,3] .vecDoublePushAll)
    //
    // return every item on the argument (in reverse order)
    // routing them to the correct stack
    //
    static let vecDoublePushAll_Behavior =
        pushAllBehavior(.vecDoublePushAll, making: VecDoubleItem.self)

    // ( [1,1,2,3] .vecDoubleIterate MOUSE )
    //
    //               4          3            2                   1         0
    // reults: ( exec:MOUSE exec:remains exec:.vecDoubleIterate exec:MOUSE int:CHEESE )
    //
    static let vecDoubleIterate_Behavior =
        iterateBehavior(.vecDoubleIterate, making: VecDoubleItem.self)

    static let vecDoubleBehaviors: [PushInstruction : Behavior] =
    [
        .vecDoubleButLast : vecDoubleButLast_Behavior,
        .vecDoubleConcat : vecDoubleConcat_Behavior,
        .vecDoubleConj : vecDoubleConj_Behavior,
        .vecDoubleContains : vecDoubleContains_Behavior,
        .vecDoubleDrop : vecDoubleDrop_Behavior,
        .vecDoubleFirst : vecDoubleFirst_Behavior,
        .vecDoubleIndexOf : vecDoubleIndexOf_Behavior,
        .vecDoubleItemIsEmpty : vecDoubleItemIsEmpty_Behavior,
        .vecDoubleIterate : vecDoubleIterate_Behavior,
        .vecDoubleLast : vecDoubleLast_Behavior,
        .vecDoubleLength : vecDoubleLength_Behavior,
        .vecDoubleNth : vecDoubleNth_Behavior,
        .vecDoubleOccurrencesOf : vecDoubleOccurrencesOf_Behavior,
        .vecDoublePushAll : vecDoublePushAll_Behavior,
        .vecDoubleRemove : vecDoubleRemove_Behavior,
        .vecDoubleReplace : vecDoubleReplace_Behavior,
        .vecDoubleReplaceFirst : vecDoubleReplaceFirst_Behavior,
        .vecDoubleRest : vecDoubleRest_Behavior,
        .vecDoubleReverse : vecDoubleReverse_Behavior,
        .vecDoubleSet : vecDoubleSet_Behavior,
        .vecDoubleSubVec : vecDoubleSubVec_Behavior,
        .vecDoubleTake : vecDoubleTake_Behavior,
    ]
}

