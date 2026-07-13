//
//  ConstantSlots.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
//

nonisolated extension Interpreter {

    /// The stacks that carry constant slots, in the order the constant
    /// behaviors are generated (see `Interpreter.constantBehaviors`).
    static let constantStacks: [PushStack] =
        [.int, .double, .string, .char, .vecInt, .vecDouble, .vecString, .vecBool]

    /// Maps each constant instruction (`.int0` … `.vecBool9`) to the stack whose
    /// value type it must hold. Built from the same naming rule the constant
    /// behaviors use (`"\(stack)\(index)"`). Constants are *stored* keyed by
    /// instruction (like `inputs`); this map exists only to validate that a
    /// bound value's type matches its token.
    static let constantInstructionStacks: [PushInstruction: PushStack] = {
        var map: [PushInstruction: PushStack] = [:]
        for stack in constantStacks {
            for index in 0..<10 {
                if let instruction = PushInstruction(rawValue: "\(stack)\(index)") {
                    map[instruction] = stack
                }
            }
        }
        return map
    }()

    /// Binds constant values by their instruction token (e.g. `.int8`), merging
    /// into `constants`.
    ///
    /// A token that is not a constant instruction, or whose value type does not
    /// match the token's stack, is skipped and returned as a validation signal.
    /// Nothing traps, so malformed external input cannot crash a `Runner` here.
    @discardableResult
    func loadConstants(_ newConstants: [PushInstruction: any Item]) -> [PushInstruction] {
        var rejected: [PushInstruction] = []
        for (instruction, value) in newConstants {
            guard let stack = Interpreter.constantInstructionStacks[instruction],
                  stack.accepts(value)
            else {
                rejected.append(instruction)
                continue
            }
            constants[instruction] = value
        }
        return rejected
    }
}
