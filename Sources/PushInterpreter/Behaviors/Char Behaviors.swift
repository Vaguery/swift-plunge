//
//  Char Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule

nonisolated extension Interpreter {

    /// The character whose Unicode scalar value is `code`, or nil if `code` is not
    /// a valid scalar (negative, past 0x10FFFF, or a surrogate).
    ///
    /// Character codes are scalar values in both directions (Roadmap #42), so
    /// `.charFromInt` and `.intFromChar` are inverses: `65 .charFromInt` is `A`.
    /// They used to map any number to `|n mod 95| + 32`, which made 65 an `a`.
    static func character(scalar code: Int) -> Character? {
        guard let bits = UInt32(exactly: code), let scalar = Unicode.Scalar(bits) else { return nil }
        return Character(scalar)
    }

    /// Truncates toward zero, then reads the result as a Unicode scalar value.
    static let charFromDouble_behavior =
        Behavior(
            .charFromDouble,
            takes: [.double],
            tags: [.fallible],
            fxn: { a, recording in
                let (x) = (a[0] as! DoubleItem)

                // Int(x.value) traps on non-finite or out-of-Int-range doubles,
                // so guard the conversion first.
                guard x.value.isFinite,
                    x.value >= Double(Int.min),
                    x.value < Double(Int.max)
                else {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .charFromDouble: \(x.value) → Int",
                                call: recording([x, InstructionItem(.charFromDouble)]))
                        )
                    ]
                }

                guard let c = character(scalar: Int(x.value)) else {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Not a Unicode scalar in .charFromDouble: \(x.value)",
                                kind: .conversion,
                                call: recording([x, InstructionItem(.charFromDouble)]))
                        )
                    ]
                }
                return [
                    Router(
                        .char,
                        CharItem(
                            c,
                            call: recording([x, InstructionItem(.charFromDouble)]))
                    )
                ]
            }
        )

    /// The character with this Unicode scalar value; an error if there is none.
    static let charFromInt_Behavior =
        Behavior(
            .charFromInt,
            takes: [.int],
            tags: [.fallible],
            fxn: { a, recording in
                let (x) = (a[0] as! IntItem)
                guard let c = character(scalar: x.value) else {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Not a Unicode scalar in .charFromInt: \(x.value)",
                                kind: .conversion,
                                call: recording([x, InstructionItem(.charFromInt)]))
                        )
                    ]
                }
                return [
                    Router(
                        .char,
                        CharItem(
                            c,
                            call: recording([x, InstructionItem(.charFromInt)]))
                    )
                ]
            }
        )

    static let charGT_Behavior =
        Behavior(
            .charGT,
            reads: [.char, .char],
            fxn: { a, recording in
                let (x, y) = (a[0] as! CharItem, a[1] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y > x,
                            call: recording(Behavior.reading([.char: 2], producing: .bool, from: [y, x, InstructionItem(.charGT)])))
                    )
                ]
            }
        )

    static let charGTE_Behavior =
        Behavior(
            .charGTE,
            reads: [.char, .char],
            fxn: { a, recording in
                let (x, y) = (a[0] as! CharItem, a[1] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y >= x,
                            call: recording(Behavior.reading([.char: 2], producing: .bool, from: [y, x, InstructionItem(.charGTE)])))
                    )
                ]
            }
        )

    static let charIsDigit_Behavior =
        Behavior(
            .charIsDigit,
            reads: [.char],
            fxn: { a, recording in
                let (x) = (a[0] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.isWholeNumber,
                            call: recording(Behavior.reading([.char: 1], producing: .bool, from: [x, InstructionItem(.charIsDigit)])))
                    )
                ]
            }
        )

    static let charIsLetter_Behavior =
        Behavior(
            .charIsLetter,
            reads: [.char],
            fxn: { a, recording in
                let (x) = (a[0] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.isLetter,
                            call: recording(Behavior.reading([.char: 1], producing: .bool, from: [x, InstructionItem(.charIsLetter)])))
                    )
                ]
            }
        )

    static let charIsWhitespace_Behavior =
        Behavior(
            .charIsWhitespace,
            reads: [.char],
            fxn: { a, recording in
                let (x) = (a[0] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.isWhitespace,
                            call: recording(Behavior.reading([.char: 1], producing: .bool, from: [x, InstructionItem(.charIsWhitespace)])))
                    )
                ]
            }
        )

    static let charLT_Behavior =
        Behavior(
            .charLT,
            reads: [.char, .char],
            fxn: { a, recording in
                let (x, y) = (a[0] as! CharItem, a[1] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y < x,
                            call: recording(Behavior.reading([.char: 2], producing: .bool, from: [y, x, InstructionItem(.charLT)])))
                    )
                ]
            }
        )

    static let charLTE_Behavior =
        Behavior(
            .charLTE,
            reads: [.char, .char],
            fxn: { a, recording in
                let (x, y) = (a[0] as! CharItem, a[1] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y <= x,
                            call: recording(Behavior.reading([.char: 2], producing: .bool, from: [y, x, InstructionItem(.charLTE)])))
                    )
                ]
            }
        )

    static let charBehaviors:[PushInstruction : Behavior] =
    [
        .charFromDouble : charFromDouble_behavior,
        .charFromInt : charFromInt_Behavior,
        .charIsDigit : charIsDigit_Behavior,
        .charIsLetter : charIsLetter_Behavior,
        .charIsWhitespace : charIsWhitespace_Behavior,
    ]
}
