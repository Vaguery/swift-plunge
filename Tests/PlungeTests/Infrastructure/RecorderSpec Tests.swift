//
//  RecorderSpec Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 7/13/26.
//

import DequeModule
@testable import Plunge
import Testing

@Suite
struct RecorderSpecTests {

    let inty = Interpreter()

    @Test func `spec stores its name and target`() {
        let spec = RecorderSpec("topInt", observing: .top(.int))
        #expect(spec.name == "topInt")
        #expect(spec.target == .top(.int))
    }

    @Test func `addRecorder installs a recorder keyed by name`() {
        inty.addRecorder(RecorderSpec("topInt", observing: .top(.int)))
        #expect(inty.recorderNames == ["topInt"])
    }

    @Test func `addRecorders installs several at once`() {
        inty.addRecorders([
            RecorderSpec("topInt", observing: .top(.int)),
            RecorderSpec("errCount", observing: .count(.error))
        ])
        #expect(inty.recorderNames == ["errCount", "topInt"])
    }

    // A `.top` spec collects the item itself (retaining provenance), so the
    // recorded trace is a sequence of `any Item?`; unwrap to compare values.
    @Test func `top spec records the top item each step`() {
        inty.addRecorder(RecorderSpec("topInt", observing: .top(.int)))
        inty.load(inputs: [.input0: IntItem(4), .input1: IntItem(-11)],
                  stacks: [.int: [IntItem(1), IntItem(2), IntItem(3)]],
                  program: [
                    InstructionItem(.input0),
                    InstructionItem(.input1),
                    InstructionItem(.intAdd),
                    InstructionItem(.intSwap)
                  ])
        inty.run(stepLimit: 100)

        let values = inty.recordedData("topInt")!.map { ($0 as? IntItem)?.value }
        #expect(values == [1, 4, 4, -11, -7, 1])
    }

    // A `.count` spec records a scalar `Int` directly. `record()` runs once per
    // step, *after* the step's action, so the first step (pushing a bool, which
    // leaves `.int` untouched) captures depth 2, and the second (the add)
    // captures depth 1.
    @Test func `count spec records stack depth each step`() {
        inty.addRecorder(RecorderSpec("intCount", observing: .count(.int)))
        inty.load(stacks: [.int: [IntItem(1), IntItem(2)]],
                  program: [BoolItem(true), InstructionItem(.intAdd)])
        inty.run(stepLimit: 100)

        #expect(inty.recordedData("intCount") as! [Int?] == [2, 1])
    }

    // The `.stack` spec observes a whole stack each step, top first; on `.print`
    // that is everything printed so far. The first step pushes a bool (nothing
    // printed), so the first reading is empty; the second step prints the 7.
    @Test func `stack spec records the printed items each step`() {
        inty.addRecorder(RecorderSpec("out", observing: .stack(.print)))
        inty.load(stacks: [.int: [IntItem(7)]],
                  program: [BoolItem(true), InstructionItem(.intPrint)])
        inty.run(stepLimit: 100)

        let trace = inty.recordedData("out") as! [[any Item]?]
        #expect(trace.first??.isEmpty == true)
        #expect(trace.last??.map { $0.pretty() } == ["7"])
    }

    @Test func `recordedData is nil for an unknown recorder`() {
        #expect(inty.recordedData("nope") == nil)
    }
}
