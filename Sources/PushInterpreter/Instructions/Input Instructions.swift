//
//  Input Instructions.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/31/26.
//

//
//  Input Instructions.swift
//  Propeller in Swift
//
//  Created by William Tozier on 5/10/26.
//

import DequeModule


extension Interpreter {
    
    //case input0, input1, input2, input3, input4, input5, input6, input7, input8, input9
    
    static var inputInstructions:[PushInstruction : Instruction] {
        var result:[PushInstruction : Instruction] = [:]
        
        for i in 0..<10 {
            let instructionName = PushInstruction(rawValue: "input\(i)")!
            result[instructionName] =
            DirectInstruction(
                instructionName,
                takes: [],
                modifier: { (interpreter, collectedItems) in
                    if var v = interpreter.inputs[instructionName] {
                        v.call = [InstructionItem(instructionName)]
                        v.isContingent = true
                        return [Router(.exec, v)]
                    } else {
                        return [Router(.error,
                                       ErrorItem("WARN: no input for \(instructionName)"))]
                    }
                })
        }
        return result
    }
}
