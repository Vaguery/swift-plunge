//
//  Provenance Toggle Tests.swift
//  PlungeTests
//
//  With `recordsProvenance` off (the default) no Behavior builds a `call`, so the
//  deep call tree never exists. This must save memory without changing any value a
//  program computes, and without breaking loops (whose iteration is state-driven,
//  not call-driven). Turned on, the whole existing crux system is untouched —
//  covered by the round-trip sweep elsewhere, and language-wide by
//  `Provenance Off Parity Tests`.
//

@testable import Plunge
import Testing

@Suite
struct ProvenanceToggleTests {

    private func run(_ program: [any Item], recordsProvenance: Bool,
                     inputs: [PushInstruction: any Item] = [:]) -> Interpreter {
        let interpreter = Interpreter()
        var config = InterpreterSettings()
        config.recordsProvenance = recordsProvenance
        interpreter.config = config
        interpreter.load(inputs: inputs, constants: [:], program: program)
        interpreter.run()
        return interpreter
    }

    @Test func `off leaves every pushed item's call empty and its crux trivial`() {
        // 5 3 .intAdd  →  8, whose provenance when ON is ( 5 3 .intAdd ).
        let program: [any Item] = [IntItem(5), IntItem(3), InstructionItem(.intAdd)]
        let interpreter = run(program, recordsProvenance: false)

        let top = interpreter.stacks[.int]?.first
        #expect((top as? IntItem)?.value == 8)
        #expect(top?.call.isEmpty == true, "call should be stripped")
        // crux of a call-less item is [self]: a single literal reproducing the value.
        #expect(top?.crux().count == 1)
        #expect((top?.crux().first as? IntItem)?.value == 8)
    }

    @Test func `on records the call as usual`() {
        let program: [any Item] = [IntItem(5), IntItem(3), InstructionItem(.intAdd)]
        let interpreter = run(program, recordsProvenance: true)
        let top = interpreter.stacks[.int]?.first
        #expect((top as? IntItem)?.value == 8)
        #expect(top?.call.isEmpty == false, "call should be recorded when on")
    }

    @Test func `the computed value is identical on and off`() {
        let program: [any Item] = [
            IntItem(5), IntItem(3), InstructionItem(.intAdd),
            IntItem(2), InstructionItem(.intMultiply)   // (5+3)*2 = 16
        ]
        let on = run(program, recordsProvenance: true).stacks[.int]?.first as? IntItem
        let off = run(program, recordsProvenance: false).stacks[.int]?.first as? IntItem
        #expect(on?.value == 16)
        #expect(off?.value == 16)
    }

    @Test func `a loop runs correctly with provenance off`() {
        // Accumulate 1 five times: 0, then ( 1 .intAdd ) × 5 via execDoTimes → 5.
        let body = CodeItem([IntItem(1), InstructionItem(.intAdd)])
        let program: [any Item] = [IntItem(0), body, IntItem(5), InstructionItem(.execDoTimes)]
        let interpreter = run(program, recordsProvenance: false)
        #expect((interpreter.stacks[.int]?.first as? IntItem)?.value == 5,
                "iteration is state-driven, so stripping call must not change the result")
    }

    @Test func `a deep accumulation stays call-light with provenance off`() {
        // A genuinely linear history: fold `1 .intAdd` many times. With provenance ON
        // the top item's call tree grows with the loop; OFF it is empty regardless.
        let body = CodeItem([IntItem(1), InstructionItem(.intAdd)])
        let program: [any Item] = [IntItem(0), body, IntItem(60), InstructionItem(.execDoTimes)]

        let onTop = run(program, recordsProvenance: true).stacks[.int]?.first
        let offTop = run(program, recordsProvenance: false).stacks[.int]?.first

        #expect((onTop as? IntItem)?.value == (offTop as? IntItem)?.value)   // same value
        #expect(offTop?.call.isEmpty == true)
        // callWeight measures provenance (content is `weight`): off keeps only itself,
        // on accumulates the loop's linear history.
        #expect(offTop!.callWeight == 1)
        #expect(offTop!.callWeight < onTop!.callWeight, "off must carry less provenance than accumulated-call on")
    }

    @Test func `requiresProvenance passes when on, warns and refuses when off`() {
        let on = Interpreter()
        on.config = { var c = InterpreterSettings(); c.recordsProvenance = true; return c }()
        #expect(on.requiresProvenance(.intAdd) == true)
        #expect((on.stacks[.error] ?? []).isEmpty)

        let off = Interpreter()
        off.config = { var c = InterpreterSettings(); c.recordsProvenance = false; return c }()
        #expect(off.requiresProvenance(.intAdd) == false)
        let errors = (off.stacks[.error] ?? []).compactMap { ($0 as? ErrorItem)?.value }
        #expect(errors.contains { $0.hasPrefix(Interpreter.provenanceMarker) })
    }
}
