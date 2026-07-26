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
                            return [Router(.exec, v)]
                        } else {
                            // Records the same `[.inputN]` its success branch
                            // does: a binding is environment state, re-supplied
                            // when a crux is re-run, so naming the instruction
                            // reproduces this error against the same environment.
                            // (Contrast the "on empty stack" and "missing args"
                            // errors, which depend on transient stack state and
                            // are their own literal crux — provenance law 4b.)
                            return [
                                Router(
                                    .error,
                                    ErrorItem(
                                        "No input for \(instructionName)",
                                        call: [InstructionItem(instructionName)])
                                )
                            ]
                        }
                    }
                )
        }
        return result
    }
}
