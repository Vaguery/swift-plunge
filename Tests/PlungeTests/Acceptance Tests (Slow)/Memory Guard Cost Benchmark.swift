//
//  Memory Guard Cost Benchmark.swift
//  PlungeTests
//
//  The memory guard used to re-sum every stack every step (O(live items)/step →
//  quadratic on a program that builds and holds a deep stack) — profiling put it at
//  ~72% of interpreter time under the full language. It is now O(1): `liveWeight` is
//  maintained incrementally, so the guard is a single comparison. This pins that: on
//  a deliberately deep-stack, long-running program, enabling the guard must add only
//  a small, bounded overhead — a regression test that would fail loudly if the
//  per-step re-sum ever came back.
//

@testable import Plunge
import Testing
import Foundation

@Suite @MainActor
struct MemoryGuardCostBenchmark {

    /// A program that grows a deep `.int` stack and keeps stepping with it live:
    /// `intDupTimes` copies the top int `passes` times, one per pass, so `.int` deepens
    /// by one each pass. The late passes are steps taken with a deep stack present —
    /// exactly what made the old per-step re-sum quadratic (pass i paid O(i)).
    private func deepStackProgram(passes: Int) -> [any Item] {
        [IntItem(5), IntItem(passes), InstructionItem(.intDupTimes)]
    }

    private func settings(memoryGuard: Bool) -> InterpreterSettings {
        var s = InterpreterSettings()
        s.stepLimit = 20_000
        s.maxStackDepth = 100_000              // allow a deep stack
        s.maxLiveWeight = memoryGuard ? 1_000_000_000 : .max  // .max disables the guard
        return s
    }

    private func timeRun(_ program: [any Item], memoryGuard: Bool) -> Duration {
        let clock = ContinuousClock()
        let start = clock.now
        let interp = Interpreter()
        interp.config = settings(memoryGuard: memoryGuard)
        interp.load(program: program)
        interp.run()
        return clock.now - start
    }

    private func ms(_ d: Duration) -> Double { Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15 }

    @Test func `the memory guard adds only bounded per-step overhead`() {
        let program = deepStackProgram(passes: 4_000)   // ~4000-deep stack, ~8000 steps

        // Min of 3 per mode to cut scheduling noise.
        var on = Double.greatestFiniteMagnitude, off = Double.greatestFiniteMagnitude
        _ = timeRun(program, memoryGuard: true)         // warm up
        for _ in 0..<3 {
            on = Swift.min(on, ms(timeRun(program, memoryGuard: true)))
            off = Swift.min(off, ms(timeRun(program, memoryGuard: false)))
        }

        let overhead = (on - off) / off
        let summary = """
        memory-guard cost — deep-stack program (~4000 items), stepLimit 20000, min of 3
        guard ON: \(String(format: "%.1f", on)) ms   guard OFF: \(String(format: "%.1f", off)) ms
        overhead: \(String(format: "%+.0f%%", overhead * 100))  (O(1) guard ⇒ negligible; the old per-step re-sum profiled at ~72% of full-language interpreter time)
        """
        print(summary)
        try? summary.write(to: URL(fileURLWithPath: "/tmp/guard_cost.txt"), atomically: true, encoding: .utf8)

        // O(1): the guard is a single comparison per step. Generous bound (timing is
        // environment-dependent), but far below the old quadratic re-sum, which turned
        // a deep-stack run into multiples of its guard-off time.
        #expect(overhead < 1.0, "the memory guard should add well under 1× — the per-step re-sum is gone")
    }
}
