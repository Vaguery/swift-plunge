////
////  IntInstructions.swift
////  Propeller in Swift
////
////  Created by William Tozier on 6/2/26.
////
//
//
//import DequeModule
//
//
//extension Interpreter {
//            
//    static let intInstructions:[PushInstruction : Instruction] =
//        [
//            .intAdd :
//                Instruction(
//                    .intAdd,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.int, PushItem.makeInt(y + x, h:"(\(a[1].hist()) \(a[0].hist()) .intAdd)") )]
//                    }),
//            .intSubtract :
//                Instruction(
//                    .intSubtract,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.int, PushItem.makeInt(y - x, h:"(\(a[1].hist()) \(a[0].hist()) .intSubtract)") )]
//                    }),
//            .intMultiply :
//                Instruction(
//                    .intMultiply,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.int, PushItem.makeInt(y * x, h:"(\(a[1].hist()) \(a[0].hist()) .intMultiply)") )]
//                    }),
//            .intMax :
//                Instruction(
//                    .intMax,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.int, PushItem.makeInt(max(x,y), h:"(\(a[1].hist()) \(a[0].hist()) .intMax)") )]
//                    }),
//            .intMin :
//                Instruction(
//                    .intMin,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.int, PushItem.makeInt(min(x,y), h:"(\(a[1].hist()) \(a[0].hist()) .intMin)") )]
//                    }),
//            .intQuot :
//                Instruction(
//                    .intQuot,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.int, PushItem.makeInt(x==0 ? 1 : (y / x), h:"(\(a[1].hist()) \(a[0].hist()) .intQuot)") )]
//                    }),
//            .intMod :
//                Instruction(
//                    .intMod,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.int, PushItem.makeInt(x==0 ? 1 : (y % x), h:"(\(a[1].hist()) \(a[0].hist()) .intMod)") )]
//                    }),
//            .intGT :
//                Instruction(
//                    .intGT,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.bool, PushItem.makeBool(y > x, h:"(\(a[1].hist()) \(a[0].hist()) .intGT)") )]
//                    }),
//            .intGTE :
//                Instruction(
//                    .intGTE,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.bool, PushItem.makeBool(y >= x, h:"(\(a[1].hist()) \(a[0].hist()) .intGTE)") )]
//                    }),
//            .intLTE :
//                Instruction(
//                    .intLTE,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.bool, PushItem.makeBool(y <= x, h:"(\(a[1].hist()) \(a[0].hist()) .intLTE)") )]
//                    }),
//            .intLT :
//                Instruction(
//                    .intLT,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.bool, PushItem.makeBool(y < x, h:"(\(a[1].hist()) \(a[0].hist()) .intLT)") )]
//                    }),
//            .intEq :
//                Instruction(
//                    .intEq,
//                    takes: [.int,.int],
//                    fxn: {a in
//                        let (x,y) = (a[0].iVal()!, a[1].iVal()!)
//                        return [Router(.bool, PushItem.makeBool(y == x, h:"(\(a[1].hist()) \(a[0].hist()) .intEq)") )]
//                    }),
//            .intInc :
//                Instruction(
//                    .intInc,
//                    takes: [.int],
//                    fxn: {a in
//                        let (x) = (a[0].iVal()!)
//                        return [Router(.int, PushItem.makeInt(x + 1, h:"(\(a[0].hist()) .intInc)") )]
//                    }),
//            .intDec :
//                Instruction(
//                    .intDec,
//                    takes: [.int],
//                    fxn: {a in
//                        let (x) = (a[0].iVal()!)
//                        return [Router(.int, PushItem.makeInt(x - 1, h:"(\(a[0].hist()) .intDec)") )]
//                    }),
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
//            
//        ]
//
//}
