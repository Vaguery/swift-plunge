//
//  Bool Instructions.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/31/26.
//

import DequeModule


extension Interpreter {
    static let boolInstructions:[PushInstruction : Behavior] =
    
    [
        .boolNot :
            Behavior(
                .boolNot,
                takes: [.bool],
                fxn: {a in
                    let (x) = (a[0] as! BoolItem)
                    return [Router(.bool,
                                   BoolItem(!x.value,
                                            call: [x, InstructionItem(.boolNot)],
                                            isContingent: Instruction.netContingency(of: x)))
                    ]
                }),
        .boolAnd :
            Instruction(
                .boolAnd,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    let (arg1, arg2) = (x.value, y.value)
                    return [Router(.bool,
                                   BoolItem(arg1 && arg2,
                                            call: [y, x, InstructionItem(.boolAnd)],
                                            isContingent: Instruction.netContingency(of: x, y)))
                    ]
                }),
        .boolOr :
            Instruction(
                .boolOr,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    let (arg1, arg2) = (x.value, y.value)
                    return [Router(.bool,
                                   BoolItem(arg1 || arg2,
                                            call: [y, x, InstructionItem(.boolOr)],
                                            isContingent: Instruction.netContingency(of: x, y)))
                    ]
                }),
        .boolXor :
            Instruction(
                .boolXor,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    let (arg1, arg2) = (x.value, y.value)
                    return [Router(.bool,
                                   BoolItem(arg1 != arg2,
                                            call: [y, x, InstructionItem(.boolXor)],
                                            isContingent: Instruction.netContingency(of: x, y)))
                    ]
                }),
        .boolInvertFirstThenAnd :
            Instruction(
                .boolInvertFirstThenAnd,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    return [Router(
                        .bool,
                        BoolItem(!y.value && x.value,
                                 call: [y, x, InstructionItem(.boolInvertFirstThenAnd)],
                                 isContingent: Instruction.netContingency(of: x, y)))
                    ]
                }),
        .boolInvertSecondThenAnd :
            Instruction(
                .boolInvertSecondThenAnd,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    return [Router(
                        .bool,
                        BoolItem(y.value && !x.value,
                                 call: [y, x, InstructionItem(.boolInvertSecondThenAnd)],
                                 isContingent: Instruction.netContingency(of: x, y)))
                    ]
                }),
        .boolFromDouble :
            Instruction(
                .boolFromDouble,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [Router(
                        .bool,
                        BoolItem(x.value != 0.0,
                                 call: [x, InstructionItem(.boolFromDouble)],
                                 isContingent: Instruction.netContingency(of: x)))
                    ]
                }),
        .boolFromInt :
            Instruction(
                .boolFromInt,
                takes: [.int],
                fxn: {a in
                    let (x) = (a[0] as! IntItem)
                    return [Router(
                        .bool,
                        BoolItem(x.value != 0,
                                 call: [x, InstructionItem(.boolFromInt)],
                                 isContingent: Instruction.netContingency(of: x)))
                    ]
                }),

    ]

}
