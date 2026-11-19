//
//  ConstantSlots.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//  Untyped since 2026-11-19: a constant slot holds a value of any type.
//

nonisolated extension Interpreter {

    /// Binds constant values by their instruction (`.constant(3)`), merging into
    /// `constants`.
    ///
    /// Any item may be bound to any constant slot: the value goes to its own stack
    /// when the instruction runs, so the slot has no type to check. Only a key that
    /// is not a constant (an input, a named instruction, or a negative slot) is
    /// skipped, and returned as a validation signal. Nothing traps, so malformed
    /// external input cannot crash a `Runner` here.
    @discardableResult
    func loadConstants(_ newConstants: [PushInstruction: any Item]) -> [PushInstruction] {
        var rejected: [PushInstruction] = []
        for (instruction, value) in newConstants {
            guard case .constant(let slot) = instruction, slot >= 0 else {
                rejected.append(instruction)
                continue
            }
            constants[instruction] = value
        }
        return rejected
    }
}


public nonisolated extension PushInstruction {

    /// The types random code gives the listed constants, ten slots each, in this
    /// order: `.constant(0…9)` ints, `.constant(10…19)` doubles, then strings,
    /// characters, and vectors of ints, doubles, strings and Booleans
    /// (`.constant(70…79)`).
    ///
    /// **A convention for random code only.** The language puts no type on a
    /// constant slot. This is how random individuals have always spread their
    /// constants across types (it was ten slots per type when each slot had a
    /// typed name, `.constant0` to `.constant79`), kept so that random code draws the same
    /// values as before.
    static let conventionalConstantStacks: [PushStack] =
        [.int, .double, .string, .char, .vecInt, .vecDouble, .vecString, .vecBool]

    /// The type random code gives constant `slot`, by
    /// ``conventionalConstantStacks``: nil past the listed constants, or for a
    /// slot below 0.
    static func conventionalStack(ofConstantSlot slot: Int) -> PushStack? {
        guard slot >= 0, slot < listedConstantCount else { return nil }
        return conventionalConstantStacks[slot / 10]
    }

    /// The constant that the typed constant `stack` number `index` became when
    /// constants lost their types: `.constant3` is `.constant(3)`, `.constant13` is
    /// `.constant(13)`, `.constant79` is `.constant(79)`. Nil for a stack that had no
    /// constants, or an index past 9.
    static func conventionalConstant(_ stack: PushStack, _ index: Int) -> PushInstruction? {
        guard let position = conventionalConstantStacks.firstIndex(of: stack), (0..<10).contains(index) else {
            return nil
        }
        return .constant(position * 10 + index)
    }
}
