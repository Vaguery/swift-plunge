//
//  Int Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule

nonisolated extension Interpreter {

    static let intAdd_Behavior =
        Behavior(
            .intAdd,
            takes: [.int, .int],
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)

                let (result, hasOverflowed) = y.value.addingReportingOverflow(
                    x.value
                )

                if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intAdd: \(y.value) + \(x.value)",
                                call: [y, x, InstructionItem(.intAdd)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: [y, x, InstructionItem(.intAdd)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            }
        )

    static let intSubtract_Behavior =
        Behavior(
            .intSubtract,
            takes: [.int, .int],
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)

                let (result, hasOverflowed) = y.value
                    .subtractingReportingOverflow(x.value)

                if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intSubtract: \(y.value) - \(x.value)",
                                call: [y, x, InstructionItem(.intSubtract)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: [y, x, InstructionItem(.intSubtract)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            }
        )

    static let intMultiply_Behavior =
        Behavior(
            .intMultiply,
            takes: [.int, .int],
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)

                let (result, hasOverflowed) = y.value
                    .multipliedReportingOverflow(by: x.value)

                if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intMultiply: \(y.value) * \(x.value)",
                                call: [y, x, InstructionItem(.intMultiply)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: [y, x, InstructionItem(.intMultiply)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            }
        )

    static let intMax_Behavior =
        Behavior(
            .intMax,
            takes: [.int, .int],
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            max(y.value, x.value),
                            call: [y, x, InstructionItem(.intMax)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let intMin_Behavior =
        Behavior(
            .intMin,
            takes: [.int, .int],
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            min(y.value, x.value),
                            call: [y, x, InstructionItem(.intMin)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let intQuot_Behavior =
        Behavior(
            .intQuot,
            takes: [.int, .int],
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)

                let (result, hasOverflowed) = y.value.dividedReportingOverflow(
                    by: x.value
                )

                // check the zero divisor first: dividedReportingOverflow(by: 0)
                // also reports overflow, so this must precede the overflow branch
                if x.value == 0 {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Divide by zero .intQuot: \(y.value) / \(x.value)",
                                call: [y, x, InstructionItem(.intQuot)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                } else if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intQuot: \(y.value) / \(x.value)",
                                call: [y, x, InstructionItem(.intQuot)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: [y, x, InstructionItem(.intQuot)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            }
        )

    static let intMod_Behavior =
        Behavior(
            .intMod,
            takes: [.int, .int],
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)

                let (result, hasOverflowed) = y.value
                    .remainderReportingOverflow(dividingBy: x.value)

                // check the zero divisor first: remainderReportingOverflow(dividingBy: 0)
                // also reports overflow, so this must precede the overflow branch
                if x.value == 0 {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Divide by zero .intMod: \(y.value) % \(x.value)",
                                call: [y, x, InstructionItem(.intMod)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                } else if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intMod: \(y.value) % \(x.value)",
                                call: [y, x, InstructionItem(.intMod)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: [y, x, InstructionItem(.intMod)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            }
        )

    static let intGT_Behavior =
        Behavior(
            .intGT,
            takes: [.int, .int],
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y.value > x.value,
                            call: [y, x, InstructionItem(.intGT)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let intGTE_Behavior =
        Behavior(
            .intGTE,
            takes: [.int, .int],
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y.value >= x.value,
                            call: [y, x, InstructionItem(.intGTE)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let intLTE_Behavior =
        Behavior(
            .intLTE,
            takes: [.int, .int],
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y.value <= x.value,
                            call: [y, x, InstructionItem(.intLTE)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let intLT_Behavior =
        Behavior(
            .intLT,
            takes: [.int, .int],
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y.value < x.value,
                            call: [y, x, InstructionItem(.intLT)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let intInc_Behavior =
        Behavior(
            .intInc,
            takes: [.int],
            fxn: { a in
                let (x) = (a[0] as! IntItem)
                let (result, hasOverflowed) = x.value.addingReportingOverflow(1)

                if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intInc: \(x.value) + 1»",
                                call: [x, InstructionItem(.intInc)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: [x, InstructionItem(.intInc)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            }
        )

    static let intDec_Behavior =
        Behavior(
            .intDec,
            takes: [.int],
            fxn: { a in
                let (x) = (a[0] as! IntItem)
                let (result, hasOverflowed) = x.value
                    .subtractingReportingOverflow(1)

                if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intDec: \(x.value) - 1»",
                                call: [x, InstructionItem(.intDec)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: [x, InstructionItem(.intDec)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            }
        )

    static let intFromBool_Behavior =
        Behavior(
            .intFromBool,
            takes: [.bool],
            fxn: { a in
                let (x) = (a[0] as! BoolItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            x.value ? 1 : 0,
                            call: [x, InstructionItem(.intFromBool)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let intFromChar_Behavior =
        Behavior(
            .intFromChar,
            takes: [.char],
            fxn: { a in
                let (c) = (a[0] as! CharItem)
                if let v = c.value.asciiValue {
                    return [
                        Router(
                            .int,
                            IntItem(
                                Int(v),
                                call: [c, InstructionItem(.intFromChar)],
                                isContingent: Behavior.netContingency(of: c)
                            )
                        )
                    ]
                } else {
                    return []
                }
            }
        )

    static let intFromString_Behavior =
        Behavior(
            .intFromString,
            takes: [.string],
            fxn: { a in
                let (s) = (a[0] as! StringItem)
                if let v = Int(s.value) {
                    return [
                        Router(
                            .int,
                            IntItem(
                                v,
                                call: [s, InstructionItem(.intFromString)],
                                isContingent: Behavior.netContingency(of: s)
                            )
                        )
                    ]
                } else {
                    return []
                }
            }
        )

    static let intFromDouble_Behavior =
        Behavior(
            .intFromDouble,
            takes: [.double],
            fxn: { a in
                let (x) = (a[0] as! DoubleItem)

                // Int(x.value) traps on non-finite or out-of-Int-range doubles
                guard x.value.isFinite,
                    x.value >= Double(Int.min),
                    x.value < Double(Int.max)
                else {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intFromDouble: \(x.value) → Int",
                                call: [x, InstructionItem(.intFromDouble)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }

                return [
                    Router(
                        .int,
                        IntItem(
                            Int(x.value),
                            call: [x, InstructionItem(.intFromDouble)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let intBehaviors:[PushInstruction : Behavior] =
        [
            .intAdd : intAdd_Behavior,
            .intDec : intDec_Behavior,
            .intFromBool : intFromBool_Behavior,
            .intFromChar : intFromChar_Behavior,
            .intFromDouble : intFromDouble_Behavior,
            .intFromString : intFromString_Behavior,
            .intGT : intGT_Behavior,
            .intGTE : intGTE_Behavior,
            .intInc : intInc_Behavior,
            .intLT : intLT_Behavior,
            .intLTE : intLTE_Behavior,
            .intMax : intMax_Behavior,
            .intMin : intMin_Behavior,
            .intMod : intMod_Behavior,
            .intMultiply : intMultiply_Behavior,
            .intQuot : intQuot_Behavior,
            .intSubtract : intSubtract_Behavior,
        ]

}
