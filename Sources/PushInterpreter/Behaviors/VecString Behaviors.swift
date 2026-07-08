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
        Behavior(
            .vecStringButLast,
            takes: [.vecString],
            fxn: { a in
                let (x) = (a[0] as! VecStringItem)
                return [
                    Router(
                        .vecString,
                        VecStringItem(
                            x.value.dropLast(1),
                            call: [x, InstructionItem(.vecStringButLast)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let vecStringConcat_Behavior =
        Behavior(
            .vecStringConcat,
            takes: [.vecString, .vecString],
            fxn: { a in
                let (x, y) = (a[0] as! VecStringItem, a[1] as! VecStringItem)
                return [
                    Router(
                        .vecString,
                        VecStringItem(
                            y.value + x.value,
                            call: [y, x, InstructionItem(.vecStringButLast)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecStringItemIsEmpty_Behavior =
        Behavior(
            .vecStringItemIsEmpty,
            takes: [.vecString],
            fxn: { a in
                let (x) = (a[0] as! VecStringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.isEmpty,
                            call: [x, InstructionItem(.vecStringItemIsEmpty)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let vecStringLength_Behavior =
        Behavior(
            .vecStringLength,
            takes: [.vecString],
            fxn: { a in
                let (x) = (a[0] as! VecStringItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            x.value.count,
                            call: [x, InstructionItem(.vecStringLength)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let vecStringRest_Behavior =
        Behavior(
            .vecStringRest,
            takes: [.vecString],
            fxn: { a in
                let (x) = (a[0] as! VecStringItem)
                return [
                    Router(
                        .vecString,
                        VecStringItem(
                            Array(x.value.dropFirst(1)),
                            call: [x, InstructionItem(.vecStringRest)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let vecStringReverse_Behavior =
        Behavior(
            .vecStringReverse,
            takes: [.vecString],
            fxn: { a in
                let (x) = (a[0] as! VecStringItem)
                return [
                    Router(
                        .vecString,
                        VecStringItem(
                            Array(x.value.reversed()),
                            call: [x, InstructionItem(.vecStringReverse)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let vecStringTake_Behavior =
        Behavior(
            .vecStringTake,
            takes: [.vecString, .int],
            fxn: { a in
                let (x, y) = (a[0] as! VecStringItem, a[1] as! IntItem)
                let range = x.value.count
                let idx = range - (min(range, max(y.value, 0)))
                let result = Array(x.value.dropLast(idx))

                return [
                    Router(
                        .vecString,
                        VecStringItem(
                            result,
                            call: [x, y, InstructionItem(.vecStringTake)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecStringDrop_Behavior =
        Behavior(
            .vecStringDrop,
            takes: [.vecString, .int],
            fxn: { a in
                let (x, y) = (a[0] as! VecStringItem, a[1] as! IntItem)
                let range = x.value.count
                let idx = (min(range, max(y.value, 0)))
                let result = Array(x.value.dropFirst(idx))

                return [
                    Router(
                        .vecString,
                        VecStringItem(
                            result,
                            call: [x, y, InstructionItem(.vecStringDrop)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecStringConj_Behavior =
        Behavior(
            .vecStringConj,
            takes: [.vecString, .string],
            fxn: { a in
                let (x, y) = (a[0] as! VecStringItem, a[1] as! StringItem)
                var result = x.value
                result.append(y.value)
                return [
                    Router(
                        .vecString,
                        VecStringItem(
                            result,
                            call: [x, y, InstructionItem(.vecStringConj)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecStringContains_Behavior =
        Behavior(
            .vecStringContains,
            takes: [.vecString, .string],
            fxn: { a in
                let (x, y) = (a[0] as! VecStringItem, a[1] as! StringItem)
                var result = x.value.contains(y.value)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            result,
                            call: [x, y, InstructionItem(.vecStringContains)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecStringFirst_Behavior =
        Behavior(
            .vecStringFirst,
            takes: [.vecString],
            fxn: { a in
                let (x) = (a[0] as! VecStringItem)
                if let result = x.value.first {
                    return [
                        Router(
                            .string,
                            StringItem(
                                result,
                                call: [x, InstructionItem(.vecStringFirst)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                } else {
                    return []
                }
            }
        )

    static let vecStringLast_Behavior =
        Behavior(
            .vecStringLast,
            takes: [.vecString],
            fxn: { a in
                let (x) = (a[0] as! VecStringItem)
                if let result = x.value.last {
                    return [
                        Router(
                            .string,
                            StringItem(
                                result,
                                call: [x, InstructionItem(.vecStringLast)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                } else {
                    return []
                }
            }
        )

    static let vecStringNth_Behavior =
        Behavior(
            .vecStringNth,
            takes: [.vecString, .int],
            fxn: { a in
                let (x, y) = (a[0] as! VecStringItem, a[1] as! IntItem)
                let range = x.value.count
                if range == 0 {
                    return []
                } else {
                    let position = abs(y.value)
                    let idx = position % range
                    let result = x.value[idx]
                    return [
                        Router(
                            .string,
                            StringItem(
                                result,
                                call: [x, y, InstructionItem(.vecStringNth)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            }
        )

    static let vecStringIndexOf_Behavior =
        Behavior(
            .vecStringIndexOf,
            takes: [.vecString, .string],
            fxn: { a in
                let (x, y) = (a[0] as! VecStringItem, a[1] as! StringItem)
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
                            call: [x, y, InstructionItem(.vecStringIndexOf)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecStringOccurrencesOf_Behavior =
        Behavior(
            .vecStringOccurrencesOf,
            takes: [.vecString, .string],
            fxn: { a in
                let (x, y) = (a[0] as! VecStringItem, a[1] as! StringItem)
                let result = x.value.count(where: { $0 == (y.value) })
                return [
                    Router(
                        .int,
                        IntItem(
                            result,
                            call: [
                                x, y, InstructionItem(.vecStringOccurrencesOf),
                            ],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let vecStringRemove_Behavior =
        Behavior(
            .vecStringRemove,
            takes: [.vecString, .string],
            fxn: { a in
                let (x, y) = (a[0] as! VecStringItem, a[1] as! StringItem)
                var result = x.value
                result.removeAll(where: { $0 == (y.value) })
                return [
                    Router(
                        .vecString,
                        VecStringItem(
                            result,
                            call: [x, y, InstructionItem(.vecStringRemove)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    // ( [1,2,3] 2 9 .vecStringReplace)
    //
    // replace every occurrence of 2 in the argument (above) with 9
    //
    static let vecStringReplace_Behavior =
        Behavior(
            .vecStringReplace,
            takes: [.vecString, .string, .string],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! VecStringItem,
                    a[1] as! StringItem,
                    a[2] as! StringItem
                )
                let result = x.value.map({ $0 == z.value ? y.value : $0 })
                return [
                    Router(
                        .vecString,
                        VecStringItem(
                            result,
                            call: [
                                x, z, y, InstructionItem(.vecStringReplace),
                            ],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
                    )
                ]
            }
        )

    // ( [1,1,2,3] 1 9 .vecStringReplaceFirst)
    //
    // replace the first occurrence of 1 in the argument (above) with 9
    //
    static let vecStringReplaceFirst_Behavior =
        Behavior(
            .vecStringReplaceFirst,
            takes: [.vecString, .string, .string],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! VecStringItem,
                    a[1] as! StringItem,
                    a[2] as! StringItem
                )
                var result = x.value
                if let idx = result.firstIndex(where: { $0 == z.value }) {
                    result[idx] = y.value
                }
                return [
                    Router(
                        .vecString,
                        VecStringItem(
                            result,
                            call: [
                                x, z, y,
                                InstructionItem(.vecStringReplaceFirst),
                            ],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
                    )
                ]
            }
        )

    // ( ["a","b","c"] 1 "foo" .vecStringSet)
    //
    // replace the element at position 1 in the argument (above) with "foo"
    //
    static let vecStringSet_Behavior =
        Behavior(
            .vecStringSet,
            takes: [.vecString, .int, .string],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! VecStringItem,
                    a[1] as! IntItem,
                    a[2] as! StringItem
                )
                var result = x.value
                if result.count > 0 {
                    let idx = abs(y.value) % (result.count)
                    result[idx] = z.value
                }
                return [
                    Router(
                        .vecString,
                        VecStringItem(
                            result,
                            call: [x, z, y, InstructionItem(.vecStringSet)],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
                    )
                ]
            }
        )

    // ( [1,1,2,3] 1 2 .vecStringSubVec)
    //
    // return a stretch of the original vector from positions 1...2
    // if idx1 is negative, make it zero
    // if idx2 < idx1, return an empty vector
    //
    static let vecStringSubVec_Behavior =
        Behavior(
            .vecStringSubVec,
            takes: [.vecString, .int, .int],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! VecStringItem,
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
                        .vecString,
                        VecStringItem(
                            result,
                            call: [x, z, y, InstructionItem(.vecStringSubVec)],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
                    )
                ]
            }
        )

    // ( [1,1,2,3] .vecStringPushAll)
    //
    // return every item on the argument (in reverse order)
    // routing them to the correct stack
    //
    static let vecStringPushAll_Behavior =
        Behavior(
            .vecStringPushAll,
            takes: [.vecString],
            fxn: { a in
                let (x) = (a[0] as! VecStringItem)
                var results = [Router]()
                let backwards = Array(x.value.reversed())
                for idx in 0..<backwards.count {
                    results.append(
                        Router(
                            .string,
                            StringItem(
                                backwards[idx],
                                call: [x, InstructionItem(.vecStringPushAll)],
                                isContingent: Behavior.netContingency(of: x),
                                index: backwards.count - idx - 1
                            )
                        )
                    )
                }
                return results
            }
        )

    // ( [1,1,2,3] .vecStringIterate MOUSE )
    //
    //               4          3            2                   1         0
    // reults: ( exec:MOUSE exec:remains exec:.vecStringIterate exec:MOUSE int:CHEESE )
    //
    static let vecStringIterate_Behavior =
        Behavior(
            .vecStringIterate,
            takes: [.vecString, .exec],
            fxn: { a in
                let (x, y) = (a[0] as! VecStringItem, a[1])
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
                            .string,
                            StringItem(
                                item,
                                call: [x, InstructionItem(.vecStringIterate)],
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
                                    .vecStringIterate,
                                    call: [
                                        x, InstructionItem(.vecStringIterate),
                                    ],
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
                                VecStringItem(
                                    workingVector,  // which was changed
                                    call: [
                                        x, InstructionItem(.vecStringIterate),
                                    ],
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

