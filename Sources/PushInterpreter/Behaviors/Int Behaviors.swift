//
//  Int Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule

nonisolated extension Interpreter {

    static let intAdd_Behavior =
        Behavior(
            .intAdd,
            takes: [.int, .int],
            tags: [.fallible],
            fxn: { a, recording in
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
                                call: recording([y, x, InstructionItem(.intAdd)]))
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: recording([y, x, InstructionItem(.intAdd)]))
                        )
                    ]
                }
            }
        )

    static let intSubtract_Behavior =
        Behavior(
            .intSubtract,
            takes: [.int, .int],
            tags: [.fallible],
            fxn: { a, recording in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)

                let (result, hasOverflowed) = y.value
                    .subtractingReportingOverflow(x.value)

                if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intSubtract: \(y.value) - \(x.value)",
                                call: recording([y, x, InstructionItem(.intSubtract)]))
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: recording([y, x, InstructionItem(.intSubtract)]))
                        )
                    ]
                }
            }
        )

    static let intMultiply_Behavior =
        Behavior(
            .intMultiply,
            takes: [.int, .int],
            tags: [.fallible],
            fxn: { a, recording in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)

                let (result, hasOverflowed) = y.value
                    .multipliedReportingOverflow(by: x.value)

                if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intMultiply: \(y.value) * \(x.value)",
                                call: recording([y, x, InstructionItem(.intMultiply)]))
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: recording([y, x, InstructionItem(.intMultiply)]))
                        )
                    ]
                }
            }
        )

    static let intMax_Behavior =
        Behavior(
            .intMax,
            takes: [.int, .int],
            fxn: { a, recording in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            max(y.value, x.value),
                            call: recording([y, x, InstructionItem(.intMax)]))
                    )
                ]
            }
        )

    static let intMin_Behavior =
        Behavior(
            .intMin,
            takes: [.int, .int],
            fxn: { a, recording in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            min(y.value, x.value),
                            call: recording([y, x, InstructionItem(.intMin)]))
                    )
                ]
            }
        )

    static let intQuot_Behavior =
        Behavior(
            .intQuot,
            takes: [.int, .int],
            tags: [.fallible],
            fxn: { a, recording in
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
                                call: recording([y, x, InstructionItem(.intQuot)]))
                        )
                    ]
                } else if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intQuot: \(y.value) / \(x.value)",
                                call: recording([y, x, InstructionItem(.intQuot)]))
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: recording([y, x, InstructionItem(.intQuot)]))
                        )
                    ]
                }
            }
        )

    static let intMod_Behavior =
        Behavior(
            .intMod,
            takes: [.int, .int],
            tags: [.fallible],
            fxn: { a, recording in
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
                                call: recording([y, x, InstructionItem(.intMod)]))
                        )
                    ]
                } else if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intMod: \(y.value) % \(x.value)",
                                call: recording([y, x, InstructionItem(.intMod)]))
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: recording([y, x, InstructionItem(.intMod)]))
                        )
                    ]
                }
            }
        )

    static let intGT_Behavior =
        Behavior(
            .intGT,
            reads: [.int, .int],
            fxn: { a, recording in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y.value > x.value,
                            call: recording(Behavior.reading([.int: 2], producing: .bool, from: [y, x, InstructionItem(.intGT)])))
                    )
                ]
            }
        )

    static let intGTE_Behavior =
        Behavior(
            .intGTE,
            reads: [.int, .int],
            fxn: { a, recording in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y.value >= x.value,
                            call: recording(Behavior.reading([.int: 2], producing: .bool, from: [y, x, InstructionItem(.intGTE)])))
                    )
                ]
            }
        )

    static let intLTE_Behavior =
        Behavior(
            .intLTE,
            reads: [.int, .int],
            fxn: { a, recording in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y.value <= x.value,
                            call: recording(Behavior.reading([.int: 2], producing: .bool, from: [y, x, InstructionItem(.intLTE)])))
                    )
                ]
            }
        )

    static let intLT_Behavior =
        Behavior(
            .intLT,
            reads: [.int, .int],
            fxn: { a, recording in
                let (x, y) = (a[0] as! IntItem, a[1] as! IntItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y.value < x.value,
                            call: recording(Behavior.reading([.int: 2], producing: .bool, from: [y, x, InstructionItem(.intLT)])))
                    )
                ]
            }
        )

    static let intInc_Behavior =
        Behavior(
            .intInc,
            takes: [.int],
            tags: [.fallible],
            fxn: { a, recording in
                let (x) = (a[0] as! IntItem)
                let (result, hasOverflowed) = x.value.addingReportingOverflow(1)

                if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intInc: \(x.value) + 1»",
                                call: recording([x, InstructionItem(.intInc)]))
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: recording([x, InstructionItem(.intInc)]))
                        )
                    ]
                }
            }
        )

    static let intDec_Behavior =
        Behavior(
            .intDec,
            takes: [.int],
            tags: [.fallible],
            fxn: { a, recording in
                let (x) = (a[0] as! IntItem)
                let (result, hasOverflowed) = x.value
                    .subtractingReportingOverflow(1)

                if hasOverflowed {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .intDec: \(x.value) - 1»",
                                call: recording([x, InstructionItem(.intDec)]))
                        )
                    ]
                } else {
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call: recording([x, InstructionItem(.intDec)]))
                        )
                    ]
                }
            }
        )

    static let intFromBool_Behavior =
        Behavior(
            .intFromBool,
            takes: [.bool],
            fxn: { a, recording in
                let (x) = (a[0] as! BoolItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            x.value ? 1 : 0,
                            call: recording([x, InstructionItem(.intFromBool)]))
                    )
                ]
            }
        )

    /// The character's Unicode scalar value, the inverse of `.charFromInt`. A
    /// character made of several scalars (a flag, a letter with a combining
    /// accent) has no single code, so it is an error.
    static let intFromChar_Behavior =
        Behavior(
            .intFromChar,
            takes: [.char],
            tags: [.fallible],
            fxn: { a, recording in
                let (c) = (a[0] as! CharItem)
                let scalars = c.value.unicodeScalars
                guard scalars.count == 1, let scalar = scalars.first else {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Several Unicode scalars in .intFromChar: \(c.value)",
                                kind: .conversion,
                                call: recording([c, InstructionItem(.intFromChar)]))
                        )
                    ]
                }
                return [
                    Router(
                        .int,
                        IntItem(
                            Int(scalar.value),
                            call: recording([c, InstructionItem(.intFromChar)]))
                    )
                ]
            }
        )

    /// The string read as an integer; an error if it is not one.
    static let intFromString_Behavior =
        Behavior(
            .intFromString,
            takes: [.string],
            tags: [.fallible],
            fxn: { a, recording in
                let (s) = (a[0] as! StringItem)
                guard let v = Int(s.value) else {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Not an integer in .intFromString: \"\(s.value)\"",
                                kind: .conversion,
                                call: recording([s, InstructionItem(.intFromString)]))
                        )
                    ]
                }
                return [
                    Router(
                        .int,
                        IntItem(
                            v,
                            call: recording([s, InstructionItem(.intFromString)]))
                    )
                ]
            }
        )

    static let intFromDouble_Behavior =
        Behavior(
            .intFromDouble,
            takes: [.double],
            tags: [.fallible],
            fxn: { a, recording in
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
                                call: recording([x, InstructionItem(.intFromDouble)]))
                        )
                    ]
                }

                return [
                    Router(
                        .int,
                        IntItem(
                            Int(x.value),
                            call: recording([x, InstructionItem(.intFromDouble)]))
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
            .intInc : intInc_Behavior,
            .intMax : intMax_Behavior,
            .intMin : intMin_Behavior,
            .intMod : intMod_Behavior,
            .intMultiply : intMultiply_Behavior,
            .intQuot : intQuot_Behavior,
            .intSubtract : intSubtract_Behavior,
        ]

}
