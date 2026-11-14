//
//  Sandbox Behaviors Tests.swift
//  PlungeTests
//
//  An instruction disabled for a run stays disabled inside the sandboxes that
//  function instructions start: a mapped function, an applied one, and a
//  derivation. Before 2026-11-14 each sandbox ran the full language, so a
//  disabled instruction still ran inside them.
//

@testable import Plunge
import Testing

@Suite
struct SandboxBehaviorsTests {

    /// `«fn (int) -> int: $0 1 .intAdd»`, adding one.
    static let addOne = FunctionItem(body: [IntItem(1), InstructionItem(.intAdd)],
                                     holes: [.init(stack: .int, positions: [0])], output: .int)

    static func run(_ program: [any Item], functions: [any Item] = [], disabling: Set<PushInstruction>) -> Interpreter {
        let inty = Interpreter()
        inty.behaviors = BehaviorTable(Interpreter.language, disabling: disabling)
        inty.load(stacks: [.function: functions], program: program)
        inty.run()
        return inty
    }

    @Test func `a mapped function uses the run's instructions`() {
        let program: [any Item] = [VecIntItem([1, 2, 3]), InstructionItem(.vecIntMap)]
        let enabled = Self.run(program, functions: [Self.addOne], disabling: [])
        #expect(enabled.stacks[.vecInt]!.first?.pretty() == "[2, 3, 4]")
        let disabled = Self.run(program, functions: [Self.addOne], disabling: [.intAdd])
        #expect(disabled.stacks[.vecInt]!.first?.pretty() != "[2, 3, 4]",
                "a disabled .intAdd must not run inside the mapped function")
    }

    @Test func `an applied function uses the run's instructions`() {
        let program: [any Item] = [IntItem(5), InstructionItem(.functionApply)]
        let enabled = Self.run(program, functions: [Self.addOne], disabling: [])
        #expect(enabled.stacks[.int]!.first?.pretty() == "6")
        let disabled = Self.run(program, functions: [Self.addOne], disabling: [.intAdd])
        #expect(disabled.stacks[.int]!.first?.pretty() != "6")
    }

    @Test func `a derivation uses the run's instructions`() {
        let program: [any Item] = [CodeItem([IntItem(1), InstructionItem(.intAdd)]),
                                   InstructionItem(.codePushAllFunctions)]
        func derived(_ inty: Interpreter) -> [String] {
            inty.stacks[.function]!.map { $0.pretty() }.filter { $0.contains(".intAdd") }
        }
        #expect(!derived(Self.run(program, disabling: [])).isEmpty)
        #expect(derived(Self.run(program, disabling: [.intAdd])).isEmpty,
                "no function is derived from a disabled .intAdd")
    }
}
