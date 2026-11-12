//
//  Provenance Cost Benchmark.swift
//  PlungeTests
//
//  Runs the *same* seeded programs twice — once recording `call` provenance
//  (`recordsProvenance = true`, the default) and once with it stripped at push
//  (`false`) — and compares the two along three axes:
//
//    1. correctness — the value on every stack must be identical (the toggle may
//       never change what a program computes, only whether it can explain itself);
//    2. retained provenance — the summed `callWeight` of everything left live, a
//       *deterministic* memory proxy (unlike RSS, which is noisy and freed between
//       runs), plus `weight` (content) as a sanity check that only provenance differs;
//    3. wall-clock — the min total run time across repetitions per mode.
//
//  Seeded (splitmix), so the whole comparison reproduces exactly. Same generator as
//  `MemoryGuardFuzz`, biased toward loops + arithmetic so values genuinely accumulate
//  a call tree when recording is on.
//

@testable import Plunge
import Testing
import Foundation

@Suite
struct ProvenanceCostBenchmark {

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

    /// A random program biased toward looping over small arithmetic bodies, so a
    /// folded value builds a genuinely linear call history when recording is on.
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

    /// Two regimes. `.production` is the real default — the `maxCallWeight` elider
    /// bounds how much provenance on-mode can build.
    /// `.uncapped` lifts it (and raises `stepLimit`) so loops run deep and provenance
    /// is retained in full: the *true* cost of call retention, which this toggle sheds
    /// entirely. Both guards are content/count based, so they fire identically on and
    /// off — the two modes always compute the same values.
    enum Regime { case production, uncapped }

    private func settings(recordsProvenance: Bool, regime: Regime) -> InterpreterSettings {
        var s = InterpreterSettings()
        s.recordsProvenance = recordsProvenance
        switch regime {
        case .production:
            s.stepLimit = 1_500
        case .uncapped:
            s.stepLimit = 3_000
            s.maxCallWeight = .max      // do not elide provenance
        }
        return s
    }

    /// A value-only signature of the whole interpreter state — every stack's items by
    /// `pretty()` (which renders value/content, never `call`). Equal signatures mean
    /// the two runs computed the same thing.
    private func valueSignature(_ interpreter: Interpreter) -> String {
        PushStack.allStacks.map { stack in
            "\(stack):" + (interpreter.stacks[stack] ?? []).map { $0.pretty() }.joined(separator: ",")
        }.joined(separator: "|")
    }

    /// Deterministic memory metrics over the live stacks: summed `callWeight`
    /// (retained provenance, dominated by many shallow items), the *deepest* single
    /// item's `callWeight` (the tail the toggle really targets), and summed `weight`
    /// (content, a sanity check that only provenance differs).
    private func liveTotals(_ interpreter: Interpreter) -> (call: Int, maxCall: Int, content: Int) {
        var call = 0, maxCall = 0, content = 0
        for stack in PushStack.allStacks {
            for item in interpreter.stacks[stack] ?? [] {
                call += item.callWeight
                maxCall = max(maxCall, item.callWeight)
                content += item.weight
            }
        }
        return (call, maxCall, content)
    }

    private func run(_ program: [any Item], recordsProvenance: Bool, regime: Regime) -> Interpreter {
        let interpreter = Interpreter.recordingProvenance()
        interpreter.config = settings(recordsProvenance: recordsProvenance, regime: regime)
        interpreter.load(inputs: [:], constants: [:], program: program)
        interpreter.run()
        return interpreter
    }

    private func ms(_ d: Duration) -> Double {
        Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15
    }

    /// Total run time for one pass over `programs` in one mode.
    private func timePass(_ programs: [[any Item]], recordsProvenance: Bool, regime: Regime) -> Duration {
        let clock = ContinuousClock()
        var elapsed = Duration.zero
        for program in programs {
            let start = clock.now
            _ = run(program, recordsProvenance: recordsProvenance, regime: regime)
            elapsed += clock.now - start
        }
        return elapsed
    }

    /// A crafted deep-accumulation program: fold `1 .intAdd` `passes` times. Its top
    /// value carries a linear call history of length ~`passes` when recording is on —
    /// the shape the toggle exists to shed — and an empty call when off.
    private func accumulator(passes: Int) -> [any Item] {
        [IntItem(0), CodeItem([IntItem(1), InstructionItem(.intAdd)]), IntItem(passes),
         InstructionItem(.execDoTimes)]
    }

    @Test func `call retention on vs off — correctness, memory, and time`() {
        let all = Runner().definedInstructions
        let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }

        // Fixed, reproducible program set: seeded fuzz + a few deep accumulators (whose
        // provenance grows with the loop, so on-vs-off separates cleanly).
        let tranches: [UInt64] = [0x1234, 0xBEEF, 0xC0FFEE]
        let perTranche = 10
        var programs: [[any Item]] = []
        for base in tranches {
            for k in 0..<perTranche {
                var rng = SeededRNG(state: base &+ UInt64(k))
                programs.append(randomProgram(length: 120, all: all, loopers: loopers,
                                              loopBias: 0.28, using: &rng))
            }
        }
        for passes in [150, 400, 800] { programs.append(accumulator(passes: passes)) }

        // --- Correctness: value on every stack identical, in both regimes.
        var mismatches = 0
        for program in programs {
            for regime in [Regime.production, .uncapped] {
                let on = run(program, recordsProvenance: true, regime: regime)
                let off = run(program, recordsProvenance: false, regime: regime)
                if valueSignature(on) != valueSignature(off) { mismatches += 1 }
            }
        }

        // --- Retained provenance (deterministic), per regime: the summed callWeight
        // (dominated by shallow leftovers) and the *deepest* single item (the tail the
        // toggle targets — a folded accumulator, O(passes) on vs O(1) off).
        func retention(_ regime: Regime) -> (callOn: Int, callOff: Int, maxOn: Int, maxOff: Int, contentOn: Int, contentOff: Int) {
            var callOn = 0, callOff = 0, maxOn = 0, maxOff = 0, contentOn = 0, contentOff = 0
            for program in programs {
                let on = liveTotals(run(program, recordsProvenance: true, regime: regime))
                let off = liveTotals(run(program, recordsProvenance: false, regime: regime))
                callOn += on.call; callOff += off.call
                maxOn = max(maxOn, on.maxCall); maxOff = max(maxOff, off.maxCall)
                contentOn += on.content; contentOff += off.content
            }
            return (callOn, callOff, maxOn, maxOff, contentOn, contentOff)
        }
        let production = retention(.production)
        let uncapped = retention(.uncapped)

        // --- Wall-clock: min total over repetitions per mode isolates compute from
        // scheduling noise. Timed in the uncapped regime, where retention is not
        // pre-bounded, so any per-push provenance cost is visible if there is one.
        let repetitions = 2
        var timeOn = Duration.seconds(Int.max), timeOff = Duration.seconds(Int.max)
        for _ in 0..<repetitions {
            let on = timePass(programs, recordsProvenance: true, regime: .uncapped)
            let off = timePass(programs, recordsProvenance: false, regime: .uncapped)
            if on < timeOn { timeOn = on }
            if off < timeOff { timeOff = off }
        }

        let speedup = ms(timeOn) / max(ms(timeOff), 0.0001)
        let summary = """
        provenance cost — \(programs.count) programs (seeded fuzz + accumulators), \(repetitions) timing reps (min)
        correctness: \(programs.count * 2 - mismatches)/\(programs.count * 2) identical value signatures (both regimes)
        content (Σ weight): on \(uncapped.contentOn) == off \(uncapped.contentOff)  ⇒ only provenance differs, never a value
        retained provenance — Σ callWeight (all live items):
          production (defaults, elider):         on \(production.callOn)   off \(production.callOff)
          uncapped (elider lifted):              on \(uncapped.callOn)   off \(uncapped.callOff)
        retained provenance — deepest single item (the tail the toggle targets):
          production: on \(production.maxOn)   off \(production.maxOff)   (\(String(format: "%.0f", Double(production.maxOn) / Double(max(production.maxOff, 1))))× deeper on)
          uncapped:   on \(uncapped.maxOn)   off \(uncapped.maxOff)   (\(String(format: "%.0f", Double(uncapped.maxOn) / Double(max(uncapped.maxOff, 1))))× deeper on)
        run time (uncapped, min of \(repetitions)): on \(String(format: "%.1f", ms(timeOn))) ms   off \(String(format: "%.1f", ms(timeOff))) ms   → \(String(format: "%.2f", speedup))× with off
        """
        print(summary)
        try? summary.write(to: URL(fileURLWithPath: "/tmp/provenance_cost.txt"), atomically: true, encoding: .utf8)

        // Correctness is the hard contract: the toggle must never change a value.
        #expect(mismatches == 0, "recordsProvenance changed a computed value")
        // Content is unaffected; only provenance is dropped.
        #expect(uncapped.contentOn == uncapped.contentOff, "only provenance should differ between modes")
        // Off collapses the deep tail: the deepest item carries a full history on, one node off.
        #expect(uncapped.maxOff == 1)
        #expect(uncapped.maxOn > 100 * uncapped.maxOff, "a folded accumulator's history should be far deeper on than off")
    }
}
