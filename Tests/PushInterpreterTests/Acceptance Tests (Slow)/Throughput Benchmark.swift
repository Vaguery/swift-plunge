//
//  Throughput Benchmark.swift
//  PushInterpreterTests
//
//  The baseline every performance change is measured against: how many interpreter
//  steps per second a fixed, seeded population of random programs runs at, under the
//  settings the PlungeGP search actually uses (stepLimit 1_000, the search's 256_000
//  live-weight cap, provenance off) and again with provenance on.
//
//  It only reports; it asserts nothing about speed, because wall-clock depends on the
//  machine and on the build configuration. Compare its printed line across commits,
//  and between `swift test` (debug, -Onone) and `swift test -c release`.
//
//  Run alone:  swift test [-c release] --filter ThroughputBenchmark
//

@testable import PushInterpreter
import Testing
import Foundation

@Suite @MainActor
struct ThroughputBenchmark {

    /// Same splitmix generator as the other seeded benchmarks, so runs reproduce exactly.
    struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            var mixed = state
            mixed = (mixed ^ (mixed >> 30)) &* 0xbf58476d1ce4e5b9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94d049bb133111eb
            return mixed ^ (mixed >> 31)
        }
    }

    /// A genome-sized random program: mostly instructions drawn from the whole defined
    /// language, with literals and small blocks mixed in, and a modest loop bias so
    /// control flow is present (as it is in the app's Numbers/Strings presets).
    private func randomProgram(length: Int, all: [PushInstruction], loopers: [PushInstruction],
                               using rng: inout SeededRNG) -> [any Item] {
        var program: [any Item] = []
        for _ in 0..<length {
            let roll = Double.random(in: 0..<1, using: &rng)
            if roll < 0.08 {
                program.append(InstructionItem(loopers.randomElement(using: &rng)!))
            } else if roll < 0.20 {
                program.append(IntItem(Int.random(in: -10...40, using: &rng)))
            } else if roll < 0.26 {
                program.append(DoubleItem(Double.random(in: -10...10, using: &rng)))
            } else if roll < 0.30 {
                program.append(StringItem(String(repeating: "ab ", count: Int.random(in: 1...4, using: &rng))))
            } else if roll < 0.40 {
                let body = (0..<Int.random(in: 1...4, using: &rng)).map { _ in
                    InstructionItem(all.randomElement(using: &rng)!) as any Item
                }
                program.append(CodeItem(body))
            } else {
                program.append(InstructionItem(all.randomElement(using: &rng)!))
            }
        }
        return program
    }

    /// The settings `Experiment.settings` hands the search in PlungeGP.
    private func searchSettings(recordsProvenance: Bool) -> InterpreterSettings {
        var settings = InterpreterSettings()
        settings.stepLimit = 1_000
        settings.maxLiveWeight = 256_000
        settings.recordsProvenance = recordsProvenance
        return settings
    }

    /// Runs every program once; returns the total steps taken and the elapsed time.
    private func pass(_ programs: [[any Item]], settings: InterpreterSettings) -> (steps: Int, elapsed: Duration) {
        let clock = ContinuousClock()
        var steps = 0
        let start = clock.now
        for program in programs {
            let interpreter = Interpreter()
            interpreter.config = settings
            interpreter.load(program: program)
            interpreter.run()
            steps += interpreter.counter
        }
        return (steps, clock.now - start)
    }

    private func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    /// The fixed, seeded program set every measurement here runs.
    private func benchmarkPrograms() -> [[any Item]] {
        let all = Runner().definedInstructions
        let loopers = Array(PushInstruction.iterators).sorted { $0.rawValue < $1.rawValue }
        var programs: [[any Item]] = []
        for seed in 0..<200 {
            var rng = SeededRNG(state: 0x5EED_0000 &+ UInt64(seed))
            programs.append(randomProgram(length: 150, all: all, loopers: loopers, using: &rng))
        }
        return programs
    }

    /// Seconds to keep the profiling loop busy, from `PUSH_PROFILE_SECONDS`; nil skips it.
    nonisolated static let profileSeconds: Double? =
        ProcessInfo.processInfo.environment["PUSH_PROFILE_SECONDS"].flatMap(Double.init)

    /// A target for a sampling profiler (`sample`, Instruments): runs the benchmark
    /// programs under search settings, over and over, for `PUSH_PROFILE_SECONDS`.
    /// Skipped unless that variable is set.
    ///
    ///     PUSH_PROFILE_SECONDS=20 swift test -c release --filter ThroughputBenchmark
    @Test(.enabled(if: ThroughputBenchmark.profileSeconds != nil))
    func `profiling loop`() {
        let programs = benchmarkPrograms()
        let settings = searchSettings(recordsProvenance: false)
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(ThroughputBenchmark.profileSeconds ?? 0)
        var steps = 0
        while clock.now < deadline { steps += pass(programs, settings: settings).steps }
        #expect(steps > 0)
    }

    @Test func `steps per second under search settings`() {
        let programs = benchmarkPrograms()

        // Warm up (builds the shared language table, faults in code pages).
        _ = pass(Array(programs.prefix(20)), settings: searchSettings(recordsProvenance: false))

        // Best of three per mode, to strip scheduling noise.
        func best(_ settings: InterpreterSettings) -> (steps: Int, seconds: Double) {
            var result = (steps: 0, seconds: Double.infinity)
            for _ in 0..<3 {
                let run = pass(programs, settings: settings)
                let elapsed = seconds(run.elapsed)
                if elapsed < result.seconds { result = (run.steps, elapsed) }
            }
            return result
        }
        let lean = best(searchSettings(recordsProvenance: false))
        let recorded = best(searchSettings(recordsProvenance: true))

        func line(_ label: String, _ timing: (steps: Int, seconds: Double)) -> String {
            let nsPerStep = timing.seconds * 1e9 / Double(max(timing.steps, 1))
            let stepsPerSecond = Double(timing.steps) / max(timing.seconds, 1e-9)
            let elapsed = timing.seconds.formatted(.number.precision(.fractionLength(3)))
            return "\(label): \(timing.steps) steps in \(elapsed) s"
                + " = \(nsPerStep.formatted(.number.precision(.fractionLength(0)))) ns/step"
                + ", \((stepsPerSecond / 1e6).formatted(.number.precision(.fractionLength(2)))) M steps/s"
        }

        #if DEBUG
        let build = "debug"
        #else
        let build = "release"
        #endif
        print("""
        === throughput (\(build) build, \(programs.count) programs × 150 tokens, best of 3) ===
        \(line("provenance off (search)", lean))
        \(line("provenance on          ", recorded))
        """)

        // Same programs, same step counts: provenance never changes what runs.
        #expect(lean.steps == recorded.steps)
        #expect(lean.steps > 0)
    }
}
