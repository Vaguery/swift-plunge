//
//  Char Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule

extension Interpreter {

    // the propeller definition is incorrect, in that it includes the first 32 unprintable characters
    static let charFromInt_Behavior =
        Behavior(
            .charFromInt,
            takes: [.int],
            fxn: { a in
                let (x) = (a[0] as! IntItem)
                let c = Character(UnicodeScalar(abs(x.value % 95) + 32)!)
                return [
                    Router(
                        .char,
                        CharItem(
                            c,
                            call: [x, InstructionItem(.charFromInt)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    // the propeller definition is incorrect, in that it includes the first 32 unprintable characters
    static let charFromDouble_behavior =
        Behavior(
            .charFromDouble,
            takes: [.double],
            fxn: { a in
                let (x) = (a[0] as! DoubleItem)
                let c = Character(Unicode.Scalar(abs(Int(x.value) % 95) + 32)!)
                return [
                    Router(
                        .char,
                        CharItem(
                            c,
                            call: [x, InstructionItem(.charFromDouble)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let charIsLetter_Behavior =
        Behavior(
            .charIsLetter,
            takes: [.char],
            fxn: { a in
                let (x) = (a[0] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.isLetter,
                            call: [x, InstructionItem(.charIsLetter)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let charIsDigit_Behavior =
        Behavior(
            .charIsDigit,
            takes: [.char],
            fxn: { a in
                let (x) = (a[0] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.isWholeNumber,
                            call: [x, InstructionItem(.charIsDigit)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let charIsWhitespace_Behavior =
        Behavior(
            .charIsWhitespace,
            takes: [.char],
            fxn: { a in
                let (x) = (a[0] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.isWhitespace,
                            call: [x, InstructionItem(.charIsWhitespace)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let charGT_Behavior =
        Behavior(
            .charGT,
            takes: [.char, .char],
            fxn: { a in
                let (x, y) = (a[0] as! CharItem, a[1] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y > x,
                            call: [y, x, InstructionItem(.charGT)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let charGTE_Behavior =
        Behavior(
            .charGTE,
            takes: [.char, .char],
            fxn: { a in
                let (x, y) = (a[0] as! CharItem, a[1] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y >= x,
                            call: [y, x, InstructionItem(.charGT)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let charLT_Behavior =
        Behavior(
            .charLT,
            takes: [.char, .char],
            fxn: { a in
                let (x, y) = (a[0] as! CharItem, a[1] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y < x,
                            call: [y, x, InstructionItem(.charLT)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let charLTE_Behavior =
        Behavior(
            .charLTE,
            takes: [.char, .char],
            fxn: { a in
                let (x, y) = (a[0] as! CharItem, a[1] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y <= x,
                            call: [y, x, InstructionItem(.charLTE)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let charBehaviors:[PushInstruction : Behavior] =
    [
        .charFromDouble : charFromDouble_behavior,
        .charFromInt : charFromInt_Behavior,
        .charGT : charGT_Behavior,
        .charGTE : charGTE_Behavior,
        .charIsDigit : charIsDigit_Behavior,
        .charIsLetter : charIsLetter_Behavior,
        .charIsWhitespace : charIsWhitespace_Behavior,
        .charLT : charLT_Behavior,
        .charLTE : charLTE_Behavior,
    ]
}
