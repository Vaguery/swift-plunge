//
//  Exec Instructions.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule


extension Interpreter {
            
    static let execInstructions:[PushInstruction : Instruction] =
    [:
        
        
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
//        .execK :
//            Instruction(
//                .execK,
//                takes: [.exec, .exec],
//                fxn: {a in
//                    let (x, y) = (a[0], a[1])
//                    return [Router(.exec, a[0].updateHistory("( .execK \(a[0].hist()) \(a[1].hist()) )"))]
//                }),
//        
//        .execY :
//            Instruction(
//                .execY,
//                takes: [.exec],
//                fxn: {a in
//                    let (x) = (a[0])
//                    return [Router(.exec, PushItem.codeblock(
//                            [PushItem.makeInst(.execY), a[0]])),
//                            Router(.exec, a[0])]
//                }),
//        
//        .execS :
//            Instruction(
//                .execS,
//                takes: [.exec, .exec, .exec],
//                fxn: {a in
//                    let (x,y,z) = (a[0], a[1], a[2])
//                    return [Router(.exec,
//                                   PushItem.codeblock(
//                                        [a[1], a[2]])),
//                            Router(.exec, a[2]),
//                            Router(.exec, a[0])
//                            ]
//                }),
//
//        .execWhen :
//            Instruction(
//                .execWhen,
//                takes: [.bool, .exec],
//                fxn: {a in
//                    let (x, y) = (a[0].bVal()!, a[1])
//                    if x {
//                        return [Router(.exec, a[1].updateHistory("( \(a[0].hist()) .execWhen \(a[1].hist()) ))"))]
//                    } else {
//                        return []
//                    }
//                    // in original code, (execWhen A) will keep A if true, discard it
//                }),
//        
//        .execWhile :
//            Instruction(
//                .execWhile,
//                takes: [.bool, .exec],
//                fxn: {a in
//                    let (x, y) = (a[0].bVal()!, a[1])
//                    if x {
//                        return [Router(.exec,PushItem.makeInst(.execWhile)),
//                                       Router(.exec, a[1].updateHistory("(\(a[0].hist()) .execWhile \(y.hist()) )"))]
//                    } else {
//                        return []
//                    }
//                }),


        ]
}
