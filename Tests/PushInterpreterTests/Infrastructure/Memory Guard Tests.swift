//
//  Memory Guard Tests.swift
//  PushInterpreterTests
//
//  The runaway guard watches stack *depth*; this watches total live *weight* — the
//  one quantity the local size caps never sum into. It catches the shape the
//  count-based guard misses: a stack whose items are individually legal but whose
//  combined content is over budget.
//

@testable import PushInterpreter
import DequeModule
import Testing

@Suite @MainActor
struct MemoryGuardTests {

    @Test func `fires when total live weight exceeds the budget`() {
        let interpreter = Interpreter()
        var settings = InterpreterSettings()
        settings.maxLiveWeight = 100
        settings.maxStackDepth = 100_000        // so the runaway/size caps don't intercept
        interpreter.config = settings

        // 200 items (past the weigh gate) whose weight (200) exceeds the budget (100).
        interpreter.stacks[.int] = Deque((0..<200).map { IntItem($0) as any Item })
        interpreter.stacks[.exec] = Deque([InstructionItem(.intAdd) as any Item])

        interpreter.enforceMemoryGuard()

        let errors = (interpreter.stacks[.error] ?? []).compactMap { ($0 as? ErrorItem)?.value }
        #expect(errors.contains { $0.hasPrefix(Interpreter.memoryMarker) })
        #expect(interpreter.stacks[.exec]?.isEmpty == true, "the run should be unwound")
    }

    @Test func `stays quiet below the budget and below the weigh gate`() {
        let interpreter = Interpreter()
        var settings = InterpreterSettings()
        settings.maxLiveWeight = 100
        interpreter.config = settings

        // Under the count gate (128): not even weighed.
        interpreter.stacks[.int] = Deque((0..<50).map { IntItem($0) as any Item })
        interpreter.enforceMemoryGuard()
        #expect((interpreter.stacks[.error] ?? []).isEmpty)
    }

    @Test func `disabled when maxLiveWeight is Int.max`() {
        let interpreter = Interpreter()
        var settings = InterpreterSettings()
        settings.maxLiveWeight = .max
        interpreter.config = settings
        interpreter.stacks[.int] = Deque((0..<1000).map { IntItem($0) as any Item })
        interpreter.enforceMemoryGuard()
        #expect((interpreter.stacks[.error] ?? []).isEmpty)
    }
}
