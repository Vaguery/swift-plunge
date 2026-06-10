//
//  Double Instructions.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule
import Foundation


extension Interpreter {
            
    static let doubleInstructions:[PushInstruction : Instruction] =
        
        [
            .doubleAdd:
                Instruction(
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
                                    isContingent: Instruction.netContingency(of: x, y )
                                )
                            )
                        ]
                    }
                ),

            .doubleQuot:
                Instruction(
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
                                    isContingent: Instruction.netContingency( of: x,  y )
                                )
                            )
                        ]
                    }
                ),

            .doubleMod:
                Instruction(
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
                                    isContingent: Instruction.netContingency( of: x, y )
                                )
                            )
                        ]
                    }
                ),

            .doubleMin:
                Instruction(
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
                                    isContingent: Instruction.netContingency( of: x, y )
                                )
                            )
                        ]
                    }
                ),

            .doubleMax:
                Instruction(
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
                                    isContingent: Instruction.netContingency(of: x, y)
                                )
                            )
                        ]
                    }
                ),

            .doubleSubtract:
                Instruction(
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
                                    isContingent: Instruction.netContingency(
                                        of: x, y
                                    )
                                )
                            )
                        ]
                    }
                ),

            .doubleMultiply:
                Instruction(
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
                                    isContingent: Instruction.netContingency(
                                        of: x,y
                                    )
                                )
                            )
                        ]
                    }
                ),

            .doubleFromInt:
                Instruction(
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
                                    isContingent: Instruction.netContingency( of: x )
                                )
                            )
                        ]
                    }
                ),
            
        .doubleGT :
            Instruction(
            .doubleGT,
            takes: [.double,.double],
            fxn: {a in
                let (x,y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(y > x,
                                 call: [y, x, InstructionItem(.doubleGT)],
                                 isContingent: Instruction.netContingency(of: x, y)
                                )
                        )
                    ]
                }
            ),

        .doubleGTE :
            Instruction(
            .doubleGTE,
            takes: [.double,.double],
            fxn: {a in
                let (x,y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(y >= x,
                                 call: [y, x, InstructionItem(.doubleGTE)],
                                 isContingent: Instruction.netContingency(of: x, y)
                                )
                        )
                    ]
                }
            ),
        
        .doubleLTE :
            Instruction(
            .doubleLTE,
            takes: [.double,.double],
            fxn: {a in
                let (x,y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(y <= x,
                                 call: [y, x, InstructionItem(.doubleLTE)],
                                 isContingent: Instruction.netContingency(of: x, y)
                                )
                        )
                    ]
                }
            ),

        .doubleLT :
            Instruction(
            .doubleLT,
            takes: [.double,.double],
            fxn: {a in
                let (x,y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                return [
                    Router(
                        .bool,
                        BoolItem(y < x,
                                 call: [y, x, InstructionItem(.doubleLT)],
                                 isContingent: Instruction.netContingency(of: x, y)
                                )
                        )
                    ]
                }
            ),

        .doubleCos :
            Instruction(
                .doubleCos,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(cos(x.value),
                                       call:[x, InstructionItem(.doubleCos)],
                                       isContingent: Instruction.netContingency(of: x)
                                       )
                            )
                        ]
                    }
            ),

        .doubleSin :
            Instruction(
                .doubleSin,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(sin(x.value),
                                       call:[x, InstructionItem(.doubleSin)],
                                       isContingent: Instruction.netContingency(of: x)
                                       )
                            )
                        ]
                    }
            ),

        .doubleTan :
            Instruction(
                .doubleTan,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(tan(x.value),
                                       call:[x, InstructionItem(.doubleTan)],
                                       isContingent: Instruction.netContingency(of: x)
                                       )
                            )
                        ]
                    }
            ),

        .doubleInc :
            Instruction(
                .doubleInc,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(x.value + 1.0,
                                       call:[x, InstructionItem(.doubleInc)],
                                       isContingent: Instruction.netContingency(of: x)
                                      )
                        )
                    ]
                }
            ),
                
        .doubleDec :
            Instruction(
                .doubleDec,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(x.value - 1.0,
                                       call:[x, InstructionItem(.doubleDec)],
                                       isContingent: Instruction.netContingency(of: x)
                                      )
                        )
                    ]
                }
            ),

        .doubleFromBool :
            Instruction(
                .doubleFromBool,
                takes: [.bool],
                fxn: {a in
                    let (x) = (a[0] as! BoolItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(x.value ? 1.0 : 0.0,
                                       call:[x, InstructionItem(.doubleFromBool)],
                                       isContingent: Instruction.netContingency(of: x)
                                      )
                        )
                    ]
                    
                }
            ),

        .doubleFromChar :
            Instruction(
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
                                       isContingent: Instruction.netContingency(of: x)
                                      )
                        )
                    ]
                }
            ),
        
        .doubleFromString :
            Instruction(
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
                                       isContingent: Instruction.netContingency(of: x)
                                      )
                        )
                    ]
                }
            ),
            
         /// insert new ones here?
        ]
        
}

