//
//  CruxShape.swift
//  PushInterpreter
//
//  Cruxes compared up to the choice of constants.
//

nonisolated extension Interpreter {

    /// **A crux with its constants renamed in order of first appearance**, per
    /// type: the first int constant it mentions becomes `.int0`, the next
    /// different one `.int1`, and so on, at every depth of nesting.
    ///
    /// A constant is a tunable parameter, not an identity: any int constant can be
    /// set to any other's value, so `( .int3 x .intAdd )` and `( .int8 x .intAdd )`
    /// are the same result up to tuning, and share a shape. Renaming rather than
    /// erasing keeps one distinction: `( .int3 .int3 .intAdd )` uses one parameter
    /// twice, `( .int3 .int8 .intAdd )` two independent ones, and their shapes
    /// differ. Inputs are not renamed; each is bound by the problem.
    ///
    /// Still a program: the renamed constants are real constant instructions.
    static func cruxShape(_ crux: [any Item]) -> [any Item] {
        var renaming: [PushInstruction: PushInstruction] = [:]
        var used: [PushStack: Int] = [:]
        func rename(_ items: [any Item]) -> [any Item] {
            items.map { item in
                if let block = item as? CodeItem { return CodeItem(rename(block.value)) }
                guard let instruction = item as? InstructionItem,
                      let stack = constantInstructionStacks[instruction.value] else { return item }
                if let known = renaming[instruction.value] { return InstructionItem(known) }
                let index = used[stack, default: 0]
                used[stack] = index + 1
                // Ten constants per type, so a crux can never need an eleventh.
                guard let renamed = PushInstruction(rawValue: "\(stack)\(index)") else { return item }
                renaming[instruction.value] = renamed
                return InstructionItem(renamed)
            }
        }
        return rename(crux)
    }
}
