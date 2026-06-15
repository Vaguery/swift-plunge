//
//  Exec Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule


extension Interpreter {
            
    static let execBehaviors:[PushInstruction : Behavior] =
    [
        
        
        // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L335-L343
        
        
//        .execDoWhile :
//            Instruction(
//                .execDoWhile,
//                takes: [.exec, .bool],
//                fxn: {a in
//                    let (item, decider) = (a[0], a[1] as! BoolItem)
//                    var results: [any Item] = []
//                    if !decider.value { return [] }
//                    results.append(a[0])
//                    results.append(InstructionItem(.execWhile))
//                    results.append(a[0])
//                    return [
//                        Router(
//                            .exec,
//                            CodeItem(results,
//                                    call: [InstructionItem(.execDoWhile), item, decider],
//                                    isContingent: Instruction.netContingency(of: item, decider)
//                                    )
//                        )
//                    ]
//                }),

//        
//        
//        // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L13-L32
//        
//        .execDoCount :
//            Instruction(
//                .execDoCount,
//                takes: [.exec, .int],
//                fxn: {a in
//                    let (item, counter) = (a[0], a[1].iVal()!)
//                    var results: [PushItem] = []
//                    if counter > 1 {
//                        results.append(PushItem.makeInt(0))
//                        results.append(a[1])
//                        results.append(PushItem.makeInst(.execDoRange))
//                        results.append(a[0])
//                    } else {
//                        results.append(a[1])
//                        results.append(a[0])
//                    }
//                    return [Router(.exec, PushItem.makeCode(results)) ]
//                }),
//
//        
//        // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L183-L203
//        
//        .execDoTimes :
//            Instruction(
//                .execDoTimes,
//                takes: [.exec, .int],
//                fxn: {a in
//                    let (item, counter) = (a[0], a[1].iVal()!)
//                    var results: [PushItem] = []
//                    if counter < 1 {
//                        return [Router(.exec, a[0]) ]
//                    } else {
//                        results.append(a[0])
//                        results.append(PushItem.makeInt(counter - 1))
//                        results.append(PushItem.makeInst(.execDoTimes))
//                        results.append(a[0])
//                        return [Router(.exec, PushItem.makeCode(results)) ]
//                    }
//                }),
//
//        
//        
//        // using my own code as an example from: https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L83-L112
//        
//        .execDoRange :
//            Instruction(
//                .execDoRange,
//                takes: [.exec, .int, .int],
//                fxn: {a in
//                    let (item, end, start) = (a[0], a[1].iVal()!, a[2].iVal()!)
//                    var results: [PushItem] = []
//                    if (end - start) > 1 {
//                        results.append(a[2])
//                        results.append(a[0])
//                        results.append(PushItem.makeInt(start+1))
//                        results.append(a[1])
//                        results.append(PushItem.makeInst(.execDoRange))
//                        results.append(a[0])
//                    } else if (start - end) > 1 {
//                        results.append(a[2])
//                        results.append(a[0])
//                        results.append(PushItem.makeInt(start-1))
//                        results.append(a[1])
//                        results.append(PushItem.makeInst(.execDoRange))
//                        results.append(a[0])
//                    } else {
//                        if start < end {
//                            results.append(PushItem.makeInt(end-1))
//                        } else if start > end {
//                            results.append(PushItem.makeInt(end+1))
//                        } else {
//                            results.append(a[1])
//                        }
//                        results.append(a[0])
//
//                    }
//                    return [Router(.exec, PushItem.makeCode(results)) ]
//                }),
//
//        
//        
//        .execIf :
//            Instruction(
//                .execIf,
//                takes: [.bool, .exec, .exec],
//                fxn: {a in
//                    let (x, y, z) = (a[0].bVal()!, a[1], a[2])
//                    let result = x ? y : z
//                    return [Router(.exec, result.updateHistory("( \(a[0].hist()) .execIf) \(y.hist()) \(z.hist()) )"))]
//                    // in original code, (exec_if A B) will keep A & discard B if true, else keep B & discard A
//                }),
//        
        .execK :
            Behavior(
                .execK,
                takes: [.exec, .exec],
                fxn: {a in
                    var (x, y) = (a[0], a[1])
                    x.call = [InstructionItem(.execK), x, y]
                    return [
                        Router(.exec, x)
                    ]
                }
            ),
        
        .execY :
            Behavior(
                .execY,
                takes: [.exec],
                fxn: {a in
                    let (x) = (a[0])
                    var results = [Router]()
                    results.append(
                        Router(
                            .exec,
                            CodeItem(
                                [ InstructionItem(.execY), a[0] ]
                            )
                        )
                    )
                    results.append(
                        Router(.exec, a[0])
                        )
                    return results
                }
            ),
        
        .execS :
            Behavior(
                .execS,
                takes: [.exec, .exec, .exec],
                fxn: {a in
                    var (x,y,z) = (a[0], a[1], a[2])
                    var results = [Router]()
                    
                    results.append(
                        Router(.exec,
                            CodeItem(
                                [a[1], a[2]],
                                call: [InstructionItem(.execS), z, y, x],
                                isContingent: Behavior.netContingency(of: x,y,z),
                                index: 2
                                ))
                        )
                    results.append(Router(.exec,z))
                    results.append(Router(.exec, x))
                    return results
                }
            ),

        .execWhen :
            Behavior(
                .execWhen,
                takes: [.bool, .exec],
                fxn: {a in
                    var (x, y) = (a[0] as! BoolItem, a[1])
                    var results = [Router]()
                    
                    if x.value {
                        y.call = [x, InstructionItem(.execWhen), y]
                        y.isContingent = Behavior.netContingency(of: x, y )
                        results.append(
                            Router(.exec,y)
                            )
                    }
                    return results
                }
            ),
        
        
        .execWhile :
            Behavior(
                .execWhile,
                takes: [.bool, .exec],
                fxn: {a in
                    var (x, y) = (a[0] as! BoolItem, a[1])
                    var results = [Router]()
                    let c = Behavior.netContingency(of: x, y )
                    
                    if x.value {
                        y.call = [x, InstructionItem(.execWhile), y]
                        y.isContingent = c
                        y.index = 2
                        var yCopy = y
                        
                        results.append(Router(.exec, y))
                        results.append(Router(.exec,
                                              InstructionItem(
                                                .execWhile,
                                                call: y.call,
                                                isContingent: c,
                                                index: 1
                                              )))
                        yCopy.index = 0
                        results.append(Router(.exec, yCopy))
                    }
                    return results
                }
            ),


        ]
}
