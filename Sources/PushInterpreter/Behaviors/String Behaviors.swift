////
////  String Behaviors.swift
////  Propeller in Swift
////
////  Created by William Tozier on 5/9/26.
////

import DequeModule

extension Interpreter {

    static let stringButLast_Behavior =
        Behavior(
            .stringButLast,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.dropLast(1)),
                            call: [x, InstructionItem(.stringButLast)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringConcat_Behavior =
        Behavior(
            .stringConcat,
            takes: [.string, .string],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            y.value + x.value,
                            call: [y, x, InstructionItem(.stringConcat)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringConjChar_Behavior =
        Behavior(
            .stringConjChar,
            takes: [.string, .char],
            fxn: { a in
                let (y, x) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            y.value + String(x.value),
                            call: [y, x, InstructionItem(.stringConjChar)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringContains_Behavior =
        Behavior(
            .stringContains,
            takes: [.string, .string],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y.value.contains(x.value),
                            call: [y, x, InstructionItem(.stringContains)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringContainsChar_Behavior =
        Behavior(
            .stringContainsChar,
            takes: [.string, .char],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.contains(y.value),
                            call: [y, x, InstructionItem(.stringContainsChar)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringIndexOfChar_Behavior =
        Behavior(
            .stringIndexOfChar,
            takes: [.string, .char],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                if let idx = x.value.firstIndex(of: y.value) {
                    let intIdx = x.value.distance(
                        from: x.value.startIndex,
                        to: idx
                    )
                    return [
                        Router(
                            .int,
                            IntItem(
                                intIdx,
                                call: [
                                    y, x, InstructionItem(.stringIndexOfChar),
                                ],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                } else {
                    return []  // not found
                }
            }
        )

    // the IntItem value is truncated at 0 before use as an index
    //
    static let stringDrop_Behavior =
        Behavior(
            .stringDrop,
            takes: [.string, .int],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                let toDrop = max(0, y.value)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.dropLast(toDrop)),
                            call: [y, x, InstructionItem(.stringDrop)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    // the IntItem value is truncated at 0 before use as an index
    //
    static let stringTake_Behavior =
        Behavior(
            .stringTake,
            takes: [.string, .int],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                let toTake = max(0, y.value)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.prefix(toTake)),
                            call: [y, x, InstructionItem(.stringTake)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringIsEmpty_Behavior =
        Behavior(
            .stringIsEmpty,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.isEmpty,
                            call: [x, InstructionItem(.stringIsEmpty)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringFirst_Behavior =
        Behavior(
            .stringFirst,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                if let c = x.value.first {
                    return [
                        Router(
                            .char,
                            CharItem(
                                c,
                                call: [x, InstructionItem(.stringFirst)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                } else {
                    return []  // empty string
                }
            }
        )

    static let stringLast_Behavior =
        Behavior(
            .stringLast,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                if let c = x.value.last {
                    return [
                        Router(
                            .char,
                            CharItem(
                                c,
                                call: [x, InstructionItem(.stringLast)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                } else {
                    return []  // empty string
                }
            }
        )

    static let stringLTE_Behavior =
        Behavior(
            .stringLTE,
            takes: [.string, .string],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y <= x,
                            call: [y, x, InstructionItem(.stringLTE)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringLT_Behavior =
        Behavior(
            .stringLT,
            takes: [.string, .string],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y < x,
                            call: [y, x, InstructionItem(.stringLT)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringGT_Behavior =
        Behavior(
            .stringGT,
            takes: [.string, .string],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y > x,
                            call: [y, x, InstructionItem(.stringGT)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringGTE_Behavior =
        Behavior(
            .stringGTE,
            takes: [.string, .string],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y >= x,
                            call: [y, x, InstructionItem(.stringGTE)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringReverse_Behavior =
        Behavior(
            .stringReverse,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.reversed()),
                            call: [x, InstructionItem(.stringReverse)],
                            isContingent: Behavior.netContingency(of: x, )
                        )
                    )
                ]
            }
        )

    static let stringLength_Behavior =
        Behavior(
            .stringLength,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            x.value.count,
                            call: [x, InstructionItem(.stringLength)],
                            isContingent: Behavior.netContingency(of: x, )
                        )
                    )
                ]
            }
        )

    static let stringFromBool_Behavior =
        Behavior(
            .stringFromBool,
            takes: [.bool],
            fxn: { a in
                let (x) = (a[0] as! BoolItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: [x, InstructionItem(.stringFromBool)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringFromChar_Behavior =
        Behavior(
            .stringFromChar,
            takes: [.char],
            fxn: { a in
                let (x) = (a[0] as! CharItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: [x, InstructionItem(.stringFromChar)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringFromDouble_Behavior =
        Behavior(
            .stringFromDouble,
            takes: [.double],
            fxn: { a in
                let (x) = (a[0] as! DoubleItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: [x, InstructionItem(.stringFromDouble)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringFromInt_Behavior =
        Behavior(
            .stringFromInt,
            takes: [.int],
            fxn: { a in
                let (x) = (a[0] as! IntItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: [x, InstructionItem(.stringFromInt)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringNth_Behavior =
        Behavior(
            .stringNth,
            takes: [.string, .int],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                if x.value.isEmpty {
                    return []
                } else {
                    let moduloIdx = (max(0, y.value) % x.value.count)
                    let idx = x.value.index(
                        x.value.startIndex,
                        offsetBy: moduloIdx
                    )
                    let c = x.value[idx]
                    return [
                        Router(
                            .char,
                            CharItem(
                                c,
                                call: [y, x, InstructionItem(.stringNth)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            }
        )

    // produces one substring of one character each for every character in the string
    // the stack will read backwards vs the order in the string
    //
    static let stringParseToLetters_Behavior =
        Behavior(
            .stringParseToLetters,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                let chars = x.value.split(separator: "")
                var results: [Router] = []
                for (idx, c) in chars.enumerated() {
                    results.append(
                        Router(
                            .string,
                            StringItem(
                                String(c),
                                call: [
                                    x, InstructionItem(.stringParseToLetters),
                                ],
                                isContingent: Behavior.netContingency(of: x),
                                index: idx
                            )
                        )
                    )
                }
                return results
            }
        )

    static let stringOccurrencesOfChar_Behavior =
        Behavior(
            .stringOccurrencesOfChar,
            takes: [.string, .char],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            x.value.filter({ $0 == y.value }).count,
                            call: [
                                y, x, InstructionItem(.stringOccurrencesOfChar),
                            ],
                            isContingent: Behavior.netContingency(of: x, y),
                        )
                    )
                ]
            }
        )

    static let stringRemoveChar_Behavior =
        Behavior(
            .stringRemoveChar,
            takes: [.string, .char],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            x.value.filter({ $0 != y.value }),
                            call: [y, x, InstructionItem(.stringRemoveChar)],
                            isContingent: Behavior.netContingency(of: x, y),
                        )
                    )
                ]
            }
        )

    // ( "0123" '2' '.' .stringReplaceChar ) -> "01.3"
    //
    static let stringReplaceChar_Behavior =
        Behavior(
            .stringReplaceChar,
            takes: [.string, .char, .char],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! StringItem,
                    a[1] as! CharItem,
                    a[2] as! CharItem
                )
                return [
                    Router(
                        .string,
                        StringItem(
                            x.value.replacing(
                                String(z.value),
                                with: String(y.value)
                            ),
                            call: [
                                z, y, x, InstructionItem(.stringRemoveChar),
                            ],
                            isContingent: Behavior.netContingency(of: x, y, z),
                        )
                    )
                ]
            }
        )

    static let stringReplaceFirstChar_Behavior =
        Behavior(
            .stringReplaceFirstChar,
            takes: [.string, .char, .char],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! StringItem,
                    a[1] as! CharItem,
                    a[2] as! CharItem
                )
                return [
                    Router(
                        .string,
                        StringItem(
                            x.value.replacing(
                                String(z.value),
                                with: String(y.value),
                                maxReplacements: 1
                            ),
                            call: [
                                z, y, x,
                                InstructionItem(.stringReplaceFirstChar),
                            ],
                            isContingent: Behavior.netContingency(of: x, y, z),
                        )
                    )
                ]
            }
        )

    // ("foo" "o" "g" .stringReplace) -> "fgg"
    //
    static let stringReplace_Behavior =
        Behavior(
            .stringReplace,
            takes: [.string, .string, .string],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! StringItem,  // replacement
                    a[1] as! StringItem,  // target
                    a[2] as! StringItem
                )  // in this context
                return [
                    Router(
                        .string,
                        StringItem(
                            z.value.replacing(y.value, with: x.value),
                            call: [z, y, x, InstructionItem(.stringReplace)],
                            isContingent: Behavior.netContingency(of: x, y, z),
                        )
                    )
                ]
            }
        )

    static let stringReplaceFirst_Behavior =
        Behavior(
            .stringReplaceFirst,
            takes: [.string, .string, .string],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! StringItem,  // replacement
                    a[1] as! StringItem,  // target
                    a[2] as! StringItem
                )  // in this context
                return [
                    Router(
                        .string,
                        StringItem(
                            z.value.replacing(
                                y.value,
                                with: x.value,
                                maxReplacements: 1
                            ),
                            call: [z, y, x, InstructionItem(.stringReplace)],
                            isContingent: Behavior.netContingency(of: x, y, z),
                        )
                    )
                ]
            }
        )

    static let stringRest_Behavior =
        Behavior(
            .stringRest,
            takes: [.string],
            fxn: { a in
                var (x) = (a[0] as! StringItem)
                let result = String(x.value.dropFirst(1))
                return [
                    Router(
                        .string,
                        StringItem(
                            result,
                            call: [x, InstructionItem(.stringRest)],
                            isContingent: Behavior.netContingency(of: x),
                        )
                    )
                ]
            }
        )

    static let stringSetChar_Behavior =
        Behavior(
            .stringSetChar,
            takes: [.string, .int, .char],
            fxn: { a in
                var (x, y, z) = (
                    a[0] as! StringItem,
                    a[1] as! IntItem,
                    a[2] as! CharItem
                )
                var result = x.value
                if result.count > 0 {
                    let moduloIdx = (max(0, y.value) % result.count)
                    let idx = result.index(
                        result.startIndex,
                        offsetBy: moduloIdx
                    )
                    result.replaceSubrange(idx...idx, with: String(z.value))
                }
                return [
                    Router(
                        .string,
                        StringItem(
                            result,
                            call: [z, y, x, InstructionItem(.stringSetChar)],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
                    )
                ]
            }
        )

    // returns every substring delimited by whitespace, if any
    // unlike stringButLast, which always returns a string, this might not return anything
    //
    static let stringSplit_Behavior =
        Behavior(
            .stringSplit,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                var result = [Router]()
                let chunks = x.value.split { $0.isWhitespace }
                for (idx, chunk) in chunks.enumerated() {
                    result.append(
                        Router(
                            .string,
                            StringItem(
                                String(chunk),
                                call: [x, InstructionItem(.stringSplit)],
                                isContingent: Behavior.netContingency(of: x),
                                index: idx
                            )
                        )
                    )
                }
                return result
            }
        )

    static let stringSubstring_Behavior =
        Behavior(
            .stringSubstring,
            takes: [.string, .int, .int],
            fxn: { a in
                let (x, y, z) = (
                    a[0] as! StringItem,
                    a[1] as! IntItem,
                    a[2] as! IntItem
                )

                var result = x.value
                var slice = Substring(result)
                if result.count > 0 {
                    let range = result.count - 1
                    let lhs = min(range, max(0, z.value))
                    let rhs = min(range, max(0, z.value, y.value))
                    let start = result.index(result.startIndex, offsetBy: lhs)
                    let end = result.index(result.startIndex, offsetBy: rhs)
                    slice = result[start...end]
                }
                return [
                    Router(
                        .string,
                        StringItem(
                            String(slice),
                            call: [x, z, y, InstructionItem(.stringSubstring)],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
                    )
                ]
            }
        )

    // ( "abcd" .stringIterate MOUSE )
    //
    // index:        4          3          2                   1          0
    // reults: ( exec:MOUSE exec:"bcd" exec:.stringIterate exec:MOUSE char:'a' )
    //
    // TODO: explain what THE MOUSE is
    //
    static let stringIterate_Behavior =
        Behavior(
            .stringIterate,
            takes: [.string, .exec],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1])
                var results = [Router]()
                var workingString = x.value

                var mouseCopy = a[1]
                let count = workingString.count
                if count > 0 {
                    mouseCopy.index = 1
                    results.append(Router(.exec, mouseCopy))  //1

                    let item = workingString.removeFirst()
                    results.append(
                        Router(
                            .char,
                            CharItem(
                                item,
                                call: [x, InstructionItem(.stringIterate), y],
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
                                    .stringIterate,
                                    call: [
                                        x, InstructionItem(.stringIterate), y,
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
                                StringItem(
                                    workingString,  // which was changed
                                    call: [
                                        x, InstructionItem(.stringIterate), y,
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

    static let stringPushAllChars_Behavior =
        Behavior(
            .stringPushAllChars,
            takes: [.string],
            fxn: { a in
                let (s) = (a[0] as! StringItem)

                var results = [Router]()
                if s.value.count > 0 {
                    let chars = Array(s.value)
                    for (idx, char) in chars.enumerated() {
                        results.append(
                            Router(
                                .char,
                                CharItem(
                                    char,
                                    call: [
                                        s, InstructionItem(.stringPushAllChars),
                                    ],
                                    isContingent: Behavior.netContingency(
                                        of: s
                                    ),
                                    index: idx
                                )
                            )
                        )
                    }
                }
                return results
            }
        )

    static let stringBehaviors:[PushInstruction : Behavior] =
       [
        .stringButLast : stringButLast_Behavior,
        .stringConcat : stringConcat_Behavior,
        .stringConjChar : stringConjChar_Behavior,
        .stringContains : stringContains_Behavior,
        .stringContainsChar : stringContainsChar_Behavior,
        .stringDrop : stringDrop_Behavior,
        .stringFirst : stringFirst_Behavior,
        .stringFromBool : stringFromBool_Behavior,
        .stringFromChar : stringFromChar_Behavior,
        .stringFromDouble : stringFromDouble_Behavior,
        .stringFromInt : stringFromInt_Behavior,
        .stringGT : stringGT_Behavior,
        .stringGTE : stringGTE_Behavior,
        .stringIndexOfChar : stringIndexOfChar_Behavior,
        .stringIsEmpty : stringIsEmpty_Behavior,
        .stringIterate : stringIterate_Behavior,
        .stringLast : stringLast_Behavior,
        .stringLength : stringLength_Behavior,
        .stringLT : stringLT_Behavior,
        .stringLTE : stringLTE_Behavior,
        .stringNth : stringNth_Behavior,
        .stringOccurrencesOfChar : stringOccurrencesOfChar_Behavior,
        .stringParseToLetters : stringParseToLetters_Behavior,
        .stringPushAllChars : stringPushAllChars_Behavior,
        .stringRemoveChar : stringRemoveChar_Behavior,
        .stringReplace : stringReplace_Behavior,
        .stringReplaceChar : stringReplaceChar_Behavior,
        .stringReplaceFirst : stringReplaceFirst_Behavior,
        .stringReplaceFirstChar : stringReplaceFirstChar_Behavior,
        .stringRest : stringRest_Behavior,
        .stringReverse : stringReverse_Behavior,
        .stringSetChar : stringSetChar_Behavior,
        .stringSplit : stringSplit_Behavior,
        .stringSubstring : stringSubstring_Behavior,
        .stringTake : stringTake_Behavior,
    ]
}
