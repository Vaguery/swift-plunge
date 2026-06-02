//
//  Float Instructions.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule
import Foundation


extension Interpreter {
            
    static let floatInstructions:[PushInstruction : Instruction] =
        
    [:
//            .floatAdd :
//            Instruction(
//                .floatAdd,
//                takes: [.float,.float],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    return [Router(.float, PushItem.makeFloat(y + x, h:"(\(a[1].hist()) \(a[0].hist()) .floatAdd)") )]
//                }),
//            
//            .floatQuot :
//            Instruction(
//                .floatQuot,
//                takes: [.float,.float],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    if x.isZero {
//                        return [Router(.float, PushItem.makeFloat(1.0, h:"(\(a[1].hist()) \(a[0].hist()) .floatQuot)") )]
//                    } else {
//                        let integralQuotient = (y - y.truncatingRemainder(dividingBy: x))/x
//                        return [Router(.float, PushItem.makeFloat(integralQuotient,
//                                                                  h:"(\(a[1].hist()) \(a[0].hist()) .floatQuot)") )]
//                    }
//                }),
//            
//            
//            .floatMod :
//            Instruction(
//                .floatMod,
//                takes: [.float,.float],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    if x.isZero {
//                        return [Router(.float, PushItem.makeFloat(1.0, h:"(\(a[1].hist()) \(a[0].hist()) .floatMod)") )]
//                    } else {
//                        let remainder = y.truncatingRemainder(dividingBy: x)
//                        return [Router(.float, PushItem.makeFloat(remainder,
//                                                                  h:"(\(a[1].hist()) \(a[0].hist()) .floatMod)") )]
//                    }
//                }),
//
//            .floatMin :
//            Instruction(
//                .floatMin,
//                takes: [.float,.float],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    return [Router(.float, PushItem.makeFloat(min(x,y), h:"(\(a[1].hist()) \(a[0].hist()) .floatMin)") )]
//                }),
//            
//            .floatMax :
//            Instruction(
//                .floatMax,
//                takes: [.float,.float],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    return [Router(.float, PushItem.makeFloat(max(x,y), h:"(\(a[1].hist()) \(a[0].hist()) .floatMax)") )]
//                }),
//            
//            .floatSubtract :
//            Instruction(
//                .floatSubtract,
//                takes: [.float,.float],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    return [Router(.float, PushItem.makeFloat(y - x, h:"(\(a[1].hist()) \(a[0].hist()) .floatSubtract)") )]
//                }),
//            
//            .floatMultiply :
//            Instruction(
//                .floatMultiply,
//                takes: [.float,.float],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    return [Router(.float, PushItem.makeFloat(y * x, h:"(\(a[1].hist()) \(a[0].hist()) .floatMultiply)") )]
//                }),
//            
//            .floatFromInt :
//            Instruction(
//                .floatFromInt,
//                takes: [.int],
//                fxn: {a in
//                    let (x) = (a[0].iVal()!)
//                    return [Router(.float, PushItem.makeFloat(Double(x), h:"(\(a[0].hist()) .floatFromInt)") )]
//                }),
//            
//            .floatGT :
//            Instruction(
//                .floatGT,
//                takes: [.float,.float],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    return [Router(.bool, PushItem.makeBool(y > x, h:"(\(a[1].hist()) \(a[0].hist()) .floatGT)") )]
//                }),
//            
//            .floatGTE :
//                Instruction(
//                    .floatGTE,
//                    takes: [.float,.float],
//                    fxn: {a in
//                        let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                        return [Router(.bool, PushItem.makeBool(y >= x, h:"(\(a[1].hist()) \(a[0].hist()) .floatGTE)") )]
//                    }),
//            
//            .floatLTE :
//                Instruction(
//                    .floatLTE,
//                    takes: [.float,.float],
//                    fxn: {a in
//                        let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                        return [Router(.bool, PushItem.makeBool(y <= x, h:"(\(a[1].hist()) \(a[0].hist()) .floatLTE)") )]
//                    }),
//            
//            .floatLT :
//                Instruction(
//                    .floatLT,
//                    takes: [.float,.float],
//                    fxn: {a in
//                        let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                        return [Router(.bool, PushItem.makeBool(y < x, h:"(\(a[1].hist()) \(a[0].hist()) .floatLT)") )]
//                    }),
//            
//            .floatCos :
//                Instruction(
//                    .floatCos,
//                    takes: [.float],
//                    fxn: {a in
//                        let (x) = (a[0].fVal()!)
//                        return [Router(.float, PushItem.makeFloat(cos(x), h:"(\(a[0].hist()) .floatCos)") )]
//                    }),
//            
//            .floatSin :
//                Instruction(
//                    .floatSin,
//                    takes: [.float],
//                    fxn: {a in
//                        let (x) = (a[0].fVal()!)
//                        return [Router(.float, PushItem.makeFloat(sin(x), h:"(\(a[0].hist()) .floatSin)") )]
//                    }),
//            
//            .floatTan :
//                Instruction(
//                    .floatTan,
//                    takes: [.float],
//                    fxn: {a in
//                        let (x) = (a[0].fVal()!)
//                        return [Router(.float, PushItem.makeFloat(tan(x), h:"(\(a[0].hist()) .floatTan)") )]
//                    }),
//            
//            .floatInc :
//                Instruction(
//                    .floatInc,
//                    takes: [.float],
//                    fxn: {a in
//                        let (x) = (a[0].fVal()!)
//                        return [Router(.float, PushItem.makeFloat(x + 1.0, h:"(\(a[0].hist()) .floatInc)") )]
//                    }),
//            
//            .floatDec :
//                Instruction(
//                    .floatDec,
//                    takes: [.float],
//                    fxn: {a in
//                        let (x) = (a[0].fVal()!)
//                        return [Router(.float, PushItem.makeFloat(x - 1.0, h:"(\(a[0].hist()) .floatDec)") )]
//                    }),
//            
//            .floatFromBool :
//                Instruction(
//                    .floatFromBool,
//                    takes: [.bool],
//                    fxn: {a in
//                        let (x) = (a[0].bVal()!)
//                        return [Router(.float, PushItem.makeFloat(x ? 1.0 : 0.0, h:"(\(a[0].hist()) .floatFromBool)") )]
//                    }),
//            
//            .floatFromChar :
//                Instruction(
//                    .floatFromChar,
//                    takes: [.char],
//                    fxn: {a in
//                        let (x) = (a[0].cVal()!)
//                        let num = (x.isASCII ? Double(x.asciiValue!) : 0.0)
//                        return [Router(.float, PushItem.makeFloat(num, h:"(\(a[0].hist()) .floatFromChar)") )]
//                    }),
//            
//            .floatFromString :
//                Instruction(
//                    .floatFromString,
//                    takes: [.string],
//                    fxn: {a in
//                        let (x) = (a[0].sVal()!)
//                        let num = Double(x) ?? 0.0
//                        return [Router(.float, PushItem.makeFloat(num, h:"(\(a[0].hist()) .floatFromString)") )]
//                    }),



        ]
        
}

