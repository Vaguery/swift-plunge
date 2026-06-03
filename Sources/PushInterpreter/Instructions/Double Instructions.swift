//
//  Double Instructions.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule
import Foundation


extension Interpreter {
            
    static let doubleInstructions:[PushInstruction : Instruction] =
        
    [
        .doubleAdd :
            Instruction(
                .doubleAdd,
                takes: [.double,.double],
                fxn: {a in
                    let (x,y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                    return [
                        Router(
                            .double,
                            DoubleItem(y.value + x.value,
                                       call:[y, x, InstructionItem(.doubleAdd)],
                                       isContingent: Instruction.netContingency(of: x, y)
                                      )
                        )
                    ]
                }
            ),
        
        .doubleQuot :
            Instruction(
                .doubleQuot,
                takes: [.double,.double],
                fxn: {a in
                    let (x,y) = (a[0] as! DoubleItem, a[1] as! DoubleItem)
                    var integralQuotient:Double
                    
                    if x.value.isZero {
                        integralQuotient = 1.0 }
                    else {
                        integralQuotient = (y.value - y.value.truncatingRemainder(dividingBy: x.value)) / x.value
                    }
                    return [
                        Router(
                            .double,
                            DoubleItem(integralQuotient,
                                       call:[y, x, InstructionItem(.doubleQuot)],
                                       isContingent: Instruction.netContingency(of: x, y)
                                      )
                        )
                    ]
                }
            ),
//
//            
//            .doubleMod :
//            Instruction(
//                .doubleMod,
//                takes: [.double,.double],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    if x.isZero {
//                        return [Router(.double, PushItem.makeDouble(1.0, h:"(\(a[1].hist()) \(a[0].hist()) .doubleMod)") )]
//                    } else {
//                        let remainder = y.truncatingRemainder(dividingBy: x)
//                        return [Router(.double, PushItem.makeDouble(remainder,
//                                                                  h:"(\(a[1].hist()) \(a[0].hist()) .doubleMod)") )]
//                    }
//                }),
//
//            .doubleMin :
//            Instruction(
//                .doubleMin,
//                takes: [.double,.double],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    return [Router(.double, PushItem.makeDouble(min(x,y), h:"(\(a[1].hist()) \(a[0].hist()) .doubleMin)") )]
//                }),
//            
//            .doubleMax :
//            Instruction(
//                .doubleMax,
//                takes: [.double,.double],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    return [Router(.double, PushItem.makeDouble(max(x,y), h:"(\(a[1].hist()) \(a[0].hist()) .doubleMax)") )]
//                }),
//            
//            .doubleSubtract :
//            Instruction(
//                .doubleSubtract,
//                takes: [.double,.double],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    return [Router(.double, PushItem.makeDouble(y - x, h:"(\(a[1].hist()) \(a[0].hist()) .doubleSubtract)") )]
//                }),
//            
//            .doubleMultiply :
//            Instruction(
//                .doubleMultiply,
//                takes: [.double,.double],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    return [Router(.double, PushItem.makeDouble(y * x, h:"(\(a[1].hist()) \(a[0].hist()) .doubleMultiply)") )]
//                }),
//            
//            .doubleFromInt :
//            Instruction(
//                .doubleFromInt,
//                takes: [.int],
//                fxn: {a in
//                    let (x) = (a[0].iVal()!)
//                    return [Router(.double, PushItem.makeDouble(Double(x), h:"(\(a[0].hist()) .doubleFromInt)") )]
//                }),
//            
//            .doubleGT :
//            Instruction(
//                .doubleGT,
//                takes: [.double,.double],
//                fxn: {a in
//                    let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                    return [Router(.bool, PushItem.makeBool(y > x, h:"(\(a[1].hist()) \(a[0].hist()) .doubleGT)") )]
//                }),
//            
//            .doubleGTE :
//                Instruction(
//                    .doubleGTE,
//                    takes: [.double,.double],
//                    fxn: {a in
//                        let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                        return [Router(.bool, PushItem.makeBool(y >= x, h:"(\(a[1].hist()) \(a[0].hist()) .doubleGTE)") )]
//                    }),
//            
//            .doubleLTE :
//                Instruction(
//                    .doubleLTE,
//                    takes: [.double,.double],
//                    fxn: {a in
//                        let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                        return [Router(.bool, PushItem.makeBool(y <= x, h:"(\(a[1].hist()) \(a[0].hist()) .doubleLTE)") )]
//                    }),
//            
//            .doubleLT :
//                Instruction(
//                    .doubleLT,
//                    takes: [.double,.double],
//                    fxn: {a in
//                        let (x,y) = (a[0].fVal()!, a[1].fVal()!)
//                        return [Router(.bool, PushItem.makeBool(y < x, h:"(\(a[1].hist()) \(a[0].hist()) .doubleLT)") )]
//                    }),
//            
//            .doubleCos :
//                Instruction(
//                    .doubleCos,
//                    takes: [.double],
//                    fxn: {a in
//                        let (x) = (a[0].fVal()!)
//                        return [Router(.double, PushItem.makeDouble(cos(x), h:"(\(a[0].hist()) .doubleCos)") )]
//                    }),
//            
//            .doubleSin :
//                Instruction(
//                    .doubleSin,
//                    takes: [.double],
//                    fxn: {a in
//                        let (x) = (a[0].fVal()!)
//                        return [Router(.double, PushItem.makeDouble(sin(x), h:"(\(a[0].hist()) .doubleSin)") )]
//                    }),
//            
//            .doubleTan :
//                Instruction(
//                    .doubleTan,
//                    takes: [.double],
//                    fxn: {a in
//                        let (x) = (a[0].fVal()!)
//                        return [Router(.double, PushItem.makeDouble(tan(x), h:"(\(a[0].hist()) .doubleTan)") )]
//                    }),
//            
//            .doubleInc :
//                Instruction(
//                    .doubleInc,
//                    takes: [.double],
//                    fxn: {a in
//                        let (x) = (a[0].fVal()!)
//                        return [Router(.double, PushItem.makeDouble(x + 1.0, h:"(\(a[0].hist()) .doubleInc)") )]
//                    }),
//            
//            .doubleDec :
//                Instruction(
//                    .doubleDec,
//                    takes: [.double],
//                    fxn: {a in
//                        let (x) = (a[0].fVal()!)
//                        return [Router(.double, PushItem.makeDouble(x - 1.0, h:"(\(a[0].hist()) .doubleDec)") )]
//                    }),
//            
//            .doubleFromBool :
//                Instruction(
//                    .doubleFromBool,
//                    takes: [.bool],
//                    fxn: {a in
//                        let (x) = (a[0].bVal()!)
//                        return [Router(.double, PushItem.makeDouble(x ? 1.0 : 0.0, h:"(\(a[0].hist()) .doubleFromBool)") )]
//                    }),
//            
//            .doubleFromChar :
//                Instruction(
//                    .doubleFromChar,
//                    takes: [.char],
//                    fxn: {a in
//                        let (x) = (a[0].cVal()!)
//                        let num = (x.isASCII ? Double(x.asciiValue!) : 0.0)
//                        return [Router(.double, PushItem.makeDouble(num, h:"(\(a[0].hist()) .doubleFromChar)") )]
//                    }),
//            
//            .doubleFromString :
//                Instruction(
//                    .doubleFromString,
//                    takes: [.string],
//                    fxn: {a in
//                        let (x) = (a[0].sVal()!)
//                        let num = Double(x) ?? 0.0
//                        return [Router(.double, PushItem.makeDouble(num, h:"(\(a[0].hist()) .doubleFromString)") )]
//                    }),



        ]
        
}

