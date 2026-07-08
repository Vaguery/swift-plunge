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
        Behavior(
            .vecIntButLast,
            takes: [.vecInt],
            fxn: { a in
                let (x) = (a[0] as! VecIntItem)
                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            x.value.dropLast(1),
                            call: [x, InstructionItem(.vecIntButLast)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let vecIntConcat_Behavior =
        Behavior(
            .vecIntConcat,
            takes: [.vecInt, .vecInt],
            fxn: { a in
                let (x, y) = (a[0] as! VecIntItem, a[1] as! VecIntItem)
                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            y.value + x.value,
                            call: [y, x, InstructionItem(.vecIntButLast)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecIntItemIsEmpty_Behavior =
        Behavior(
            .vecIntItemIsEmpty,
            takes: [.vecInt],
            fxn: { a in
                let (x) = (a[0] as! VecIntItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.isEmpty,
                            call: [x, InstructionItem(.vecIntItemIsEmpty)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let vecIntLength_Behavior =
        Behavior(
            .vecIntLength,
            takes: [.vecInt],
            fxn: { a in
                let (x) = (a[0] as! VecIntItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            x.value.count,
                            call: [x, InstructionItem(.vecIntLength)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let vecIntRest_Behavior =
        Behavior(
            .vecIntRest,
            takes: [.vecInt],
            fxn: { a in
                let (x) = (a[0] as! VecIntItem)
                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            Array(x.value.dropFirst(1)),
                            call: [x, InstructionItem(.vecIntRest)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let vecIntReverse_Behavior =
        Behavior(
            .vecIntReverse,
            takes: [.vecInt],
            fxn: { a in
                let (x) = (a[0] as! VecIntItem)
                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            Array(x.value.reversed()),
                            call: [x, InstructionItem(.vecIntReverse)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let vecIntTake_Behavior =
        Behavior(
            .vecIntTake,
            takes: [.vecInt, .int],
            fxn: { a in
                let (x, y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                let range = x.value.count
                let idx = range - (min(range, max(y.value, 0)))
                let result = Array(x.value.dropLast(idx))

                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            result,
                            call: [x, y, InstructionItem(.vecIntTake)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecIntDrop_Behavior =
        Behavior(
            .vecIntDrop,
            takes: [.vecInt, .int],
            fxn: { a in
                let (x, y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                let range = x.value.count
                let idx = (min(range, max(y.value, 0)))
                let result = Array(x.value.dropFirst(idx))

                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            result,
                            call: [x, y, InstructionItem(.vecIntDrop)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecIntConj_Behavior =
        Behavior(
            .vecIntConj,
            takes: [.vecInt, .int],
            fxn: { a in
                let (x, y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                var result = x.value
                result.append(y.value)
                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            result,
                            call: [x, y, InstructionItem(.vecIntConj)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecIntContains_Behavior =
        Behavior(
            .vecIntContains,
            takes: [.vecInt, .int],
            fxn: { a in
                let (x, y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                var result = x.value.contains(y.value)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            result,
                            call: [x, y, InstructionItem(.vecIntContains)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecIntFirst_Behavior =
        Behavior(
            .vecIntFirst,
            takes: [.vecInt],
            fxn: { a in
                let (x) = (a[0] as! VecIntItem)
                if let result = x.value.first {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: [x, InstructionItem(.vecIntFirst)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                } else {
                    return []
                }
            }
        )

    static let vecIntLast_Behavior =
        Behavior(
            .vecIntLast,
            takes: [.vecInt],
            fxn: { a in
                let (x) = (a[0] as! VecIntItem)
                if let result = x.value.last {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: [x, InstructionItem(.vecIntLast)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                } else {
                    return []
                }
            }
        )

    static let vecIntNth_Behavior =
        Behavior(
            .vecIntNth,
            takes: [.vecInt, .int],
            fxn: { a in
                let (x, y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                let range = x.value.count
                if range == 0 {
                    return []
                } else {
                    let position = abs(y.value)
                    let idx = position % range
                    let result = x.value[idx]
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: [x, y, InstructionItem(.vecIntNth)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            }
        )

    static let vecIntIndexOf_Behavior =
        Behavior(
            .vecIntIndexOf,
            takes: [.vecInt, .int],
            fxn: { a in
                let (x, y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                var result: Int? = nil
                if let idx = x.value.firstIndex(of: y.value) {
                    result = idx
                } else {
                    result = -1
                }
                return [
                    Router(
                        .int,
                        IntItem(
                            result!,
                            call: [x, y, InstructionItem(.vecIntIndexOf)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecIntOccurrencesOf_Behavior =
        Behavior(
            .vecIntOccurrencesOf,
            takes: [.vecInt, .int],
            fxn: { a in
                let (x, y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                let result = x.value.count(where: { $0 == (y.value) })
                return [
                    Router(
                        .int,
                        IntItem(
                            result,
                            call: [
                                x, y, InstructionItem(.vecIntOccurrencesOf),
                            ],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecIntRemove_Behavior =
        Behavior(
            .vecIntRemove,
            takes: [.vecInt, .int],
            fxn: { a in
                let (x, y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                var result = x.value
                result.removeAll(where: { $0 == (y.value) })
                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            result,
                            call: [x, y, InstructionItem(.vecIntRemove)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    // ( [1,2,3] 2 9 .vecIntReplace)
    //
    // replace every occurrence of 2 in the argument (above) with 9
    //
    static let vecIntReplace_Behavior =
        Behavior(
            .vecIntReplace,
            takes: [.vecInt, .int, .int],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! VecIntItem,
                    a[1] as! IntItem,
                    a[2] as! IntItem
                )
                let result = x.value.map({ $0 == z.value ? y.value : $0 })
                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            result,
                            call: [x, z, y, InstructionItem(.vecIntReplace)],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
                    )
                ]
            }
        )

    // ( [1,1,2,3] 1 9 .vecIntReplaceFirst)
    //
    // replace the first occurrence of 1 in the argument (above) with 9
    //
    static let vecIntReplaceFirst_Behavior =
        Behavior(
            .vecIntReplaceFirst,
            takes: [.vecInt, .int, .int],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! VecIntItem,
                    a[1] as! IntItem,
                    a[2] as! IntItem
                )
                var result = x.value
                if let idx = result.firstIndex(where: { $0 == z.value }) {
                    result[idx] = y.value
                }
                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            result,
                            call: [
                                x, z, y, InstructionItem(.vecIntReplaceFirst),
                            ],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
                    )
                ]
            }
        )

    // ( [1,1,2,3] 1 9 .vecIntSet)
    //
    // replace the element at position 1 in the argument (above) with 9
    //
    static let vecIntSet_Behavior =
        Behavior(
            .vecIntSet,
            takes: [.vecInt, .int, .int],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! VecIntItem,
                    a[1] as! IntItem,
                    a[2] as! IntItem
                )
                var result = x.value
                if result.count > 0 {
                    let idx = abs(y.value) % (result.count)
                    result[idx] = z.value
                }
                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            result,
                            call: [x, z, y, InstructionItem(.vecIntSet)],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
                    )
                ]
            }
        )

    // ( [1,1,2,3] 1 2 .vecIntSubVec)
    //
    // return a stretch of the original vector from positions 1...2
    // if idx1 is negative, make it zero
    // if idx2 < idx1, return an empty vector
    //
    static let vecIntSubVec_Behavior =
        Behavior(
            .vecIntSubVec,
            takes: [.vecInt, .int, .int],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! VecIntItem,
                    a[1] as! IntItem,
                    a[2] as! IntItem
                )
                var result = x.value

                if result.count > 0 {
                    let range = result.count - 1
                    let lhs = min(range, max(0, z.value))
                    let rhs = min(range, max(0, z.value, y.value))
                    result = Array(result[lhs...rhs])
                }
                return [
                    Router(
                        .vecInt,
                        VecIntItem(
                            result,
                            call: [x, z, y, InstructionItem(.vecIntSubVec)],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
                    )
                ]
            }
        )

    // ( [1,1,2,3] .vecIntPushAll)
    //
    // return every item on the argument (in reverse order)
    // routing them to the correct stack
    //
    static let vecIntPushAll_Behavior =
        Behavior(
            .vecIntPushAll,
            takes: [.vecInt],
            fxn: { a in
                let (x) = (a[0] as! VecIntItem)
                var results = [Router]()
                let backwards = Array(x.value.reversed())
                for idx in 0..<backwards.count {
                    results.append(
                        Router(
                            .int,
                            IntItem(
                                backwards[idx],
                                call: [x, InstructionItem(.vecIntPushAll)],
                                isContingent: Behavior.netContingency(of: x),
                                index: backwards.count - idx - 1
                            )
                        )
                    )
                }
                return results
            }
        )

    // ( [1,1,2,3] .vecIntIterate MOUSE )
    //
    //               4          3            2                   1         0
    // reults: ( exec:MOUSE exec:remains exec:.vecIntIterate exec:MOUSE int:CHEESE )
    //
    static let vecIntIterate_Behavior =
        Behavior(
            .vecIntIterate,
            takes: [.vecInt, .exec],
            fxn: { a in
                let (x, y) = (a[0] as! VecIntItem, a[1])
                var results = [Router]()
                var workingVector = x.value

                var mouseCopy = a[1]
                let count = workingVector.count
                if count > 0 {
                    mouseCopy.index = 1
                    results.append(Router(.exec, mouseCopy))  //1

                    let item = workingVector.removeFirst()
                    results.append(
                        Router(
                            .int,
                            IntItem(
                                item,
                                call: [x, InstructionItem(.vecIntIterate)],
                                isContingent: Behavior.netContingency(of: x, y),
                                index: 0
                            )
                        )
                    )
                    if count > 1 {
                        results.append(
                            Router(
                                .exec,
                                InstructionItem(
                                    .vecIntIterate,
                                    call: [x, InstructionItem(.vecIntIterate)],
                                    isContingent: Behavior.netContingency(
                                        of: x,
                                        y
                                    ),
                                    index: 2
                                )
                            )
                        )
                        results.append(
                            Router(
                                .exec,
                                VecIntItem(
                                    workingVector,  // which was changed
                                    call: [x, InstructionItem(.vecIntIterate)],
                                    isContingent: Behavior.netContingency(
                                        of: x,
                                        y
                                    ),
                                    index: 3
                                )
                            )
                        )
                        mouseCopy.index = 4
                        results.append(Router(.exec, mouseCopy))  //4
                    }
                }
                return results
            }
        )

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

