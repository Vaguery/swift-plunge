//
//  IntInstructions.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//


import DequeModule


extension Interpreter {
            
    static let intInstructions:[PushInstruction : Instruction] =
        [
            .intAdd :
                Instruction(
                    .intAdd,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(y.value + x.value,
                                        call:[y, x, InstructionItem(.intAdd)],
                                        isContingent: Instruction.netContingency(of: x, y)
                                       )
                            )
                        ]
                    }),
            
                .intSubtract :
                Instruction(
                    .intSubtract,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(y.value - x.value,
                                        call:[y, x, InstructionItem(.intSubtract)],
                                        isContingent: Instruction.netContingency(of: x, y)
                                       )
                            )
                        ]
                    }),
            
                .intMultiply :
                Instruction(
                    .intMultiply,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(y.value * x.value,
                                        call:[y, x, InstructionItem(.intMultiply)],
                                        isContingent: Instruction.netContingency(of: x, y)
                                       )
                            )
                        ]
                    }),
            
                .intMax :
                Instruction(
                    .intMax,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(max(y.value, x.value),
                                        call:[y, x, InstructionItem(.intMax)],
                                        isContingent: Instruction.netContingency(of: x, y)
                                       )
                            )
                        ]
                    }),
            
                .intMin :
                Instruction(
                    .intMin,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(min(y.value, x.value),
                                        call:[y, x, InstructionItem(.intMin)],
                                        isContingent: Instruction.netContingency(of: x, y)
                                       )
                            )
                        ]
                    }),
            
                .intQuot :
                Instruction(
                    .intQuot,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(
                                    x.value==0 ? 1 : (y.value / x.value),
                                    call: [y, x, InstructionItem(.intQuot)],
                                    isContingent: Instruction.netContingency(of: x, y)
                                )
                            )
                        ]
                    }),
            
                .intMod :
                Instruction(
                    .intMod,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(x.value==0 ? 1 : (y.value % x.value),
                                        call:[y, x, InstructionItem(.intMod)],
                                        isContingent: Instruction.netContingency(of: x, y)
                                       )
                            )
                        ]
                    }
                ),
            
                .intGT :
                Instruction(
                    .intGT,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .bool,
                                BoolItem(y.value > x.value,
                                         call:[y, x, InstructionItem(.intGT)],
                                         isContingent: Instruction.netContingency(of: x, y)
                                        )
                            )
                        ]
                    }
                ),
            
                .intGTE :
                Instruction(
                    .intGTE,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .bool,
                                BoolItem(y.value >= x.value,
                                         call:[y, x, InstructionItem(.intGTE)],
                                         isContingent: Instruction.netContingency(of: x, y)
                                        )
                            )
                        ]
                    }
                ),
            
                .intLTE :
                Instruction(
                    .intLTE,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .bool,
                                BoolItem(y.value <= x.value,
                                         call:[y, x, InstructionItem(.intLTE)],
                                         isContingent: Instruction.netContingency(of: x, y)
                                        )
                            )
                        ]
                    }
                ),
            
                .intLT :
                Instruction(
                    .intLT,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .bool,
                                BoolItem(y.value < x.value,
                                         call:[y, x, InstructionItem(.intLT)],
                                         isContingent: Instruction.netContingency(of: x, y)
                                        )
                            )
                        ]
                    }
                ),
            
                .intEq :
                Instruction(
                    .intEq,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .bool,
                                BoolItem(y.value == x.value,
                                         call:[y, x, InstructionItem(.intEq)],
                                         isContingent: Instruction.netContingency(of: x, y)
                                        )
                            )
                        ]
                    }
                ),
            
                .intInc :
                Instruction(
                    .intInc,
                    takes: [.int],
                    fxn: {a in
                        let (x) = (a[0] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(x.value + 1,
                                        call:[x, InstructionItem(.intInc)],
                                        isContingent: Instruction.netContingency(of: x)
                                       )
                            )
                        ]
                    }
                ),
            
                .intDec :
                Instruction(
                    .intDec,
                    takes: [.int],
                    fxn: {a in
                        let (x) = (a[0] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(x.value - 1,
                                        call:[x, InstructionItem(.intDec)],
                                        isContingent: Instruction.netContingency(of: x)
                                       )
                            )
                        ]
                    }
                ),

//            .intFromBool :
//                Instruction(
//                    .intFromBool,
//                    takes: [.bool],
//                    fxn: {a in
//                        let (x) = (a[0].bVal()!)
//                        return [Router(.int, PushItem.makeInt(x ? 1 : 0, h:"(\(a[0].hist()) .intFromBool)") )]
//                    }),
            
//            .intFromChar :
//                Instruction(
//                    .intFromChar,
//                    takes: [.char],
//                    fxn: {a in
//                        let (c) = (a[0].cVal()!)
//                        if let v = c.asciiValue {
//                            return [Router(.int, PushItem.makeInt(Int(v), h:"(\(a[0].hist()) .intFromChar)") )]
//                        } else { return [] }
//                    }),
            
//            .intFromString :
//                Instruction(
//                    .intFromString,
//                    takes: [.string],
//                    fxn: {a in
//                        let (x) = (a[0].sVal()!)
//                        if let c = Int(x) {
//                            return [Router(.int, PushItem.makeInt(c, h:"(\(a[0].hist()) .intFromString)") )]
//                        } else {
//                            return []
//                        }
//                    }),
            
//            .intFromFloat :
//                Instruction(
//                    .intFromFloat,
//                    takes: [.float],
//                    fxn: {a in
//                        let (x) = (a[0].fVal()!)
//                        return [Router(.int, PushItem.makeInt(Int(x), h:"(\(a[0].hist()) .intFromFloat)") )]
//                    }),
            
        ]

}
