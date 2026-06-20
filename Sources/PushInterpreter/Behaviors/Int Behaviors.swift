//
//  Int Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//


import DequeModule


extension Interpreter {
            
    static let intBehaviors:[PushInstruction : Behavior] =
        [
            .intAdd :
                Behavior(
                    .intAdd,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(y.value + x.value,
                                        call:[y, x, InstructionItem(.intAdd)],
                                        isContingent: Behavior.netContingency(of: x, y)
                                       )
                            )
                        ]
                    }),
            
                .intSubtract :
                Behavior(
                    .intSubtract,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(y.value - x.value,
                                        call:[y, x, InstructionItem(.intSubtract)],
                                        isContingent: Behavior.netContingency(of: x, y)
                                       )
                            )
                        ]
                    }),
            
                .intMultiply :
                Behavior(
                    .intMultiply,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        
                        let (result, hasOverflowed) = y.value.multipliedReportingOverflow(by: x.value)

                        if hasOverflowed {
                            return [
                                Router(
                                    .error,
                                    ErrorItem("Overflow in .intMultiply: \(y.value) * \(x.value)",
                                            call:[y, x, InstructionItem(.intMultiply)],
                                            isContingent: Behavior.netContingency(of: x, y)
                                           )
                                )
                            ]
                        } else {
                            return [
                                Router(
                                    .int,
                                    IntItem(y.value * x.value,
                                            call:[y, x, InstructionItem(.intMultiply)],
                                            isContingent: Behavior.netContingency(of: x, y)
                                           )
                                )
                            ]
                        }
                    }
                ),
            
                .intMax :
                Behavior(
                    .intMax,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(max(y.value, x.value),
                                        call:[y, x, InstructionItem(.intMax)],
                                        isContingent: Behavior.netContingency(of: x, y)
                                       )
                            )
                        ]
                    }),
            
                .intMin :
                Behavior(
                    .intMin,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(min(y.value, x.value),
                                        call:[y, x, InstructionItem(.intMin)],
                                        isContingent: Behavior.netContingency(of: x, y)
                                       )
                            )
                        ]
                    }),
            
                .intQuot :
                Behavior(
                    .intQuot,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(
                                    x.value == 0 ? 1 : (y.value / x.value),
                                    call: [y, x, InstructionItem(.intQuot)],
                                    isContingent: Behavior.netContingency(of: x, y)
                                )
                            )
                        ]
                    }),
            
                .intMod :
                Behavior(
                    .intMod,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(x.value==0 ? 1 : (y.value % x.value),
                                        call:[y, x, InstructionItem(.intMod)],
                                        isContingent: Behavior.netContingency(of: x, y)
                                       )
                            )
                        ]
                    }
                ),
            
                .intGT :
                Behavior(
                    .intGT,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .bool,
                                BoolItem(y.value > x.value,
                                         call:[y, x, InstructionItem(.intGT)],
                                         isContingent: Behavior.netContingency(of: x, y)
                                        )
                            )
                        ]
                    }
                ),
            
                .intGTE :
                Behavior(
                    .intGTE,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .bool,
                                BoolItem(y.value >= x.value,
                                         call:[y, x, InstructionItem(.intGTE)],
                                         isContingent: Behavior.netContingency(of: x, y)
                                        )
                            )
                        ]
                    }
                ),
            
                .intLTE :
                Behavior(
                    .intLTE,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .bool,
                                BoolItem(y.value <= x.value,
                                         call:[y, x, InstructionItem(.intLTE)],
                                         isContingent: Behavior.netContingency(of: x, y)
                                        )
                            )
                        ]
                    }
                ),
            
                .intLT :
                Behavior(
                    .intLT,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .bool,
                                BoolItem(y.value < x.value,
                                         call:[y, x, InstructionItem(.intLT)],
                                         isContingent: Behavior.netContingency(of: x, y)
                                        )
                            )
                        ]
                    }
                ),
            
                .intEq :
                Behavior(
                    .intEq,
                    takes: [.int,.int],
                    fxn: {a in
                        let (x,y) = (a[0] as! IntItem, a[1] as! IntItem)
                        return [
                            Router(
                                .bool,
                                BoolItem(y.value == x.value,
                                         call:[y, x, InstructionItem(.intEq)],
                                         isContingent: Behavior.netContingency(of: x, y)
                                        )
                            )
                        ]
                    }
                ),
            
                .intInc :
                Behavior(
                    .intInc,
                    takes: [.int],
                    fxn: {a in
                        let (x) = (a[0] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(x.value + 1,
                                        call:[x, InstructionItem(.intInc)],
                                        isContingent: Behavior.netContingency(of: x)
                                       )
                            )
                        ]
                    }
                ),
            
                .intDec :
                Behavior(
                    .intDec,
                    takes: [.int],
                    fxn: {a in
                        let (x) = (a[0] as! IntItem)
                        return [
                            Router(
                                .int,
                                IntItem(x.value - 1,
                                        call:[x, InstructionItem(.intDec)],
                                        isContingent: Behavior.netContingency(of: x)
                                       )
                            )
                        ]
                    }
                ),
            
                .intFromBool :
                Behavior(
                    .intFromBool,
                    takes: [.bool],
                    fxn: {a in
                        let (x) = (a[0] as! BoolItem)
                        return [
                            Router(
                                .int,
                                IntItem(x.value ? 1 : 0,
                                        call:[x, InstructionItem(.intFromBool)],
                                        isContingent: Behavior.netContingency(of: x)
                                       )
                            )
                        ]
                    }
                ),
            
            .intFromChar :
                Behavior(
                    .intFromChar,
                    takes: [.char],
                    fxn: {a in
                        let (c) = (a[0] as! CharItem)
                        if let v = c.value.asciiValue {
                            return [
                                Router(
                                    .int,
                                    IntItem(Int(v),
                                            call: [c, InstructionItem(.intFromChar)],
                                            isContingent: Behavior.netContingency(of: c)
                                            )
                                    )
                                ]
                        } else {
                            return []
                        }
                    }
                ),
            
            .intFromString :
                Behavior(
                    .intFromString,
                    takes: [.string],
                    fxn: {a in
                        let (s) = (a[0] as! StringItem)
                        if let v = Int(s.value) {
                            return [
                                Router(.int,
                                       IntItem(v,
                                               call:[s, InstructionItem(.intFromString)],
                                               isContingent: Behavior.netContingency(of: s)
                                               )
                                       )
                                ]
                        } else {
                            return []
                        }
                    }),
            
            .intFromDouble :
                Behavior(
                    .intFromDouble,
                    takes: [.double],
                    fxn: {a in
                        let (x) = (a[0] as! DoubleItem)
                        return [
                            Router(.int,
                                   IntItem(Int(x.value),
                                           call:[x, InstructionItem(.intFromDouble)],
                                           isContingent: Behavior.netContingency(of: x)
                                          )
                                   )
                            ]
                    }
                ),
        ]

}
