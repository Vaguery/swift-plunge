//
//  VecString Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/14/26.
//

import DequeModule

extension Interpreter {

    // returns a new vecString with the old value's last element removed
    // if the argument was empty, an empty vector is pushed
    //
    static let vecStringButLast_Behavior =
        butLastBehavior(.vecStringButLast, making: VecStringItem.self)

    static let vecStringConcat_Behavior =
        concatBehavior(.vecStringConcat, making: VecStringItem.self)

    static let vecStringItemIsEmpty_Behavior =
        itemIsEmptyBehavior(.vecStringItemIsEmpty, making: VecStringItem.self)

    static let vecStringLength_Behavior =
        lengthBehavior(.vecStringLength, making: VecStringItem.self)

    static let vecStringRest_Behavior =
        restBehavior(.vecStringRest, making: VecStringItem.self)

    static let vecStringReverse_Behavior =
        reverseBehavior(.vecStringReverse, making: VecStringItem.self)

    static let vecStringTake_Behavior =
        takeBehavior(.vecStringTake, making: VecStringItem.self)

    static let vecStringDrop_Behavior =
        dropBehavior(.vecStringDrop, making: VecStringItem.self)

    static let vecStringConj_Behavior =
        conjBehavior(.vecStringConj, making: VecStringItem.self)

    static let vecStringContains_Behavior =
        containsBehavior(.vecStringContains, making: VecStringItem.self)

    static let vecStringFirst_Behavior =
        firstBehavior(.vecStringFirst, making: VecStringItem.self)

    static let vecStringLast_Behavior =
        lastBehavior(.vecStringLast, making: VecStringItem.self)

    static let vecStringNth_Behavior =
        nthBehavior(.vecStringNth, making: VecStringItem.self)

    static let vecStringIndexOf_Behavior =
        indexOfBehavior(.vecStringIndexOf, making: VecStringItem.self)

    static let vecStringOccurrencesOf_Behavior =
        occurrencesOfBehavior(.vecStringOccurrencesOf, making: VecStringItem.self)

    static let vecStringRemove_Behavior =
        removeBehavior(.vecStringRemove, making: VecStringItem.self)

    // ( [1,2,3] 2 9 .vecStringReplace)
    //
    // replace every occurrence of 2 in the argument (above) with 9
    //
    static let vecStringReplace_Behavior =
        replaceBehavior(.vecStringReplace, making: VecStringItem.self)

    // ( [1,1,2,3] 1 9 .vecStringReplaceFirst)
    //
    // replace the first occurrence of 1 in the argument (above) with 9
    //
    static let vecStringReplaceFirst_Behavior =
        replaceFirstBehavior(.vecStringReplaceFirst, making: VecStringItem.self)

    // ( ["a","b","c"] 1 "foo" .vecStringSet)
    //
    // replace the element at position 1 in the argument (above) with "foo"
    //
    static let vecStringSet_Behavior =
        setBehavior(.vecStringSet, making: VecStringItem.self)

    // ( [1,1,2,3] 1 2 .vecStringSubVec)
    //
    // return a stretch of the original vector from positions 1...2
    // if idx1 is negative, make it zero
    // if idx2 < idx1, return an empty vector
    //
    static let vecStringSubVec_Behavior =
        subVecBehavior(.vecStringSubVec, making: VecStringItem.self)

    // ( [1,1,2,3] .vecStringPushAll)
    //
    // return every item on the argument (in reverse order)
    // routing them to the correct stack
    //
    static let vecStringPushAll_Behavior =
        pushAllBehavior(.vecStringPushAll, making: VecStringItem.self)

    // ( [1,1,2,3] .vecStringIterate MOUSE )
    //
    //               4          3            2                   1         0
    // reults: ( exec:MOUSE exec:remains exec:.vecStringIterate exec:MOUSE int:CHEESE )
    //
    static let vecStringIterate_Behavior =
        iterateBehavior(.vecStringIterate, making: VecStringItem.self)

    static let vecStringBehaviors: [PushInstruction : Behavior] =
    [
        .vecStringButLast : vecStringButLast_Behavior,
        .vecStringConcat : vecStringConcat_Behavior,
        .vecStringConj : vecStringConj_Behavior,
        .vecStringContains : vecStringContains_Behavior,
        .vecStringDrop : vecStringDrop_Behavior,
        .vecStringFirst : vecStringFirst_Behavior,
        .vecStringIndexOf : vecStringIndexOf_Behavior,
        .vecStringItemIsEmpty : vecStringItemIsEmpty_Behavior,
        .vecStringIterate : vecStringIterate_Behavior,
        .vecStringLast : vecStringLast_Behavior,
        .vecStringLength : vecStringLength_Behavior,
        .vecStringNth : vecStringNth_Behavior,
        .vecStringOccurrencesOf : vecStringOccurrencesOf_Behavior,
        .vecStringPushAll : vecStringPushAll_Behavior,
        .vecStringRemove : vecStringRemove_Behavior,
        .vecStringReplace : vecStringReplace_Behavior,
        .vecStringReplaceFirst : vecStringReplaceFirst_Behavior,
        .vecStringRest : vecStringRest_Behavior,
        .vecStringReverse : vecStringReverse_Behavior,
        .vecStringSet : vecStringSet_Behavior,
        .vecStringSubVec : vecStringSubVec_Behavior,
        .vecStringTake : vecStringTake_Behavior,
    ]
}

