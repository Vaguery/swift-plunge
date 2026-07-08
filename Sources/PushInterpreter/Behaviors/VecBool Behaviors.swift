//
//  VecBool Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/14/26.
//

import DequeModule

extension Interpreter {

    // returns a new vecBool with the old value's last element removed
    // if the argument was empty, an empty vector is pushed
    static let vecBoolButLast_Behavior =
        butLastBehavior(.vecBoolButLast, making: VecBoolItem.self)

    static let vecBoolConcat_Behavior =
        concatBehavior(.vecBoolConcat, making: VecBoolItem.self)

    static let vecBoolItemIsEmpty_Behavior =
        itemIsEmptyBehavior(.vecBoolItemIsEmpty, making: VecBoolItem.self)

    static let vecBoolLength_Behavior =
        lengthBehavior(.vecBoolLength, making: VecBoolItem.self)

    static let vecBoolRest_Behavior =
        restBehavior(.vecBoolRest, making: VecBoolItem.self)

    static let vecBoolReverse_Behavior =
        reverseBehavior(.vecBoolReverse, making: VecBoolItem.self)

    static let vecBoolTake_Behavior =
        takeBehavior(.vecBoolTake, making: VecBoolItem.self)

    static let vecBoolDrop_Behavior =
        dropBehavior(.vecBoolDrop, making: VecBoolItem.self)

    static let vecBoolConj_Behavior =
        conjBehavior(.vecBoolConj, making: VecBoolItem.self)

    static let vecBoolContains_Behavior =
        containsBehavior(.vecBoolContains, making: VecBoolItem.self)

    static let vecBoolFirst_Behavior =
        firstBehavior(.vecBoolFirst, making: VecBoolItem.self)

    static let vecBoolLast_Behavior =
        lastBehavior(.vecBoolLast, making: VecBoolItem.self)

    static let vecBoolNth_Behavior =
        nthBehavior(.vecBoolNth, making: VecBoolItem.self)

    static let vecBoolIndexOf_Behavior =
        indexOfBehavior(.vecBoolIndexOf, making: VecBoolItem.self)

    static let vecBoolOccurrencesOf_Behavior =
        occurrencesOfBehavior(.vecBoolOccurrencesOf, making: VecBoolItem.self)

    static let vecBoolRemove_Behavior =
        removeBehavior(.vecBoolRemove, making: VecBoolItem.self)

    // ( [1,2,3] 2 9 .vecBoolReplace)
    //
    // replace every occurrence of 2 in the argument (above) with 9
    //
    static let vecBoolReplace_Behavior =
        replaceBehavior(.vecBoolReplace, making: VecBoolItem.self)

    // ( [1,1,2,3] 1 9 .vecBoolReplaceFirst)
    //
    // replace the first occurrence of 1 in the argument (above) with 9
    //
    static let vecBoolReplaceFirst_Behavior =
        replaceFirstBehavior(.vecBoolReplaceFirst, making: VecBoolItem.self)

    // ( [1,1,2,3] 1 9 .vecBoolSet)
    //
    // replace the element at position 1 in the argument (above) with 9
    //
    static let vecBoolSet_Behavior =
        setBehavior(.vecBoolSet, making: VecBoolItem.self)

    // ( [1,1,2,3] 1 2 .vecBoolSubVec)
    //
    // return a stretch of the original vector from positions 1...2
    // if idx1 is negative, make it zero
    // if idx2 < idx1, return an empty vector
    //
    static let vecBoolSubVec_Behavior =
        subVecBehavior(.vecBoolSubVec, making: VecBoolItem.self)

    // ( [1,1,2,3] .vecBoolPushAll)
    //
    // return every item on the argument (in reverse order)
    // routing them to the correct stack
    //
    static let vecBoolPushAll_Behavior =
        pushAllBehavior(.vecBoolPushAll, making: VecBoolItem.self)

    // ( [1,1,2,3] .vecBoolIterate MOUSE )
    //
    //               4          3            2                   1         0
    // reults: ( exec:MOUSE exec:remains exec:.vecBoolIterate exec:MOUSE int:CHEESE )
    //
    static let vecBoolIterate_Behavior =
        iterateBehavior(.vecBoolIterate, making: VecBoolItem.self)

    static let vecBoolBehaviors: [PushInstruction : Behavior] =
    [
        .vecBoolButLast : vecBoolButLast_Behavior,
        .vecBoolConcat : vecBoolConcat_Behavior,
        .vecBoolConj : vecBoolConj_Behavior,
        .vecBoolContains : vecBoolContains_Behavior,
        .vecBoolDrop : vecBoolDrop_Behavior,
        .vecBoolFirst : vecBoolFirst_Behavior,
        .vecBoolIndexOf : vecBoolIndexOf_Behavior,
        .vecBoolItemIsEmpty : vecBoolItemIsEmpty_Behavior,
        .vecBoolIterate : vecBoolIterate_Behavior,
        .vecBoolLast : vecBoolLast_Behavior,
        .vecBoolLength : vecBoolLength_Behavior,
        .vecBoolNth : vecBoolNth_Behavior,
        .vecBoolOccurrencesOf : vecBoolOccurrencesOf_Behavior,
        .vecBoolPushAll : vecBoolPushAll_Behavior,
        .vecBoolRemove : vecBoolRemove_Behavior,
        .vecBoolReplace : vecBoolReplace_Behavior,
        .vecBoolReplaceFirst : vecBoolReplaceFirst_Behavior,
        .vecBoolRest : vecBoolRest_Behavior,
        .vecBoolReverse : vecBoolReverse_Behavior,
        .vecBoolSet : vecBoolSet_Behavior,
        .vecBoolSubVec : vecBoolSubVec_Behavior,
        .vecBoolTake : vecBoolTake_Behavior,
    ]
}

