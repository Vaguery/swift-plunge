//
//  Input Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/31/26.
//

import DequeModule

nonisolated extension Interpreter {

    //case input0, input1, input2, input3, input4, input5, input6, input7, input8, input9

    static var inputBehaviors: [PushInstruction: Behavior] {
        var result: [PushInstruction: Behavior] = [:]

        for i in 0..<10 {
            let instructionName = PushInstruction(rawValue: "input\(i)")!
            result[instructionName] =
                BehaviorWithSideEffects(
                    instructionName,
                    takes: [],
                    modifier: { (interpreter, collectedItems) in
                        if var v = interpreter.inputs[instructionName] {
                            v.call = [InstructionItem(instructionName)]
                            v.isContingent = true
                            return [Router(.exec, v)]
                        } else {
                            return [
                                Router(
                                    .error,
                                    ErrorItem("No input for \(instructionName)")
                                )
                            ]
                        }
                    }
                )
        }
        return result
    }
}
