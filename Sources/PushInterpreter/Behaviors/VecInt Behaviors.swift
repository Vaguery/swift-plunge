//
//  VecInt Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/12/26.
//

import DequeModule

extension Interpreter {

    // returns a new vecInt with the old value's last element removed
    // if the argument was empty, an empty vector is pushed
    //
    static let vecIntButLast_Behavior =
        butLastBehavior(.vecIntButLast, making: VecIntItem.self)

    static let vecIntConcat_Behavior =
        concatBehavior(.vecIntConcat, making: VecIntItem.self)

    static let vecIntItemIsEmpty_Behavior =
        itemIsEmptyBehavior(.vecIntItemIsEmpty, making: VecIntItem.self)

    static let vecIntLength_Behavior =
        lengthBehavior(.vecIntLength, making: VecIntItem.self)

    static let vecIntRest_Behavior =
        restBehavior(.vecIntRest, making: VecIntItem.self)

    static let vecIntReverse_Behavior =
        reverseBehavior(.vecIntReverse, making: VecIntItem.self)

    static let vecIntTake_Behavior =
        takeBehavior(.vecIntTake, making: VecIntItem.self)

    static let vecIntDrop_Behavior =
        dropBehavior(.vecIntDrop, making: VecIntItem.self)

    static let vecIntConj_Behavior =
        conjBehavior(.vecIntConj, making: VecIntItem.self)

    static let vecIntContains_Behavior =
        containsBehavior(.vecIntContains, making: VecIntItem.self)

    static let vecIntFirst_Behavior =
        firstBehavior(.vecIntFirst, making: VecIntItem.self)

    static let vecIntLast_Behavior =
        lastBehavior(.vecIntLast, making: VecIntItem.self)

    static let vecIntNth_Behavior =
        nthBehavior(.vecIntNth, making: VecIntItem.self)

    static let vecIntIndexOf_Behavior =
        indexOfBehavior(.vecIntIndexOf, making: VecIntItem.self)

    static let vecIntOccurrencesOf_Behavior =
        occurrencesOfBehavior(.vecIntOccurrencesOf, making: VecIntItem.self)

    static let vecIntRemove_Behavior =
        removeBehavior(.vecIntRemove, making: VecIntItem.self)

    // ( [1,2,3] 2 9 .vecIntReplace)
    //
    // replace every occurrence of 2 in the argument (above) with 9
    //
    static let vecIntReplace_Behavior =
        replaceBehavior(.vecIntReplace, making: VecIntItem.self)

    // ( [1,1,2,3] 1 9 .vecIntReplaceFirst)
    //
    // replace the first occurrence of 1 in the argument (above) with 9
    //
    static let vecIntReplaceFirst_Behavior =
        replaceFirstBehavior(.vecIntReplaceFirst, making: VecIntItem.self)

    // ( [1,1,2,3] 1 9 .vecIntSet)
    //
    // replace the element at position 1 in the argument (above) with 9
    //
    static let vecIntSet_Behavior =
        setBehavior(.vecIntSet, making: VecIntItem.self)

    // ( [1,1,2,3] 1 2 .vecIntSubVec)
    //
    // return a stretch of the original vector from positions 1...2
    // if idx1 is negative, make it zero
    // if idx2 < idx1, return an empty vector
    //
    static let vecIntSubVec_Behavior =
        subVecBehavior(.vecIntSubVec, making: VecIntItem.self)

    // ( [1,1,2,3] .vecIntPushAll)
    //
    // return every item on the argument (in reverse order)
    // routing them to the correct stack
    //
    static let vecIntPushAll_Behavior =
        pushAllBehavior(.vecIntPushAll, making: VecIntItem.self)

    // ( [1,1,2,3] .vecIntIterate MOUSE )
    //
    //               4          3            2                   1         0
    // reults: ( exec:MOUSE exec:remains exec:.vecIntIterate exec:MOUSE int:CHEESE )
    //
    static let vecIntIterate_Behavior =
        iterateBehavior(.vecIntIterate, making: VecIntItem.self)

    static let vecIntBehaviors: [PushInstruction : Behavior] =
    [
        .vecIntButLast : vecIntButLast_Behavior,
        .vecIntConcat : vecIntConcat_Behavior,
        .vecIntConj : vecIntConj_Behavior,
        .vecIntContains : vecIntContains_Behavior,
        .vecIntDrop : vecIntDrop_Behavior,
        .vecIntFirst : vecIntFirst_Behavior,
        .vecIntIndexOf : vecIntIndexOf_Behavior,
        .vecIntItemIsEmpty : vecIntItemIsEmpty_Behavior,
        .vecIntIterate : vecIntIterate_Behavior,
        .vecIntLast : vecIntLast_Behavior,
        .vecIntLength : vecIntLength_Behavior,
        .vecIntNth : vecIntNth_Behavior,
        .vecIntOccurrencesOf : vecIntOccurrencesOf_Behavior,
        .vecIntPushAll : vecIntPushAll_Behavior,
        .vecIntRemove : vecIntRemove_Behavior,
        .vecIntReplace : vecIntReplace_Behavior,
        .vecIntReplaceFirst : vecIntReplaceFirst_Behavior,
        .vecIntRest : vecIntRest_Behavior,
        .vecIntReverse : vecIntReverse_Behavior,
        .vecIntSet : vecIntSet_Behavior,
        .vecIntSubVec : vecIntSubVec_Behavior,
        .vecIntTake : vecIntTake_Behavior,
    ]
}

