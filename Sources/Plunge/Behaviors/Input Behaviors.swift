//
//  Input Behaviors.swift
//  Plunge
//
//  Created by Bill Tozier on 5/31/26.
//

import DequeModule

nonisolated extension Interpreter {

    /// The behaviors of the listed inputs, `.input(0)` through
    /// `.input(listedInputCount - 1)`. Any other input's behavior is made by
    /// `inputBehavior(_:)` when it is first needed.
    static var inputBehaviors: [PushInstruction: Behavior] {
        var result: [PushInstruction: Behavior] = [:]
        for slot in 0..<PushInstruction.listedInputCount {
            result[.input(slot)] = inputBehavior(slot)
        }
        return result
    }

    /// The behavior of `.input(slot)`: push the value the training case binds to
    /// the slot, by way of `.exec`, or refuse when it binds none.
    static func inputBehavior(_ slot: Int) -> Behavior {
        let instructionName = PushInstruction.input(slot)
        return Behavior.contextRead(instructionName, produces: .input) { _, context in
                if var v = context.inputs[instructionName] {
                    v.call = context.recording([InstructionItem(instructionName)])
                    return [Router(.exec, v)]
                } else {
                    // Records the same `[.inputN]` its success branch does: a
                    // binding is environment state, re-supplied when a crux is
                    // re-run, so naming the instruction reproduces this error
                    // against the same environment. (Contrast the "on empty
                    // stack" and "missing args" errors, which depend on transient
                    // stack state and are their own literal crux — provenance law
                    // 4b.)
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "No input for \(instructionName)",
                                kind: .missingInput, source: instructionName,
                                call: context.recording([InstructionItem(instructionName)]))
                        )
                    ]
                }
            }
            .described(
                "Pushes input \(slot)'s value onto its own stack, by way of `.exec`; refuses when that input is "
                + "unbound.")
    }
}
