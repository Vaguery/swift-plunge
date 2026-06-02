//
//  Char Instructions.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule


extension Interpreter {
    
    static let charInstructions:[PushInstruction : Instruction] =
    [
        .charAllFromString : Instruction(
            .charAllFromString,
            takes: [.string],
            fxn: {a in
                let (s) = (a[0] as! StringItem)
                if s.value == "" {
                    return []
                } else {
                    let chars = Array(s.value)
                    let revChars = Array(chars.reversed())
                    
                    var result:[Router] = []
                    for idx in 0..<revChars.count {
                        result.append(
                            Router(
                                .char,
                                CharItem(chars[idx],
                                         call: [s, InstructionItem(.charAllFromString)],
                                         isContingent: Instruction.netContingency(of: s),
                                         index: idx)
                            ))
                    }
                    return result
                }
            }),
//        
//            .charFromInt : Instruction(
//                .charFromInt,
//                takes: [.int],
//                fxn: {a in
//                    let (x) = (a[0].iVal()!)
//                    let c = Character(UnicodeScalar(abs(x % 128))!)
//                    return [Router(.char, PushItem.makeChar(c, h:"(\(a[0].hist()) .charFromInt)") )]
//                }),
//        
//            .charFromFloat : Instruction(
//                .charFromFloat,
//                takes: [.float],
//                fxn: {a in
//                    let (x) = (a[0].fVal()!)
//                    let c = Character(UnicodeScalar(abs(Int(x) % 128))!)
//                    return [Router(.char, PushItem.makeChar(c, h:"(\(a[0].hist()) .charFromFloat)") )]
//                }),
//        
//            .charIsLetter : Instruction(
//                .charIsLetter,
//                takes: [.char],
//                fxn: {a in
//                    let (x) = (a[0].cVal()!)
//                    return [Router(.bool, PushItem.makeBool(x.isLetter, h:"(\(a[0].hist()) .charIsLetter)") )]
//                }),
//        
//            .charIsDigit : Instruction(
//                .charIsDigit,
//                takes: [.char],
//                fxn: {a in
//                    let (x) = (a[0].cVal()!)
//                    return [Router(.bool, PushItem.makeBool(x.isWholeNumber, h:"(\(a[0].hist()) .charIsDigit)") )]
//                }),
//        
//            .charIsWhitespace : Instruction(
//                .charIsWhitespace,
//                takes: [.char],
//                fxn: {a in
//                    let (x) = (a[0].cVal()!)
//                    return [Router(.bool, PushItem.makeBool(x.isWhitespace, h:"(\(a[0].hist()) .charIsWhitespace)") )]
//                })
//        
//        
    ]
}
