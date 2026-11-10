//
//  Final Only Recorder Tests.swift
//  PlungeTests
//
//  `run` takes a `.finalOnly` recorder's one reading at the end of the run instead
//  of after every step. These hold it to what recording after every step gave: the
//  last reading of an `.everyStep` recorder on the same target, and no reading at all
//  for a run that took no step.
//

@testable import Plunge
import Testing

struct FinalOnlyRecorderTests {

    private func interpreter(program: [any Item], stepLimit: Int = 1_000) -> Interpreter {
        let interpreter = Interpreter()
        interpreter.config.stepLimit = stepLimit
        interpreter.load(program: program, recorders: [
            AnyRecorder(RecorderSpec("every", observing: .top(.int), keeping: .everyStep)),
            AnyRecorder(RecorderSpec("final", observing: .top(.int), keeping: .finalOnly)),
            AnyRecorder(RecorderSpec("steps", observing: .counter, keeping: .finalOnly))
        ])
        return interpreter
    }

    private func pretty(_ data: [Any?]?) -> [String] {
        (data ?? []).map { ($0 as? any Item)?.pretty() ?? "\(String(describing: $0))" }
    }

    @Test(arguments: [1_000, 3])
    func `the final reading is the last per-step reading`(stepLimit: Int) {
        let program: [any Item] = [IntItem(2), IntItem(3), InstructionItem(.intAdd),
                                   IntItem(7), InstructionItem(.intMultiply), InstructionItem(.intDup)]
        let run = interpreter(program: program, stepLimit: stepLimit)
        run.run()
        let every = pretty(run.recordedData("every"))
        #expect(every.count == run.counter)
        #expect(pretty(run.recordedData("final")) == [every.last!])
        #expect(run.recordedData("steps")?.first as? Int == run.counter)
    }

    @Test func `a run that takes no step records nothing`() {
        let run = interpreter(program: [])
        run.run()
        #expect(run.counter == 0)
        #expect(run.recordedData("final")?.isEmpty == true)
    }

    @Test func `stepping directly still records every recorder`() {
        let run = interpreter(program: [IntItem(4), IntItem(5)])
        run.step()
        #expect(pretty(run.recordedData("final")) == ["4"])
        run.step()
        #expect(pretty(run.recordedData("final")) == ["5"])
    }
}
