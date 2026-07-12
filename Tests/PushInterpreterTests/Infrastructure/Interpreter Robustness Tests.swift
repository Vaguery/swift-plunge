//
//  Interpreter Robustness Tests.swift
//  PropellerWithStructs
//
//  Coverage + edge-case tests supporting Proposal A:
//   - every registered Behavior runs its transform through the validated push
//     gate without tripping the stack-type invariant;
//   - an instruction with no registered behavior routes to .error instead of
//     trapping the interpreter loop.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct InterpreterRobustnessTests {

    /// A benign, well-typed representative Item for each stack, used to satisfy
    /// any behavior's argument needs (and to seed stacks that behaviors read
    /// directly, e.g. combinators) so the transform actually runs.
    func sample(for stack: PushStack) -> any Item {
        switch stack {
        case .bool:      return BoolItem(false)
        case .int:       return IntItem(1)
        case .double:    return DoubleItem(1.0)
        case .char:      return CharItem(Character("a"))
        case .string:    return StringItem("x")
        case .code:      return CodeItem([BoolItem(false)])
        case .vecBool:   return VecBoolItem([false, true])
        case .vecInt:    return VecIntItem([1, 2, 3])
        case .vecDouble: return VecDoubleItem([1.0, 2.0])
        case .vecString: return VecStringItem(["a", "b"])
        case .exec:      return BoolItem(false)
        case .error:     return ErrorItem("x")
        }
    }

    /// Drives every behavior in the language once. Each stack is seeded with
    /// several well-typed items so both the declared arguments and any direct
    /// stack reads are satisfied. If any behavior emitted a mis-tagged Router,
    /// `push(_:to:)` would fatalError — so reaching the end of the loop is the
    /// assertion that the whole language honors the stack-type invariant.
    @Test func `every behavior honors the stack-type invariant`() {
        #expect(!Interpreter.language.isEmpty)

        for (_, behavior) in Interpreter.language {
            let inty = Interpreter()
            for stack in PushStack.allCases where stack != .error {
                for _ in 0..<5 {
                    inty.stacks[stack]!.prepend(sample(for: stack))
                }
            }
            behavior.act(on: inty)
        }
    }

    /// An enumerated instruction with no registered behavior must be reported,
    /// not crash the step loop.
    @Test func `unknown instruction routes to error`() {
        let inty = Interpreter()
        // remove a behavior to simulate an unimplemented / de-registered one
        inty.behaviors[.intAdd] = nil
        inty.stacks[.exec]!.prepend(InstructionItem(.intAdd))

        inty.step()

        #expect(stackString(inty, .error).contains("intAdd is an unknown instruction"))
    }
}
