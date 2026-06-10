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
        
            // the propeller definition is incorrect, in that it includes the first 32 unprintable characters
            .charFromInt : Instruction(
                .charFromInt,
                takes: [.int],
                fxn: {a in
                    let (x) = (a[0] as! IntItem)
                    let c = Character(UnicodeScalar(abs(x.value % 95) + 32)!)
                    return [Router(
                                .char,
                                CharItem(c,
                                         call:[x, InstructionItem(.charFromInt)],
                                         isContingent: Instruction.netContingency(of: x)
                                        )
                                )
                    ]
                }),

            // the propeller definition is incorrect, in that it includes the first 32 unprintable characters
            .charFromDouble : Instruction(
                .charFromDouble,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    let c = Character(Unicode.Scalar(abs(Int(x.value) % 95) + 32)!)
                    return [
                        Router(
                            .char,
                            CharItem(c,
                                     call:[x, InstructionItem(.charFromDouble)],
                                     isContingent: Instruction.netContingency(of: x)
                                    )
                        )
                    ]
                }),
        
            .charIsLetter : Instruction(
                .charIsLetter,
                takes: [.char],
                fxn: {a in
                    let (x) = (a[0] as! CharItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(x.value.isLetter,
                                     call: [x, InstructionItem(.charIsLetter)],
                                     isContingent: Instruction.netContingency(of: x)
                            )
                        )
                    ]
                }),
        
            .charIsDigit : Instruction(
                .charIsDigit,
                takes: [.char],
                fxn: {a in
                    let (x) = (a[0] as! CharItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(x.value.isWholeNumber,
                                     call: [x, InstructionItem(.charIsDigit)],
                                     isContingent: Instruction.netContingency(of: x)
                            )
                        )
                    ]
                }),
        
            .charIsWhitespace : Instruction(
                .charIsWhitespace,
                takes: [.char],
                fxn: {a in
                    let (x) = (a[0] as! CharItem)
                    return [Router(
                        .bool,
                        BoolItem(x.value.isWhitespace,
                                 call:[x, InstructionItem(.charIsWhitespace)],
                                 isContingent: Instruction.netContingency(of: x)
                        ))
                    ]
                })
        
        
    ]
}
