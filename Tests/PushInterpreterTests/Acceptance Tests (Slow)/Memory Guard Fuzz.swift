//
//  Memory Guard Fuzz.swift
//  PushInterpreterTests
//
//  Loop-heavy random programs at a high step limit, run serially against the
//  live-weight memory guard. Without the guard these are exactly the programs that
//  reached tens of GB; with it, a piling run stops at `MEMORY:` and peak RSS stays
//  flat. Seeded, so any offender reproduces. `stepLimit` is deliberately high (the
//  thing real algorithms need); `maxItemWeight`/`maxStackDepth` are only lowered
//  enough that a single step cannot spike faster than the guard checks.
//

@testable import PushInterpreter
import Testing
import Foundation
import Darwin

@Suite @MainActor
struct MemoryGuardFuzz {

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

    private func peakRSSGB() -> Double {
        var u = rusage(); getrusage(RUSAGE_SELF, &u); return Double(u.ru_maxrss) / 1_073_741_824
    }

    /// A random program biased heavily toward looping, with int counts and small
    /// code-block bodies so the loops have something to run.
    private func randomProgram(length: Int, all: [PushInstruction], loopers: [PushInstruction],
                               loopBias: Double, using rng: inout SeededRNG) -> [any Item] {
        var prog: [any Item] = []
        for _ in 0..<length {
            let r = Double.random(in: 0..<1, using: &rng)
            if r < loopBias {
                prog.append(InstructionItem(loopers.randomElement(using: &rng)!))
            } else if r < loopBias + 0.15 {
                prog.append(IntItem(Int.random(in: 0...60, using: &rng)))
            } else if r < loopBias + 0.30 {
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

    private func settings() -> InterpreterSettings {
        var s = InterpreterSettings()
        s.stepLimit = 3_000          // high: what loop-coordinating algorithms need
        s.maxItemWeight = 20_000     // bound a single step's spike (safety), still generous
        s.maxStackDepth = 5_000
        s.maxLiveWeight = 10_000_000 // the guard under test (~80 MB of content)
        return s
    }

    @Test func `loop-heavy fuzz stays bounded under the memory guard`() {
        let all = Runner().definedInstructions
        let loopers = Array(PushInstruction.iterators).sorted { $0.rawValue < $1.rawValue }
        let config = settings()

        var normal = 0, memory = 0, runaway = 0
        var firstMemorySeed: UInt64?
        let tranches: [UInt64] = [0x1234, 0xBEEF, 0xC0FFEE]
        let perTranche = 100

        for base in tranches {
            for k in 0..<perTranche {
                let seed = base &+ UInt64(k)
                var rng = SeededRNG(state: seed)
                let program = randomProgram(length: 220, all: all, loopers: loopers, loopBias: 0.40, using: &rng)

                let interp = Interpreter()
                interp.config = config
                interp.load(inputs: [:], constants: [:], program: program)
                interp.run()

                let errors = (interp.stacks[.error] ?? []).compactMap { ($0 as? ErrorItem)?.value }
                if errors.contains(where: { $0.hasPrefix(Interpreter.memoryMarker) }) {
                    memory += 1; if firstMemorySeed == nil { firstMemorySeed = seed }
                } else if errors.contains(where: { $0.hasPrefix(Interpreter.runawayMarker) }) {
                    runaway += 1
                } else {
                    normal += 1
                }
            }
        }

        let peak = peakRSSGB()
        let summary = """
        loop-heavy fuzz — \(tranches.count * perTranche) programs, stepLimit \(config.stepLimit), maxLiveWeight \(config.maxLiveWeight)
        normal: \(normal)   MEMORY-guard: \(memory)   RUNAWAY-guard: \(runaway)
        first MEMORY seed: \(firstMemorySeed.map { "0x\(String($0, radix: 16))" } ?? "none")
        peak RSS: \(String(format: "%.2f", peak)) GB
        """
        print(summary)
        try? summary.write(to: URL(fileURLWithPath: "/tmp/fuzz_mem.txt"), atomically: true, encoding: .utf8)

        // The point of the exercise: the interpreter stays bounded no matter what
        // these programs try to allocate.
        #expect(peak < 4.0, "the memory guard should keep the interpreter bounded")
    }
}
