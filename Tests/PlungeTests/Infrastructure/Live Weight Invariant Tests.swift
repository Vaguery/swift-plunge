//
//  Live Weight Invariant Tests.swift
//  PlungeTests
//
//  `liveWeight` is maintained incrementally by the stack-mutation helpers so the
//  memory guard is O(1) per step. Correctness rests on one invariant: the running
//  total must always equal a full recompute. This checks it after **every step** of
//  many seeded full-language programs — if any mutation path fails to account its
//  delta, the incremental total drifts and this catches it, reproducibly.
//

@testable import Plunge
import Testing
import Foundation

@Suite @MainActor
struct LiveWeightInvariantTests {

    struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
            z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }
    }

    private func randomProgram(length: Int, all: [PushInstruction], loopers: [PushInstruction],
                               loopBias: Double, using rng: inout SeededRNG) -> [any Item] {
        var prog: [any Item] = []
        for _ in 0..<length {
            let r = Double.random(in: 0..<1, using: &rng)
            if r < loopBias {
                prog.append(InstructionItem(loopers.randomElement(using: &rng)!))
            } else if r < loopBias + 0.20 {
                prog.append(IntItem(Int.random(in: 0...40, using: &rng)))
            } else if r < loopBias + 0.35 {
                let body = (0..<Int.random(in: 1...4, using: &rng)).map { _ in
                    InstructionItem(all.randomElement(using: &rng)!) as any Item
                }
                prog.append(CodeItem(body))
            } else {
                prog.append(InstructionItem(all.randomElement(using: &rng)!))
            }
        }
        return prog
    }

    /// Independent full sum of `Item.weight` across all stacks — the ground truth the
    /// incremental `liveWeight` must match.
    private func fullRecompute(_ interp: Interpreter) -> Int {
        var total = 0
        for stack in PushStack.allStacks {
            for item in interp.stacks[stack] ?? [] { total &+= item.weight }
        }
        return total
    }

    /// Run with provenance recording off (the default, what a search runs) and on:
    /// the weights involved are content-only, so the invariant must hold either way.
    @Test(arguments: [false, true])
    func `liveWeight equals a full recompute after every step`(recordsProvenance: Bool) {
        let all = Runner().definedInstructions
        let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }
        var settings = InterpreterSettings()
        settings.stepLimit = 2_000
        settings.recordsProvenance = recordsProvenance

        let tranches: [UInt64] = [0x1234, 0xBEEF, 0xC0FFEE, 0xD00D]
        let perTranche = 25
        var checkedSteps = 0
        var firstFailure: String?

        outer: for base in tranches {
            for k in 0..<perTranche {
                var rng = SeededRNG(state: base &+ UInt64(k))
                let program = randomProgram(length: 140, all: all, loopers: loopers, loopBias: 0.30, using: &rng)

                let interp = Interpreter()
                interp.config = settings
                interp.load(program: program)             // anchors liveWeight
                #expect(interp.liveWeight == fullRecompute(interp))

                // Step manually so we can check the invariant after each mutation.
                var step = 0
                while interp.counter < settings.stepLimit && !(interp.stacks[.exec]?.isEmpty ?? true) {
                    interp.step()
                    checkedSteps += 1
                    step += 1
                    if interp.liveWeight != fullRecompute(interp) {
                        firstFailure = "seed 0x\(String(base &+ UInt64(k), radix: 16)) step \(step): liveWeight \(interp.liveWeight) != recompute \(fullRecompute(interp))"
                        break outer
                    }
                }
            }
        }

        let summary = """
        live-weight invariant — \(tranches.count * perTranche) programs, \(checkedSteps) steps checked
        \(firstFailure ?? "invariant held after every step")
        """
        print(summary)
        try? summary.write(to: URL(fileURLWithPath: "/tmp/liveweight_invariant.txt"), atomically: true, encoding: .utf8)

        #expect(firstFailure == nil, firstFailure.map { Comment(rawValue: $0) } ?? "")
    }

    @Test func `reset zeroes the total; load re-anchors it`() {
        let interp = Interpreter()
        interp.config = InterpreterSettings()
        interp.load(program: [IntItem(1), IntItem(2), InstructionItem(.intAdd)])
        #expect(interp.liveWeight == fullRecompute(interp))
        interp.reset()
        #expect(interp.liveWeight == 0)
    }
}
