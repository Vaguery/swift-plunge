//
//  Input Behaviors.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 5/31/26.
//

import DequeModule

nonisolated extension Interpreter {

    //case input0, input1, input2, input3, input4, input5, input6, input7, input8, input9

    static var inputBehaviors: [PushInstruction: Behavior] {
        var result: [PushInstruction: Behavior] = [:]

        for instructionName in inputSlots {
            result[instructionName] =
                Behavior.contextRead(instructionName, produces: .input) { _, context in
                        if var v = context.inputs[instructionName] {
                            v.call = context.recording([InstructionItem(instructionName)])
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
                                        kind: .missingInput,
                                        call: context.recording([InstructionItem(instructionName)]))
                                )
                            ]
                        }
                    }
                    .described(
                        "Pushes input \(instructionName.rawValue.dropFirst("input".count))'s value onto its own "
                        + "stack, by way of `.exec`; refuses when that input is unbound.")
        }
        return result
    }
}
