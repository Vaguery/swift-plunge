//
//  Bool Instructions.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/31/26.
//

import DequeModule


extension Interpreter {
    static let boolInstructions:[PushInstruction : Instruction] =
    
    [:
//        .boolNot :
//            Instruction(
//                .boolNot,
//                takes: [.bool],
//                fxn: {a in
//                    let (x) = (a[0].bVal()!)
//                    return [Router(.bool, PushItem.makeBool(!x, h:"(\(a[0].hist()) .boolNot)") )]
//                }),
//        .boolAnd :
//            Instruction(
//                .boolAnd,
//                takes: [.bool,.bool],
//                fxn: {a in
//                    let (x,y) = (a[0].bVal()!, a[1].bVal()!)
//                    return [Router(.bool, PushItem.makeBool(x && y, h:"(\(a[1].hist()) \(a[0].hist()) .boolAnd)") )]
//                }),
//        .boolOr :
//            Instruction(
//                .boolOr,
//                takes: [.bool,.bool],
//                fxn: {a in
//                    let (x,y) = (a[0].bVal()!, a[1].bVal()!)
//                    return [Router(.bool, PushItem.makeBool(x || y, h:"(\(a[1].hist()) \(a[0].hist()) .boolOr)") )]
//                }),
//        .boolXor :
//            Instruction(
//                .boolXor,
//                takes: [.bool,.bool],
//                fxn: {a in
//                    let (x,y) = (a[0].bVal()!, a[1].bVal()!)
//                    return [Router(.bool, PushItem.makeBool(x != y, h:"(\(a[1].hist()) \(a[0].hist()) .boolXor)") )]
//                }),
//        .boolInvertFirstThenAnd :
//            Instruction(
//                .boolInvertFirstThenAnd,
//                takes: [.bool,.bool],
//                fxn: {a in
//                    let (x,y) = (a[0].bVal()!, a[1].bVal()!)
//                    return [Router(.bool, PushItem.makeBool(!y && x, h:"(\(a[1].hist()) \(a[0].hist()) .boolInvertFirstThenAnd)") )]
//                }),
//        .boolInvertSecondThenAnd :
//            Instruction(
//                .boolInvertSecondThenAnd,
//                takes: [.bool,.bool],
//                fxn: {a in
//                    let (x,y) = (a[0].bVal()!, a[1].bVal()!)
//                    return [Router(.bool, PushItem.makeBool(y && !x, h:"(\(a[1].hist()) \(a[0].hist()) .boolInvertSecondThenAnd)") )]
//                }),
//        .boolFromFloat :
//            Instruction(
//                .boolFromFloat,
//                takes: [.float],
//                fxn: {a in
//                    let (x) = (a[0].fVal()!)
//                    return [Router(.bool, PushItem.makeBool(x != 0.0, h:"(\(a[0].hist()) .boolFromFloat)") )]
//                }),
//        .boolFromInt :
//            Instruction(
//                .boolFromInt,
//                takes: [.int],
//                fxn: {a in
//                    let (x) = (a[0].iVal()!)
//                    return [Router(.bool, PushItem.makeBool(x != 0, h:"(\(a[0].hist()) .boolFromInt)") )]
//                }),

    ]

}
