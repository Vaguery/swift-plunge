//
//  Bool Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/31/26.
//

import DequeModule

nonisolated extension Interpreter {

    static let boolAnd_Behavior =
        Behavior(
            .boolAnd,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                let (arg1, arg2) = (x.value, y.value)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            arg1 && arg2,
                            call: [y, x, InstructionItem(.boolAnd)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolFromDouble_Behavior =
        Behavior(
            .boolFromDouble,
            takes: [.double],
            fxn: { a in
                let (x) = (a[0] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value != 0.0,
                            call: [x, InstructionItem(.boolFromDouble)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let boolFromInt_Behavior =
        Behavior(
            .boolFromInt,
            takes: [.int],
            fxn: { a in
                let (x) = (a[0] as! IntItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value != 0,
                            call: [x, InstructionItem(.boolFromInt)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let boolIfPThenQ_Behavior =
        Behavior(
            .boolIfPThenQ,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value || !y.value,
                            call: [y, x, InstructionItem(.boolIfPThenQ)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolIfQThenP_Behavior =
        Behavior(
            .boolIfQThenP,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            !x.value || y.value,
                            call: [y, x, InstructionItem(.boolIfQThenP)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolNand_Behavior =
        Behavior(
            .boolNand,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                let (arg1, arg2) = (x.value, y.value)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            !(arg1 && arg2),
                            call: [y, x, InstructionItem(.boolNand)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolNor_Behavior =
        Behavior(
            .boolNor,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                let (arg1, arg2) = (x.value, y.value)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            !(arg1 || arg2),
                            call: [y, x, InstructionItem(.boolNor)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolNot_Behavior =
        Behavior(
            .boolNot,
            takes: [.bool],
            fxn: { a in
                let (x) = (a[0] as! BoolItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            !x.value,
                            call: [
                                x,
                                InstructionItem(.boolNot),
                            ],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let boolNotP_Behavior =
        Behavior(
            .boolNotP,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            !y.value,
                            call: [y, x, InstructionItem(.boolNotP)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolNotPandQ_Behavior =
        Behavior(
            .boolNotPandQ,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            !y.value && x.value,
                            call: [y, x, InstructionItem(.boolNotPandQ)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolNotQ_Behavior =
        Behavior(
            .boolNotQ,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            !x.value,
                            call: [y, x, InstructionItem(.boolNotQ)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolOr_Behavior =
        Behavior(
            .boolOr,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                let (arg1, arg2) = (x.value, y.value)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            arg1 || arg2,
                            call: [y, x, InstructionItem(.boolOr)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolP_Behavior =
        Behavior(
            .boolP,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y.value,
                            call: [y, x, InstructionItem(.boolP)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolPandNotQ_Behavior =
        Behavior(
            .boolPandNotQ,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y.value && !x.value,
                            call: [y, x, InstructionItem(.boolPandNotQ)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolQ_Behavior =
        Behavior(
            .boolQ,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value,
                            call: [y, x, InstructionItem(.boolQ)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolXnor_Behavior =
        Behavior(
            .boolXnor,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                let (arg1, arg2) = (x.value, y.value)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            arg1 == arg2,
                            call: [y, x, InstructionItem(.boolXnor)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolXor_Behavior =
        Behavior(
            .boolXor,
            takes: [.bool, .bool],
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                let (arg1, arg2) = (x.value, y.value)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            arg1 != arg2,
                            call: [y, x, InstructionItem(.boolXor)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let boolBehaviors: [PushInstruction: Behavior] =
        [
            .boolAnd: boolAnd_Behavior,
            .boolFromDouble: boolFromDouble_Behavior,
            .boolFromInt: boolFromInt_Behavior,
            .boolIfPThenQ: boolIfPThenQ_Behavior,
            .boolIfQThenP: boolIfQThenP_Behavior,
            .boolNand: boolNand_Behavior,
            .boolNor: boolNor_Behavior,
            .boolNot: boolNot_Behavior,
            .boolNotP: boolNotP_Behavior,
            .boolNotPandQ: boolNotPandQ_Behavior,
            .boolNotQ: boolNotQ_Behavior,
            .boolOr: boolOr_Behavior,
            .boolP: boolP_Behavior,
            .boolPandNotQ: boolPandNotQ_Behavior,
            .boolQ: boolQ_Behavior,
            .boolXnor: boolXnor_Behavior,
            .boolXor: boolXor_Behavior,
        ]

}
