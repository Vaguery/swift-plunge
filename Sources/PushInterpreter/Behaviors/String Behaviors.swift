////
////  String Behaviors.swift
////  Propeller in Swift
////
////  Created by William Tozier on 5/9/26.
////

import DequeModule


extension Interpreter {
                
    static let stringBehaviors:[PushInstruction : Behavior] =
       [
        
        .stringButLast :
            Behavior(
                .stringButLast,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                String(x.value.dropLast(1)),
                                call:[x, InstructionItem(.stringButLast)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),

        .stringConcat :
            Behavior(
                .stringConcat,
                takes: [.string, .string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                y.value + x.value,
                                call:[y, x, InstructionItem(.stringConcat)],
                                isContingent: Behavior.netContingency(of: x,y )
                            )
                        )
                    ]
                }
            ),
        
        .stringConjChar :
            Behavior(
                .stringConjChar,
                takes: [.string, .char],
                fxn: {a in
                    let (y,x) = (a[0] as! StringItem, a[1] as! CharItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                y.value + String(x.value),
                                call:[y, x, InstructionItem(.stringConjChar)],
                                isContingent: Behavior.netContingency(of: x,y )
                            )
                        )
                    ]
                }
            ),
        
        .stringContains :
            Behavior(
                .stringContains,
                takes: [.string, .string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                y.value.contains(x.value),
                                call:[y, x, InstructionItem(.stringContains)],
                                isContingent: Behavior.netContingency(of: x,y )
                            )
                        )
                    ]
                }
            ),
        
        .stringContainsChar :
            Behavior(
                .stringContainsChar,
                takes: [.string, .char],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! CharItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                x.value.contains(y.value),
                                call:[y, x, InstructionItem(.stringContainsChar)],
                                isContingent: Behavior.netContingency(of: x,y )
                            )
                        )
                    ]
                }
            ),
        
        .stringIndexOfChar :
            Behavior(
                .stringIndexOfChar,
                takes: [.string, .char],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! CharItem)
                    if let idx = x.value.firstIndex(of: y.value) {
                        let intIdx = x.value.distance(from: x.value.startIndex, to: idx)
                        return [
                            Router(
                                .int,
                                IntItem(
                                    intIdx,
                                    call: [y, x, InstructionItem(.stringIndexOfChar)],
                                    isContingent: Behavior.netContingency(of: x,y )
                                    )
                                )
                            ]
                    } else {
                        return []  // not found
                    }
                }
            ),

        // the IntItem value is truncated at 0 before use as an index
        //
        .stringDrop :
            Behavior(
                .stringDrop,
                takes: [.string, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! IntItem)
                    let toDrop = max(0,y.value)
                    return [
                        Router(
                            .string,
                            StringItem(
                                String(x.value.dropLast(toDrop)),
                                call: [y, x, InstructionItem(.stringDrop)],
                                isContingent: Behavior.netContingency(of: x,y )
                            )
                        )
                    ]
                }
            ),

        
        // the IntItem value is truncated at 0 before use as an index
        //
        .stringTake :
            Behavior(
                .stringTake,
                takes: [.string, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! IntItem)
                    let toTake = max(0,y.value)
                    return [
                        Router(
                            .string,
                            StringItem(
                                String(x.value.prefix(toTake)),
                                call: [y, x, InstructionItem(.stringTake)],
                                isContingent: Behavior.netContingency(of: x, y )
                            )
                        )
                    ]
                }
            ),

        .stringIsEmpty :
            Behavior(
                .stringIsEmpty,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                x.value.isEmpty,
                                call: [x, InstructionItem(.stringIsEmpty)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),
        
        .stringFirst :
            Behavior(
                .stringFirst,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    if let c = x.value.first {
                        return [
                            Router(
                                .char,
                                CharItem(
                                    c,
                                    call: [x, InstructionItem(.stringFirst)],
                                    isContingent: Behavior.netContingency(of: x )
                                    )
                                )
                            ]
                    } else {
                        return []  // empty string
                    }
                }
            ),

    
        .stringLast :
            Behavior(
                .stringLast,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    if let c = x.value.last {
                        return [
                            Router(
                                .char,
                                CharItem(
                                    c,
                                    call: [x, InstructionItem(.stringLast)],
                                    isContingent: Behavior.netContingency(of: x )
                                    )
                                )
                            ]
                    } else {
                        return []  // empty string
                    }
                }
            ),

        .stringLTE :
            Behavior(
                .stringLTE,
                takes: [.string,.string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                y <= x,
                                call: [y, x, InstructionItem(.stringLTE)],
                                isContingent: Behavior.netContingency(of: x, y )
                            )
                        )
                    ]
                }
            ),

        .stringLT :
            Behavior(
                .stringLT,
                takes: [.string,.string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                y < x,
                                call: [y, x, InstructionItem(.stringLT)],
                                isContingent: Behavior.netContingency(of: x, y )
                            )
                        )
                    ]
                }
            ),

    
        .stringGT :
            Behavior(
                .stringGT,
                takes: [.string,.string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                y > x,
                                call: [y, x, InstructionItem(.stringGT)],
                                isContingent: Behavior.netContingency(of: x, y )
                            )
                        )
                    ]
                }
            ),

        .stringGTE :
            Behavior(
                .stringGTE,
                takes: [.string,.string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                y >= x,
                                call: [y, x, InstructionItem(.stringGTE)],
                                isContingent: Behavior.netContingency(of: x, y )
                            )
                        )
                    ]
                }
            ),
        
        
        .stringReverse :
            Behavior(
                .stringReverse,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                String(x.value.reversed() ),
                                call: [ x, InstructionItem(.stringReverse)],
                                isContingent: Behavior.netContingency(of: x, )
                            )
                        )
                    ]
                }
            ),
        
        .stringLength :
            Behavior(
                .stringLength,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    return [
                        Router(
                            .int,
                            IntItem(
                                x.value.count,
                                call: [ x, InstructionItem(.stringLength)],
                                isContingent: Behavior.netContingency(of: x, )
                            )
                        )
                    ]
                }
            ),
        
        .stringFromBool :
            Behavior(
                .stringFromBool,
                takes: [.bool],
                fxn: {a in
                    let (x) = (a[0] as! BoolItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                "\(x.value)",
                                call: [ x, InstructionItem(.stringFromBool)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),
        
        .stringFromChar :
            Behavior(
                .stringFromChar,
                takes: [.char],
                fxn: {a in
                    let (x) = (a[0] as! CharItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                "\(x.value)",
                                call: [ x, InstructionItem(.stringFromChar)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),
        
        .stringFromDouble :
            Behavior(
                .stringFromDouble,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                "\(x.value)",
                                call: [ x, InstructionItem(.stringFromDouble)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),
        
        .stringFromInt :
            Behavior(
                .stringFromInt,
                takes: [.int],
                fxn: {a in
                    let (x) = (a[0] as! IntItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                "\(x.value)",
                                call: [ x, InstructionItem(.stringFromInt)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),
        
//        .stringNth :
//            Instruction(
//                .stringNth,
//                takes: [.string, .int],
//                fxn: {a in
//                    let (x, y) = (a[0].sVal()!, a[1].iVal()!)
//                    if x.isEmpty {
//                        return []
//                    } else {
//                        let moduloIdx = (max(0,y) % x.count)
//                        let idx = x.index(x.startIndex, offsetBy: moduloIdx)
//                        let c = x[idx]
//                        return [Router(.char,
//                                       PushItem.makeChar(c,
//                                                         h : "( \(a[0].hist()) \(a[1].hist()) .stringNth )"))]
//                    }
//                }),
//
//        
//        .stringParseToChars :
//            Instruction(
//                .stringParseToChars,
//                takes: [.string],
//                fxn: {a in
//                    let (x) = (a[0].sVal()!)
//                    let chars = x.split(separator: "")
//                    var result:[Router] = []
//                    for (idx, c) in chars.enumerated() {
//                        result.append(Router(.string,
//                                             PushItem.makeString(String(c), h : "( \(a[0].hist()) .stringParseToChars ).\(idx)")))
//                    }
//                    return result
//                }),
//        
//        .stringOccurrencesOfChar :
//            Instruction(
//                .stringOccurrencesOfChar,
//                takes: [.string, .char],
//                fxn: {a in
//                    let (x, y) = (a[0].sVal()!, a[1].cVal()!)
//                    return [Router(.int,
//                                   PushItem.makeInt(x.filter({ $0 == y }).count,
//                                   h : "( \(a[0].hist()) \(a[1].hist()) .stringOccurrencesOfChar )"))]
//                }),
//        
//        .stringRemoveChar :
//            Instruction(
//                .stringRemoveChar,
//                takes: [.string, .char],
//                fxn: {a in
//                    let (x, y) = (a[0].sVal()!, a[1].cVal()!)
//                    return [Router(.string,
//                                   PushItem.makeString(x.filter({ $0 != y }),
//                                   h : "( \(a[0].hist()) \(a[1].hist()) .stringRemoveChar )"))]
//                }),
//        
//        .stringReplaceChar :
//            Instruction(
//                .stringReplaceChar,
//                takes: [.string, .char, .char],
//                fxn: {a in
//                    let (x, y, z) = (a[0].sVal()!, a[1].cVal()!, a[2].cVal()!)
//                    return [Router(.string,
//                                   PushItem.makeString(x.replacing(String(y), with: String(z)),
//                                   h : "( \(a[0].hist()) \(a[1].hist()) \(a[2].hist()) .stringReplaceChar )"))]
//                }),
//        
//        .stringReplaceFirstChar :
//            Instruction(
//                .stringReplaceFirstChar,
//                takes: [.string, .char, .char],
//                fxn: {a in
//                    let (x, y, z) = (a[0].sVal()!, a[1].cVal()!, a[2].cVal()!)
//                    return [Router(.string,
//                                   PushItem.makeString(x.replacing(String(y), with: String(z), maxReplacements: 1),
//                                   h : "( \(a[0].hist()) \(a[1].hist()) \(a[2].hist()) .stringReplaceFirstChar )"))]
//                }),
//        
//        
//        .stringReplace :
//            Instruction(
//                .stringReplace,
//                takes: [.string, .string, .string],
//                fxn: {a in
//                    let (x, y, z) = (a[0].sVal()!, a[1].sVal()!, a[2].sVal()!)
//                    return [Router(.string,
//                                   PushItem.makeString(z.replacing(y, with: x),
//                                   h : "( \(a[2].hist()) \(a[1].hist()) \(a[0].hist()) .stringReplace )"))]
//                }),
//        
//        .stringReplaceFirst :
//            Instruction(
//                .stringReplaceFirst,
//                takes: [.string, .string, .string],
//                fxn: {a in
//                    let (x, y, z) = (a[0].sVal()!, a[1].sVal()!, a[2].sVal()!)
//                    return [Router(.string,
//                                   PushItem.makeString(z.replacing(y, with: x, maxReplacements: 1),
//                                   h : "( \(a[2].hist()) \(a[1].hist()) \(a[0].hist()) .stringReplaceFirst )"))]
//                }),
//        
//        .stringRest :
//            Instruction(
//                .stringRest,
//                takes: [.string],
//                fxn: {a in
//                    var (x) = (a[0].sVal()!)
//                    if x.count > 0 {
//                        x.removeFirst(1)
//                        return [Router(.string,
//                                       PushItem.makeString(x, h : "( \(a[0].hist()) .stringRest )"))]
//                    } else {
//                        return []
//                    }
//                }),
//
//        .stringSetChar :
//            Instruction(
//                .stringSetChar,
//                takes: [.string, .int, .char],
//                fxn: {a in
//                    var (x, y, z) = (a[0].sVal()!, a[1].iVal()!, a[2].cVal()!)
//                    if x.isEmpty {
//                        return [Router(.string, a[0])]
//                    } else {
//                        let moduloIdx = (max(0,y) % x.count)
//                        let idx = x.index(x.startIndex, offsetBy: moduloIdx)
//                        x.replaceSubrange(idx...idx, with: String(z))
//                        return [Router(.string,
//                                       PushItem.makeString(x,
//                                                         h : "( \(a[0].hist()) \(a[1].hist()) \(a[2].hist()) .stringSetChar )"))]
//                    }
//                }),
//
//        .stringSplit :
//            Instruction(
//                .stringSplit,
//                takes: [.string],
//                fxn: {a in
//                    let (x) = (a[0].sVal()!)
//                    var result:[Router] = []
//                    let chunks = x.split {$0.isWhitespace }
//                    for chunk in chunks {
//                        result.append(Router(.string, PushItem.makeString(String(chunk),h:"so tired")))
//                    }
//                    return result
//                }),
//
//        .stringSubstring :
//            Instruction(
//                .stringSubstring,
//                takes: [.string, .int, .int],
//                fxn: {a in
//                    let (x,starter,ender) = (a[0].sVal(), a[1].iVal(), a[2].iVal())
//                    if x!.isEmpty == true {
//                        return [Router(.string, a[0])]
//                    } else {
//                        let range = x!.count-1
//                        let lhs = min(range,max(0,starter!))
//                        let start = x!.index(x!.startIndex, offsetBy: lhs)
//                        let rhs = min(range,max(0,starter!,ender!))
//                        let end = x!.index(x!.startIndex, offsetBy: rhs)
//                        let newString = x![start..<end]
//                        
//                        return [Router(.string, PushItem.string(String(newString)))]
//                    }
//                }),
//        
//        
//        .stringIterate :
//            Instruction(
//                .stringIterate,
//                takes: [.string, .exec],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal(), a[1])
//                    var thisResult: [Router] = []
//                    
//                    let count = x!.count
//                    if count == 0 {
//                        return thisResult
//                    } else {
//                        thisResult.append(Router(.exec, a[1]))
//                        
//                        let char1 = x!.first
//                        let remains = x!.dropFirst(1)
//                        thisResult.append(Router(.char, PushItem.char(char1!)))
//                        
//                        if count > 1 {
//                            thisResult.append(Router(.exec, PushItem.makeInst(.stringIterate)))
//                            thisResult.append(Router(.exec, PushItem.makeString(String(remains))))
//                            thisResult.append(Router(.exec, a[1]))
//                        }
//                    }
//                    return thisResult
//                }),
//
//
//
//        
//        
//        
//        

        ]
}
