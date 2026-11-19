//
//  CruxShape.swift
//  Plunge
//
//  Cruxes compared up to the choice of constants.
//

nonisolated extension Interpreter {

    /// **A crux with its constants renamed in order of first appearance**: the
    /// first constant it mentions becomes `.constant(0)`, the next different one
    /// `.constant(1)`, and so on, at every depth of nesting.
    ///
    /// A constant is a tunable parameter, not an identity: any constant can be set
    /// to any other's value, so `( .constant3 x .intAdd )` and
    /// `( .constant8 x .intAdd )` are the same result up to tuning, and share a
    /// shape. Renaming rather than erasing keeps one distinction:
    /// `( .constant3 .constant3 .intAdd )` uses one parameter twice,
    /// `( .constant3 .constant8 .intAdd )` two independent ones, and their shapes
    /// differ. Inputs are not renamed; each is bound by the problem. (Until
    /// 2026-11-19 constants had types, and were numbered per type.)
    ///
    /// Still a program: the renamed constants are real constant instructions.
    static func cruxShape(_ crux: [any Item]) -> [any Item] {
        var renaming: [PushInstruction: PushInstruction] = [:]
        func rename(_ items: [any Item]) -> [any Item] {
            items.map { item in
                if let block = item as? CodeItem { return CodeItem(rename(block.value)) }
                guard let instruction = item as? InstructionItem, instruction.value.isConstant else { return item }
                if let known = renaming[instruction.value] { return InstructionItem(known) }
                let renamed = PushInstruction.constant(renaming.count)
                renaming[instruction.value] = renamed
                return InstructionItem(renamed)
            }
        }
        return rename(crux)
    }
}
