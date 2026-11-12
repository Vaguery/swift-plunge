//
//  Step Limit Census.swift
//  PlungeTests
//
//  What raising the default `stepLimit` would change: the probe's random
//  programs run under several limits, counting how many reach each limit, how
//  long they take, whether an iterator was mid-walk when the limit stopped
//  them, and how often the size limits refused something along the way.
//
//      PUSH_FUNCTION_PROBE=1 swift test --filter StepLimitCensus
//

import Foundation
import Testing
@testable import Plunge

@Suite
struct StepLimitCensus {

    typealias Probe = FunctionOutcome

    static let limits = [1_000, 10_000, 100_000]

    struct Tally {
        var programs = 0, stopped = 0, midWalk = 0, steps = 0
        var time = Duration.zero
        var refusals: [String: Int] = [:]
        var stepsOfStopped: [Int] = []
        /// With provenance recorded: the longest crux among the final stack
        /// tops, per program, and programs with an elided history among them.
        var longest: [Int] = []
        var elided = 0
    }

    static func census(_ regime: Probe.Regime, programs: Int, limit: Int, recording: Bool = false) -> Tally {
        var t = Tally()
        let clock = ContinuousClock()
        for seed in 0..<programs {
            let drawn = withFuzzSeed(UInt64(seed)) { Probe.draw(regime) }
            let inty = Interpreter()
            inty.config.stepLimit = limit
            inty.config.recordsProvenance = recording
            inty.load(inputs: drawn.inputs, constants: drawn.constants, program: drawn.program)
            t.time += clock.measure { inty.run() }
            t.programs += 1
            if recording { measureCruxes(inty, into: &t) }
            t.steps += inty.counter
            if !inty.stacks[.exec]!.isEmpty {
                t.stopped += 1
                if !inty.stacks[.iterator]!.isEmpty { t.midWalk += 1 }
            }
            let watched: Set<ErrorKind> = [.sizeRefusal, .guardStop]
            for case let error as ErrorItem in inty.stacks[.error]! where watched.contains(error.kind) {
                let what = error.value.contains("maxStackDepth") ? "stack depth"
                    : error.kind == .guardStop ? "guard stop" : "item size"
                t.refusals[what, default: 0] += 1
            }
        }
        return t
    }

    static func measureCruxes(_ inty: Interpreter, into t: inout Tally) {
        var longest = 0, elided = false
        for stack in BlockFunctionCensus.valueStacks {
            guard let top = inty.stacks[stack]?.first else { continue }
            guard let body = CruxSharing.crux(of: top, limit: 1_000_000) else { longest = 1_000_000; continue }
            longest = max(longest, body.count)
            if body.contains(where: { ($0 as? StandInItem)?.reason == .elided }) { elided = true }
        }
        t.longest.append(longest)
        t.elided += elided ? 1 : 0
    }

    @Test(.enabled(if: FunctionOutcomeProbe.enabled))
    func `what a higher step limit changes`() throws {
        let programs = Int(ProcessInfo.processInfo.environment["PUSH_FUNCTION_PROBE_PROGRAMS"] ?? "") ?? 300
        let percent = FunctionOutcomeProbe.percent
        var text = "# Step limit census\n\n\(programs) programs per regime.\n"
        for regime in Probe.Regime.allCases {
            text += "\n## \(regime.rawValue)\n\n| limit | stopped by it | of those, mid-walk | mean steps "
            text += "| time | size and guard refusals |\n|---:|---:|---:|---:|---:|---|\n"
            for limit in Self.limits {
                let t = Self.census(regime, programs: programs, limit: limit)
                let refusals = t.refusals.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
                    .joined(separator: ", ")
                let cells = ["\(limit)", "\(t.stopped) (\(percent(t.stopped, t.programs)))", "\(t.midWalk)",
                             BlockFunctionCensus.mean(t.steps, t.programs),
                             t.time.formatted(.units(allowed: [.seconds, .milliseconds], width: .narrow)),
                             refusals.isEmpty ? "none" : refusals]
                text += "| " + cells.joined(separator: " | ") + " |\n"
            }
        }
        text += "\n## With provenance recorded (as the Runner runs)\n\n| regime | limit | time | median longest crux "
        text += "| 90th pct | max | programs with elided history |\n|---|---:|---:|---:|---:|---:|---:|\n"
        for regime in Probe.Regime.allCases {
            for limit in Self.limits.prefix(2) {
                let t = Self.census(regime, programs: programs, limit: limit, recording: true)
                let sorted = t.longest.sorted()
                let cells = [regime.rawValue, "\(limit)",
                             t.time.formatted(.units(allowed: [.seconds, .milliseconds], width: .narrow)),
                             "\(sorted[sorted.count / 2])", "\(sorted[sorted.count * 9 / 10])", "\(sorted.last!)",
                             "\(t.elided) (\(percent(t.elided, t.programs)))"]
                text += "| " + cells.joined(separator: " | ") + " |\n"
            }
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "step-limit-census.md")
        try text.write(to: url, atomically: true, encoding: .utf8)
        print(text)
    }
}
