//
//  ConstantSlots.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

nonisolated extension Interpreter {

    /// The stacks that carry constant slots, in the order the constant
    /// behaviors are generated (see `Interpreter.constantBehaviors`).
    static let constantStacks: [PushStack] =
        [.int, .double, .string, .char, .vecInt, .vecDouble, .vecString, .vecBool]

    /// The constant instructions of each constant stack, by slot: `.int0` is slot
    /// 0 of `.int`. Derived from the instruction set (a constant's name is its
    /// stack's name and a slot number), never written as a count, since the number
    /// of slots is not fixed.
    static let constantSlots: [PushStack: [PushInstruction]] = {
        var slots: [PushStack: [(slot: Int, instruction: PushInstruction)]] = [:]
        for instruction in PushInstruction.allCases {
            for stack in constantStacks {
                let name = instruction.rawValue
                guard name.hasPrefix(stack.rawValue), name.count > stack.rawValue.count,
                      name.dropFirst(stack.rawValue.count).allSatisfy({ $0.isASCII && $0.isWholeNumber }),
                      let slot = Int(name.dropFirst(stack.rawValue.count)) else { continue }
                slots[stack, default: []].append((slot, instruction))
            }
        }
        return slots.mapValues { $0.sorted { $0.slot < $1.slot }.map(\.instruction) }
    }()

    /// Maps each constant instruction (`.int0` … `.vecBool9`) to the stack whose
    /// value type it must hold. Constants are *stored* keyed by instruction (like
    /// `inputs`); this map exists only to validate that a bound value's type
    /// matches its token.
    static let constantInstructionStacks: [PushInstruction: PushStack] = {
        var map: [PushInstruction: PushStack] = [:]
        for (stack, instructions) in constantSlots {
            for instruction in instructions { map[instruction] = stack }
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
