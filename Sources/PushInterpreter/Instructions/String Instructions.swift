////
////  String Instructions.swift
////  Propeller in Swift
////
////  Created by William Tozier on 5/9/26.
////
//
//import DequeModule
//
//
//extension Interpreter {
//                
//    static let stringInstructions:[PushInstruction : Instruction] =
//       [
//        .stringButLast :
//            Instruction(
//                .stringButLast,
//                takes: [.string],
//                fxn: {a in
//                    let (x) = (a[0].sVal()!)
//                    return [Router(.string, PushItem.makeString(String(x.dropLast(1)), h:"(\(a[0].hist())  .stringButLast)") )]
//                }),
//        
//        .stringConcat :
//            Instruction(
//                .stringConcat,
//                takes: [.string,.string],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal()!, a[1].sVal()!)
//                    return [Router(.string, PushItem.makeString(y + x, h:"(\(a[1].hist()) \(a[0].hist()) .stringConcat)") )]
//                }),
//        
//        .stringConjChar :
//            Instruction(
//                .stringConjChar,
//                takes: [.string,.char],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal()!, a[1].cVal()!)
//                    return [Router(.string,
//                                   PushItem.makeString("\(x)\(y)",
//                                   h : "( \(a[0].hist()) \(a[1].hist()) .stringConjChar )"))]
//                }),
//        
//        .stringContains :
//            Instruction(
//                .stringContains,
//                takes: [.string,.string],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal()!, a[1].sVal()!)
//                    return [Router(.bool,
//                                   PushItem.makeBool(y.contains(x),
//                                   h : "( \(a[1].hist()) \(a[0].hist()) .stringContains )"))]
//                }),
//        
//        .stringContainsChar :
//            Instruction(
//                .stringContainsChar,
//                takes: [.string,.char],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal()!, a[1].cVal()!)
//                    return [Router(.bool,
//                                   PushItem.makeBool(x.contains(String(y)),
//                                   h : "( \(a[1].hist()) \(a[0].hist()) .stringContainsChar )"))]
//                }),
//        
//        .stringIndexOfChar :
//            Instruction(
//                .stringIndexOfChar,
//                takes: [.string,.char],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal()!, a[1].cVal()!)
//                    if let idx = x.firstIndex(of: y) {
//                        let intIdx = x.distance(from: x.startIndex, to: idx)
//                        return [Router(.int,
//                                       PushItem.makeInt(intIdx,
//                                        h : "( \(a[1].hist()) \(a[0].hist()) .stringIndexOfChar )"))]
//                    } else {
//                        return []
//                    }
//                }),
//        
//        .stringDrop :
//            Instruction(
//                .stringDrop,
//                takes: [.string,.int],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal()!, a[1].iVal()!)
//                    let toDrop = max(0,y)
//                    return [Router(.string,
//                                   PushItem.makeString(String(x.dropLast(toDrop)),
//                                   h : "( \(a[1].hist()) \(a[0].hist()) .stringDrop )"))]
//                }),
//        
//        .stringTake :
//            Instruction(
//                .stringTake,
//                takes: [.string,.int],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal()!, a[1].iVal()!)
//                    let toDrop = max(0,y)
//                    return [Router(.string,
//                                   PushItem.makeString(String(x.prefix(toDrop)),
//                                   h : "( \(a[1].hist()) \(a[0].hist()) .stringTake )"))]
//                }),
//        
//        .stringEmptyString :
//            Instruction(
//                .stringEmptyString,
//                takes: [.string],
//                fxn: {a in
//                    let (x) = (a[0].sVal()!)
//                    return [Router(.bool,
//                                   PushItem.makeBool(x.isEmpty,
//                                   h : "( \(a[0].hist()) .stringEmptyString )"))]
//                }),
//        
//        .stringFirst :
//            Instruction(
//                .stringFirst,
//                takes: [.string],
//                fxn: {a in
//                    let (x) = (a[0].sVal()!)
//                    if let c = x.first {
//                        return [Router(.char,
//                                       PushItem.makeChar(c, h : "( \(a[0].hist()) .stringFirst )"))]
//                    } else {
//                        return []
//                    }
//                }),
//        
//        .stringLast :
//            Instruction(
//                .stringLast,
//                takes: [.string],
//                fxn: {a in
//                    let (x) = (a[0].sVal()!)
//                    if let c = x.last {
//                        return [Router(.char,
//                                       PushItem.makeChar(c, h : "( \(a[0].hist()) .stringLast )"))]
//                    } else {
//                        return []
//                    }
//                }),
//        
//        .stringLTE :
//            Instruction(
//                .stringLTE,
//                takes: [.string,.string],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal()!, a[1].sVal()!)
//                    return [Router(.bool,
//                                   PushItem.makeBool(y <= x,
//                                   h : "( \(a[1].hist()) \(a[0].hist()) .stringLTE )"))]
//                }),
//        
//        .stringLT :
//            Instruction(
//                .stringLT,
//                takes: [.string,.string],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal()!, a[1].sVal()!)
//                    return [Router(.bool,
//                                   PushItem.makeBool(y < x,
//                                   h : "( \(a[1].hist()) \(a[0].hist()) .stringLT )"))]
//                }),
//        
//        .stringGTE :
//            Instruction(
//                .stringGTE,
//                takes: [.string,.string],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal()!, a[1].sVal()!)
//                    return [Router(.bool,
//                                   PushItem.makeBool(y >= x,
//                                   h : "( \(a[1].hist()) \(a[0].hist()) .stringGTE )"))]
//                }),
//        
//        .stringGT :
//            Instruction(
//                .stringGT,
//                takes: [.string,.string],
//                fxn: {a in
//                    let (x,y) = (a[0].sVal()!, a[1].sVal()!)
//                    return [Router(.bool,
//                                   PushItem.makeBool(y > x,
//                                   h : "( \(a[1].hist()) \(a[0].hist()) .stringGT )"))]
//                }),
//        
//        .stringReverse :
//            Instruction(
//                .stringReverse,
//                takes: [.string],
//                fxn: {a in
//                    let (x) = (a[0].sVal()!)
//                    return [Router(.string,
//                                   PushItem.makeString(String(x.reversed()),
//                                   h : "( \(a[0].hist()) .stringReverse )"))]
//                }),
//        
//        .stringLength :
//            Instruction(
//                .stringLength,
//                takes: [.string],
//                fxn: {a in
//                    let (x) = (a[0].sVal()!)
//                    return [Router(.int,
//                                   PushItem.makeInt(x.count,
//                                   h : "( \(a[0].hist()) .stringLength )"))]
//                }),
//        
//        .stringFromBool :
//            Instruction(
//                .stringFromBool,
//                takes: [.bool],
//                fxn: {a in
//                    let (x) = (a[0].bVal()!)
//                    return [Router(.string,
//                                   PushItem.makeString("\(x)",
//                                   h : "( \(a[0].hist()) .stringFromBool )"))]
//                }),
//        
//        .stringFromChar :
//            Instruction(
//                .stringFromChar,
//                takes: [.char],
//                fxn: {a in
//                    let (x) = (a[0].cVal()!)
//                    return [Router(.string,
//                                   PushItem.makeString("\(x)",
//                                   h : "( \(a[0].hist()) .stringFromChar )"))]
//                }),
//        
//        .stringFromFloat :
//            Instruction(
//                .stringFromFloat,
//                takes: [.float],
//                fxn: {a in
//                    let (x) = (a[0].fVal()!)
//                    return [Router(.string,
//                                   PushItem.makeString("\(x)",
//                                   h : "( \(a[0].hist()) .stringFromFloat )"))]
//                }),
//        
//        .stringFromInt :
//            Instruction(
//                .stringFromInt,
//                takes: [.int],
//                fxn: {a in
//                    let (x) = (a[0].iVal()!)
//                    return [Router(.string,
//                                   PushItem.makeString("\(x)",
//                                   h : "( \(a[0].hist()) .stringFromInt )"))]
//                }),
//        
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
//
//        ]
//}
