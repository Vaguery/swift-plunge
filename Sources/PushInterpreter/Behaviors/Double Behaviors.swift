//
//  Double Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule
import Foundation

nonisolated extension Interpreter {

    static let doubleAdd_Behavior =
        Behavior(
            .doubleAdd,
            takes: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)

                let result = y.value + x.value
                if result.isInfinite || result.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleAdd: \(y.value) + \(x.value)",
                                call: [y, x, InstructionItem(.doubleAdd)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                result,
                                call: [y, x, InstructionItem(.doubleAdd)])
                        )
                    ]

                }
            }
        )

    static let doubleQuot_Behavior =
        Behavior(
            .doubleQuot,
            takes: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)

                var result =
                    (y.value - y.value.truncatingRemainder(dividingBy: x.value))
                    / x.value
                if result.isInfinite || result.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleQuot: \(y.value) // \(x.value)",
                                call: [y, x, InstructionItem(.doubleQuot)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                result,
                                call: [y, x, InstructionItem(.doubleQuot)])
                        )
                    ]

                }
            }
        )

    static let doubleDivide_Behavior =
        Behavior(
            .doubleDivide,
            takes: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)

                var result = (y.value / x.value)
                if result.isInfinite || result.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleDivide: \(y.value) / \(x.value)",
                                call: [y, x, InstructionItem(.doubleDivide)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                result,
                                call: [y, x, InstructionItem(.doubleDivide)])
                        )
                    ]

                }
            }
        )

    static let doubleMod_Behavior =
        Behavior(
            .doubleMod,
            takes: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)

                var result = (y.value.truncatingRemainder(dividingBy: x.value))
                if result.isInfinite || result.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleMod: \(y.value) % \(x.value)",
                                call: [y, x, InstructionItem(.doubleMod)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                result,
                                call: [y, x, InstructionItem(.doubleMod)])
                        )
                    ]

                }
            }
        )

    static let doubleMin_Behavior =
        Behavior(
            .doubleMin,
            takes: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .double,
                        DoubleItem(
                            min(x.value, y.value),
                            call: [y, x, InstructionItem(.doubleMin)])
                    )
                ]
            }
        )

    static let doubleMax_Behavior =
        Behavior(
            .doubleMax,
            takes: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .double,
                        DoubleItem(
                            max(x.value, y.value),
                            call: [y, x, InstructionItem(.doubleMax)])
                    )
                ]
            }
        )

    static let doubleSubtract_Behavior =
        Behavior(
            .doubleSubtract,
            takes: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)

                let result = y.value - x.value
                if result.isInfinite || result.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleSubtract: \(y.value) - \(x.value)",
                                call: [y, x, InstructionItem(.doubleSubtract)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                result,
                                call: [y, x, InstructionItem(.doubleSubtract)])
                        )
                    ]

                }
            }
        )

    static let doubleMultiply_Behavior =
        Behavior(
            .doubleMultiply,
            takes: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)

                let result = y.value * x.value
                if result.isInfinite || result.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleMultiply: \(y.value) * \(x.value)",
                                call: [y, x, InstructionItem(.doubleMultiply)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                result,
                                call: [y, x, InstructionItem(.doubleMultiply)])
                        )
                    ]

                }
            }
        )

    static let doubleFromInt_Behavior =
        Behavior(
            .doubleFromInt,
            takes: [.int],
            fxn: { a in
                let (x) = (a[0] as! IntItem)
                return [
                    Router(
                        .double,
                        DoubleItem(
                            Double(x.value),
                            call: [x, InstructionItem(.doubleFromInt)])
                    )
                ]
            }
        )

    static let doubleGT_Behavior =
        Behavior(
            .doubleGT,
            reads: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y > x,
                            call: Behavior.reading([.double: 2], producing: .bool, from: [y, x, InstructionItem(.doubleGT)]))
                    )
                ]
            }
        )

    static let doubleGTE_Behavior =
        Behavior(
            .doubleGTE,
            reads: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y >= x,
                            call: Behavior.reading([.double: 2], producing: .bool, from: [y, x, InstructionItem(.doubleGTE)]))
                    )
                ]
            }
        )

    static let doubleLTE_Behavior =
        Behavior(
            .doubleLTE,
            reads: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y <= x,
                            call: Behavior.reading([.double: 2], producing: .bool, from: [y, x, InstructionItem(.doubleLTE)]))
                    )
                ]
            }
        )

    static let doubleLT_Behavior =
        Behavior(
            .doubleLT,
            reads: [.double, .double],
            fxn: { a in
                let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y < x,
                            call: Behavior.reading([.double: 2], producing: .bool, from: [y, x, InstructionItem(.doubleLT)]))
                    )
                ]
            }
        )

    static let doubleCos_Behavior =
        Behavior(
            .doubleCos,
            takes: [.double],
            fxn: { a in
                let (x) = (a[0] as! DoubleItem)
                let result = cos(x.value)
                if result.isInfinite || result.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleCos: cos(\(x.value))",
                                call: [x, InstructionItem(.doubleCos)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                result,
                                call: [x, InstructionItem(.doubleCos)])
                        )
                    ]
                }
            }
        )

    static let doubleSin_Behavior =
        Behavior(
            .doubleSin,
            takes: [.double],
            fxn: { a in
                let (x) = (a[0] as! DoubleItem)
                let result = sin(x.value)
                if result.isInfinite || result.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleSin: sin(\(x.value))",
                                call: [x, InstructionItem(.doubleSin)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                result,
                                call: [x, InstructionItem(.doubleSin)])
                        )
                    ]
                }
            }
        )

    static let doubleTan_Behavior =
        Behavior(
            .doubleTan,
            takes: [.double],
            fxn: { a in
                let (x) = (a[0] as! DoubleItem)
                let result = tan(x.value)
                if result.isInfinite || result.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleTan: tan(\(x.value))",
                                call: [x, InstructionItem(.doubleTan)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                result,
                                call: [x, InstructionItem(.doubleTan)])
                        )
                    ]
                }
            }
        )

    static let doubleInc_Behavior =
        Behavior(
            .doubleInc,
            takes: [.double],
            fxn: { a in
                let (x) = (a[0] as! DoubleItem)
                let result = x.value + 1.0

                if result.isInfinite || result.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleInc: \(x.value) + 1.0",
                                call: [x, InstructionItem(.doubleInc)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                result,
                                call: [x, InstructionItem(.doubleInc)])
                        )
                    ]
                }
            }
        )

    static let doubleDec_Behavior =
        Behavior(
            .doubleDec,
            takes: [.double],
            fxn: { a in
                let (x) = (a[0] as! DoubleItem)
                let result = x.value - 1.0

                if result.isInfinite || result.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleDec: \(x.value) - 1.0",
                                call: [x, InstructionItem(.doubleDec)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                result,
                                call: [x, InstructionItem(.doubleDec)])
                        )
                    ]
                }
            }
        )

    static let doubleFromBool_Behavior =
        Behavior(
            .doubleFromBool,
            takes: [.bool],
            fxn: { a in
                let (x) = (a[0] as! BoolItem)
                return [
                    Router(
                        .double,
                        DoubleItem(
                            x.value ? 1.0 : 0.0,
                            call: [x, InstructionItem(.doubleFromBool)])
                    )
                ]

            }
        )

    static let doubleFromChar_Behavior =
        Behavior(
            .doubleFromChar,
            takes: [.char],
            fxn: { a in
                let (x) = (a[0] as! CharItem)
                let num = (x.value.isASCII ? Double(x.value.asciiValue!) : 0.0)
                return [
                    Router(
                        .double,
                        DoubleItem(
                            num,
                            call: [x, InstructionItem(.doubleFromChar)])
                    )
                ]
            }
        )

    static let doubleFromString_Behavior =
        Behavior(
            .doubleFromString,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                let num = Double(x.value) ?? 0.0
                // "inf"/"infinity"/"nan"/"1e400" parse to non-finite values;
                // reject them here so they cannot poison later numeric behaviors
                if num.isInfinite || num.isNaN {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Overflow in .doubleFromString: \"\(x.value)\"",
                                call: [x, InstructionItem(.doubleFromString)])
                        )
                    ]
                } else {
                    return [
                        Router(
                            .double,
                            DoubleItem(
                                num,
                                call: [x, InstructionItem(.doubleFromString)])
                        )
                    ]
                }
            }
        )

    static let doubleBehaviors:[PushInstruction : Behavior] =
        
        [
            .doubleAdd : doubleAdd_Behavior,
            .doubleCos : doubleCos_Behavior,
            .doubleDec : doubleDec_Behavior,
            .doubleDivide : doubleDivide_Behavior,
            .doubleFromBool : doubleFromBool_Behavior,
            .doubleFromChar : doubleFromChar_Behavior,
            .doubleFromInt : doubleFromInt_Behavior,
            .doubleFromString : doubleFromString_Behavior,
            .doubleInc : doubleInc_Behavior,
            .doubleMax : doubleMax_Behavior,
            .doubleMin : doubleMin_Behavior,
            .doubleMod : doubleMod_Behavior,
            .doubleMultiply : doubleMultiply_Behavior,
            .doubleQuot : doubleQuot_Behavior,
            .doubleSin : doubleSin_Behavior,
            .doubleSubtract : doubleSubtract_Behavior,
            .doubleTan : doubleTan_Behavior,
        ]
        
}

