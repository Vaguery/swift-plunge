//
//  Bool Behaviors.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/31/26.
//

import DequeModule


extension Interpreter {
    static let boolBehaviors:[PushInstruction : Behavior] =
    
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
                                            isContingent: Behavior.netContingency(of: x)))
                    ]
                }),
        
        .boolAnd :
            Behavior(
                .boolAnd,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    let (arg1, arg2) = (x.value, y.value)
                    return [Router(.bool,
                                   BoolItem(arg1 && arg2,
                                            call: [y, x, InstructionItem(.boolAnd)],
                                            isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolNand :
            Behavior(
                .boolNand,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    let (arg1, arg2) = (x.value, y.value)
                    return [Router(.bool,
                                   BoolItem( !(arg1 && arg2),
                                            call: [y, x, InstructionItem(.boolNand)],
                                            isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolOr :
            Behavior(
                .boolOr,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    let (arg1, arg2) = (x.value, y.value)
                    return [Router(.bool,
                                   BoolItem(arg1 || arg2,
                                            call: [y, x, InstructionItem(.boolOr)],
                                            isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolNor :
            Behavior(
                .boolNor,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    let (arg1, arg2) = (x.value, y.value)
                    return [Router(.bool,
                                   BoolItem(!(arg1 || arg2),
                                            call: [y, x, InstructionItem(.boolNor)],
                                            isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolXor :
            Behavior(
                .boolXor,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    let (arg1, arg2) = (x.value, y.value)
                    return [Router(.bool,
                                   BoolItem(arg1 != arg2,
                                            call: [y, x, InstructionItem(.boolXor)],
                                            isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolXnor :
            Behavior(
                .boolXnor,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    let (arg1, arg2) = (x.value, y.value)
                    return [Router(.bool,
                                   BoolItem( arg1 == arg2,
                                            call: [y, x, InstructionItem(.boolXnor)],
                                            isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolNotPandQ :
            Behavior(
                .boolNotPandQ,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    return [Router(
                        .bool,
                        BoolItem(!y.value && x.value,
                                 call: [y, x, InstructionItem(.boolNotPandQ)],
                                 isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolPandNotQ :
            Behavior(
                .boolPandNotQ,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    return [Router(
                        .bool,
                        BoolItem(y.value && !x.value,
                                 call: [y, x, InstructionItem(.boolPandNotQ)],
                                 isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolNotP :
            Behavior(
                .boolNotP,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    return [Router(
                        .bool,
                        BoolItem(!y.value,
                                 call: [y, x, InstructionItem(.boolNotP)],
                                 isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolNotQ :
            Behavior(
                .boolNotQ,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    return [Router(
                        .bool,
                        BoolItem(!x.value,
                                 call: [y, x, InstructionItem(.boolNotQ)],
                                 isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolIfQThenP :
            Behavior(
                .boolIfQThenP,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    return [Router(
                        .bool,
                        BoolItem(!x.value || y.value,
                                 call: [y, x, InstructionItem(.boolIfQThenP)],
                                 isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolIfPThenQ :
            Behavior(
                .boolIfPThenQ,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    return [Router(
                        .bool,
                        BoolItem(x.value || !y.value,
                                 call: [y, x, InstructionItem(.boolIfPThenQ)],
                                 isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolP :
            Behavior(
                .boolP,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    return [Router(
                        .bool,
                        BoolItem(y.value,
                                 call: [y, x, InstructionItem(.boolP)],
                                 isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        .boolQ :
            Behavior(
                .boolQ,
                takes: [.bool,.bool],
                fxn: {a in
                    let (x,y) = (a[0] as! BoolItem, a[1] as! BoolItem)
                    return [Router(
                        .bool,
                        BoolItem(x.value,
                                 call: [y, x, InstructionItem(.boolQ)],
                                 isContingent: Behavior.netContingency(of: x, y)))
                    ]
                }),
        
        
        .boolFromDouble :
            Behavior(
                .boolFromDouble,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [Router(
                        .bool,
                        BoolItem(x.value != 0.0,
                                 call: [x, InstructionItem(.boolFromDouble)],
                                 isContingent: Behavior.netContingency(of: x)))
                    ]
                }),
        .boolFromInt :
            Behavior(
                .boolFromInt,
                takes: [.int],
                fxn: {a in
                    let (x) = (a[0] as! IntItem)
                    return [Router(
                        .bool,
                        BoolItem(x.value != 0,
                                 call: [x, InstructionItem(.boolFromInt)],
                                 isContingent: Behavior.netContingency(of: x)))
                    ]
                }),

    ]

}
