//
//  Runaway Guard Tests.swift
//  PlungeTests
//
//  Exercises Interpreter.enforceRunawayGuard by seeding stacks directly into
//  the mid-loop states it is meant to catch, rather than trying to hand-build a
//  real runaway program (which is fiddly and less precise). Each test isolates
//  one gate: the data-side symptom, the control-side confirmation, or a knob.
//

@testable import Plunge
import Testing
import DequeModule

@Suite
struct RunawayGuardTests {

    /// An interpreter with `intPile` copies of one IntItem on `.int` and the
    /// given instructions atop `.exec`. 1200 clears the default trigger (1000).
    func loaded(intPile count: Int, value: Int = 7, exec: [PushInstruction]) -> Interpreter {
        let interp = Interpreter()
        interp.stacks[.int] = Deque((0..<count).map { _ in IntItem(value) as any Item })
        interp.stacks[.exec] = Deque(exec.map { InstructionItem($0) as any Item })
        return interp
    }

    func errorMarkers(_ interp: Interpreter) -> [String] {
        interp.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.value }
    }

    @Test func `the iterators set names the looping instructions, not others`() {
        #expect(Interpreter.reEntrantInstructions.contains(.iteratorPlay))
        #expect(Interpreter.reEntrantInstructions.contains(.iteratorPlayDelayed))
        #expect(Interpreter.reEntrantInstructions.contains(.execY))
        #expect(Interpreter.reEntrantInstructions.contains(.vecIntIterate))
        #expect(!Interpreter.reEntrantInstructions.contains(.intAdd))

        // `.execDoRange` and its siblings are deliberately absent now: they fire
        // once, build an iterator and hand it to `.iteratorPlay`, so they never
        // sit on `.exec` waiting for a next pass. `.iteratorPlay` is what does,
        // and it is the signal in their place.
        #expect(!Interpreter.reEntrantInstructions.contains(.execDoRange))
        #expect(!Interpreter.reEntrantInstructions.contains(.execDoCount))
        #expect(!Interpreter.reEntrantInstructions.contains(.execDoTimes))
    }

    @Test func `a piling stack with a live looper is stopped`() {
        let interp = loaded(intPile: 1200, exec: [.iteratorPlay])
        interp.enforceRunawayGuard()
        #expect(interp.stacks[.exec]!.isEmpty)   // unwound
        #expect(errorMarkers(interp).contains { $0.hasPrefix(Interpreter.runawayMarker) })
    }

    @Test func `a monotone counter with a live looper is stopped`() {
        let interp = Interpreter()
        interp.stacks[.int] = Deque((0..<1200).map { IntItem($0) as any Item })   // 0,1,2,… distinct + monotone
        interp.stacks[.exec] = Deque([InstructionItem(.iteratorPlay) as any Item])
        interp.enforceRunawayGuard()
        #expect(interp.stacks[.exec]!.isEmpty)
        #expect(errorMarkers(interp).contains { $0.contains("counting monotonically") })
    }

    @Test func `a deep stack with no looper on exec is left alone`() {
        let interp = loaded(intPile: 1200, exec: [.intAdd, .boolPop])   // control gate fails
        interp.enforceRunawayGuard()
        #expect(interp.stacks[.exec]!.count == 2)
        #expect(errorMarkers(interp).isEmpty)
    }

    @Test func `a deep but varied stack is left alone`() {
        let interp = Interpreter()
        // Squares mod 97: ~49 distinct values, non-monotone, no short period.
        interp.stacks[.int] = Deque((0..<1200).map { IntItem(($0 * $0) % 97) as any Item })
        interp.stacks[.exec] = Deque([InstructionItem(.iteratorPlay) as any Item])
        interp.enforceRunawayGuard()
        #expect(!interp.stacks[.exec]!.isEmpty)   // data gate fails
        #expect(errorMarkers(interp).isEmpty)
    }

    @Test func `a stack below the trigger is ignored even with a looper`() {
        let interp = loaded(intPile: 100, exec: [.iteratorPlay])   // 100 < trigger
        interp.enforceRunawayGuard()
        #expect(!interp.stacks[.exec]!.isEmpty)
        #expect(errorMarkers(interp).isEmpty)
    }

    @Test func `the guard can be disabled`() {
        let interp = loaded(intPile: 1200, exec: [.iteratorPlay])
        interp.config.runawayGuardEnabled = false
        interp.enforceRunawayGuard()
        #expect(!interp.stacks[.exec]!.isEmpty)
        #expect(errorMarkers(interp).isEmpty)
    }
}
