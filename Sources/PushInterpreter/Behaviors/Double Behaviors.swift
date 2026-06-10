//
//  Double Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule
import Foundation


extension Interpreter {
            
    static let doubleBehaviors:[PushInstruction : Behavior] =
        
        [
            .doubleAdd:
                Behavior(
                    .doubleAdd,
                    takes: [.double, .double],
                    fxn: { a in
                        let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                        return [
                            Router(
                                .double,
                                DoubleItem(
                                    y.value + x.value,
                                    call: [y, x, InstructionItem(.doubleAdd)],
                                    isContingent: Behavior.netContingency(of: x, y )
                                )
                            )
                        ]
                    }
                ),

            .doubleQuot:
                Behavior(
                    .doubleQuot,
                    takes: [.double, .double],
                    fxn: { a in
                        let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                        var integralQuotient: Double

                        if x.value.isZero {
                            integralQuotient = 1.0
                        } else {
                            integralQuotient =
                                (y.value
                                    - y.value.truncatingRemainder(
                                        dividingBy: x.value
                                    )) / x.value
                        }
                        return [
                            Router(
                                .double,
                                DoubleItem(
                                    integralQuotient,
                                    call: [y, x, InstructionItem(.doubleQuot)],
                                    isContingent: Behavior.netContingency( of: x,  y )
                                )
                            )
                        ]
                    }
                ),

            .doubleMod:
                Behavior(
                    .doubleMod,
                    takes: [.double, .double],
                    fxn: { a in
                        let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                        var remainder: Double

                        if x.value.isZero {
                            remainder = 1.0
                        } else {
                            remainder =
                                (y.value.truncatingRemainder(
                                    dividingBy: x.value
                                ))
                        }
                        return [
                            Router(
                                .double,
                                DoubleItem(
                                    remainder,
                                    call: [y, x, InstructionItem(.doubleMod)],
                                    isContingent: Behavior.netContingency( of: x, y )
                                )
                            )
                        ]
                    }
                ),

            .doubleMin:
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
                                    call: [y, x, InstructionItem(.doubleMin)],
                                    isContingent: Behavior.netContingency( of: x, y )
                                )
                            )
                        ]
                    }
                ),

            .doubleMax:
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
                                    call: [y, x, InstructionItem(.doubleMax)],
                                    isContingent: Behavior.netContingency(of: x, y)
                                )
                            )
                        ]
                    }
                ),

            .doubleSubtract:
                Behavior(
                    .doubleSubtract,
                    takes: [.double, .double],
                    fxn: { a in
                        let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                        return [
                            Router(
                                .double,
                                DoubleItem(
                                    y.value - x.value,
                                    call: [
                                        y, x, InstructionItem(.doubleSubtract),
                                    ],
                                    isContingent: Behavior.netContingency(
                                        of: x, y
                                    )
                                )
                            )
                        ]
                    }
                ),

            .doubleMultiply:
                Behavior(
                    .doubleMultiply,
                    takes: [.double, .double],
                    fxn: { a in
                        let (x, y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                        return [
                            Router(
                                .double,
                                DoubleItem(
                                    y.value * x.value,
                                    call: [
                                        y, x, InstructionItem(.doubleMultiply),
                                    ],
                                    isContingent: Behavior.netContingency(
                                        of: x,y
                                    )
                                )
                            )
                        ]
                    }
                ),

            .doubleFromInt:
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
                                    call: [x, InstructionItem(.doubleFromInt)],
                                    isContingent: Behavior.netContingency( of: x )
                                )
                            )
                        ]
                    }
                ),
            
        .doubleGT :
            Behavior(
            .doubleGT,
            takes: [.double,.double],
            fxn: {a in
                let (x,y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(y > x,
                                 call: [y, x, InstructionItem(.doubleGT)],
                                 isContingent: Behavior.netContingency(of: x, y)
                                )
                        )
                    ]
                }
            ),

        .doubleGTE :
            Behavior(
            .doubleGTE,
            takes: [.double,.double],
            fxn: {a in
                let (x,y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(y >= x,
                                 call: [y, x, InstructionItem(.doubleGTE)],
                                 isContingent: Behavior.netContingency(of: x, y)
                                )
                        )
                    ]
                }
            ),
        
        .doubleLTE :
            Behavior(
            .doubleLTE,
            takes: [.double,.double],
            fxn: {a in
                let (x,y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(y <= x,
                                 call: [y, x, InstructionItem(.doubleLTE)],
                                 isContingent: Behavior.netContingency(of: x, y)
                                )
                        )
                    ]
                }
            ),

        .doubleLT :
            Behavior(
            .doubleLT,
            takes: [.double,.double],
            fxn: {a in
                let (x,y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(y < x,
                                 call: [y, x, InstructionItem(.doubleLT)],
                                 isContingent: Behavior.netContingency(of: x, y)
                                )
                        )
                    ]
                }
            ),

        .doubleCos :
            Behavior(
                .doubleCos,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(cos(x.value),
                                       call:[x, InstructionItem(.doubleCos)],
                                       isContingent: Behavior.netContingency(of: x)
                                       )
                            )
                        ]
                    }
            ),

        .doubleSin :
            Behavior(
                .doubleSin,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(sin(x.value),
                                       call:[x, InstructionItem(.doubleSin)],
                                       isContingent: Behavior.netContingency(of: x)
                                       )
                            )
                        ]
                    }
            ),

        .doubleTan :
            Behavior(
                .doubleTan,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(tan(x.value),
                                       call:[x, InstructionItem(.doubleTan)],
                                       isContingent: Behavior.netContingency(of: x)
                                       )
                            )
                        ]
                    }
            ),

        .doubleInc :
            Behavior(
                .doubleInc,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(x.value + 1.0,
                                       call:[x, InstructionItem(.doubleInc)],
                                       isContingent: Behavior.netContingency(of: x)
                                      )
                        )
                    ]
                }
            ),
                
        .doubleDec :
            Behavior(
                .doubleDec,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(x.value - 1.0,
                                       call:[x, InstructionItem(.doubleDec)],
                                       isContingent: Behavior.netContingency(of: x)
                                      )
                        )
                    ]
                }
            ),

        .doubleFromBool :
            Behavior(
                .doubleFromBool,
                takes: [.bool],
                fxn: {a in
                    let (x) = (a[0] as! BoolItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(x.value ? 1.0 : 0.0,
                                       call:[x, InstructionItem(.doubleFromBool)],
                                       isContingent: Behavior.netContingency(of: x)
                                      )
                        )
                    ]
                    
                }
            ),

        .doubleFromChar :
            Behavior(
                .doubleFromChar,
                takes: [.char],
                fxn: {a in
                    let (x) = (a[0] as! CharItem)
                    let num = (x.value.isASCII ? Double(x.value.asciiValue!) : 0.0)
                    return [
                        Router(
                            .double,
                            DoubleItem(num,
                                       call:[x, InstructionItem(.doubleFromChar)],
                                       isContingent: Behavior.netContingency(of: x)
                                      )
                        )
                    ]
                }
            ),
        
        .doubleFromString :
            Behavior(
                .doubleFromString,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    let num = Double(x.value) ?? 0.0
                    return [
                        Router(
                            .double,
                            DoubleItem(num,
                                       call:[x, InstructionItem(.doubleFromString)],
                                       isContingent: Behavior.netContingency(of: x)
                                      )
                        )
                    ]
                }
            ),
            
         /// insert new ones here?
        ]
        
}

