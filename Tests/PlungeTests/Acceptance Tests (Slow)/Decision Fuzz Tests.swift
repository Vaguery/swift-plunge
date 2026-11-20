//
//  Decision Fuzz Tests.swift
//  PlungeTests
//
//  The decision log, counterfactual runs, rolling by index and full size on
//  random programs under the dual-mode stress test's regimes (2026-11-20).
//  `PUSH_DECISION_FUZZ` sets how many programs (default 60); `PUSH_FUZZ_SEED`
//  shifts their seeds.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct DecisionFuzzTests {

    static let programs = ProcessInfo.processInfo.environment["PUSH_DECISION_FUZZ"].flatMap(Int.init) ?? 60

    /// `c` run with provenance on, its step limit held to 20,000; with the
    /// decision log when `logging`, and the given decisions flipped or forced.
    static func run(_ c: DualModeStress.Case, logging: Bool, flipping: Set<Int>? = nil,
                    forcing: [Int: Int]? = nil) -> (Interpreter, Double) {
        let inty = Interpreter()
        inty.config = c.settings
        inty.config.stepLimit = min(c.settings.stepLimit, 20_000)
        inty.config.recordsProvenance = true
        inty.config.flippedDecisions = flipping
        inty.config.forcedChoices = forcing
        if logging { inty.addRecorder(RecorderSpec("decided", observing: .decisions)) }
        inty.load(inputs: c.inputs, constants: c.constants, program: c.program)
        let clock = ContinuousClock()
        let start = clock.now
        inty.run()
        return (inty, seconds(clock.now - start))
    }

    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    /// The value `crux` leaves on `stack`, replayed with `c`'s inputs and
    /// constants; nil when it leaves none.
    static func replay(_ crux: [any Item], on stack: PushStack, _ c: DualModeStress.Case) -> String? {
        let inty = Interpreter()
        inty.config = c.settings.reconstructing
        inty.config.recordsProvenance = false
        inty.config.stepLimit = max(1_000, CruxCompression.replaySteps(crux) * 2 + crux.count)
        inty.load(inputs: c.inputs, constants: c.constants, program: crux)
        inty.run()
        return inty.stacks[stack]?.first?.pretty()
    }

    struct Tally {
        var programs = 0, decisions = 0, mostDecisions = 0, selections = 0, counts = 0
        var plain = 0.0, logged = 0.0, slowestRatio = (ratio: 0.0, seed: UInt64(0))
        var forcedRuns = 0, forcedTaken = 0
        var cruxes = 0, rolled = 0, rollInconclusive = 0, rollTime = 0.0, slowestRoll = 0.0
        var fullSizeTime = 0.0, largestFullSize = 0
        var findings: [String] = []
    }

    static func report(_ tally: Tally) {
        func format(_ value: Double, _ places: Int) -> String { String(format: "%.\(places)f", value) }
        print("""
            DECISION FUZZ (shift \(FuzzSeed.shift)): \(tally.programs) programs, \(tally.decisions) decisions \
            (\(tally.selections) selections, \(tally.counts) counts; at most \(tally.mostDecisions) in a run)
              time plain \(format(tally.plain, 2)) s, with the log \(format(tally.logged, 2)) s; \
            slowest ratio \(format(tally.slowestRatio.ratio, 1))× (seed \(tally.slowestRatio.seed))
              counterfactual runs \(tally.forcedRuns), decisions taken otherwise \(tally.forcedTaken)
              cruxes \(tally.cruxes), rolled shorter \(tally.rolled) (\(tally.rollInconclusive) not replayable), \
            rolling \(format(tally.rollTime, 3)) s (slowest \(format(tally.slowestRoll, 3)) s), \
            full size \(format(tally.fullSizeTime, 3)) s (largest \(tally.largestFullSize))
            """)
        for finding in tally.findings.prefix(20) { print("  FINDING \(finding)") }
    }

    /// A counterfactual run at each of the first three places: a conditional
    /// flipped, a count made one pass longer, a selection's last option taken.
    static func counterfactuals(_ c: DualModeStress.Case, log: [Decision], into tally: inout Tally) {
        var flips = Set<Int>()
        var forced: [Int: Int] = [:]
        for (place, decision) in log.prefix(3).enumerated() {
            if decision.naming == .count {
                forced[place] = min((decision.chosen ?? 0) + 1, 200)
            } else if let options = decision.options {
                forced[place] = options.count - 1
            } else {
                flips.insert(place)
            }
        }
        guard !flips.isEmpty || !forced.isEmpty else { return }
        let (changed, _) = run(c, logging: true, flipping: flips, forcing: forced)
        tally.forcedRuns += 1
        tally.forcedTaken += (changed.decisionLog ?? []).prefix(3).count(where: \.flipped)
    }

    /// Every top item's crux, rolled by index, must replay as the crux does; and
    /// its full size must come out.
    static func rolling(_ logged: Interpreter, _ c: DualModeStress.Case, seed: UInt64, into tally: inout Tally) {
        for stack in PushStack.allStacks where stack != .exec {
            guard let top = logged.stacks[stack]?.first, !top.call.isEmpty, top.callWeight <= 4_000 else { continue }
            let crux = top.crux()
            guard crux.count <= CruxCompression.rollingLimit else { continue }
            tally.cruxes += 1
            let clock = ContinuousClock()
            var start = clock.now
            let size = top.fullSize
            tally.fullSizeTime += seconds(clock.now - start)
            tally.largestFullSize = max(tally.largestFullSize, size)
            if size < 1 { tally.findings.append("seed \(seed) .\(stack): full size \(size)") }
            start = clock.now
            let rolled = CruxCompression.rolledByIndex(crux)
            let rollTime = seconds(clock.now - start)
            tally.rollTime += rollTime
            tally.slowestRoll = max(tally.slowestRoll, rollTime)
            guard rolled.count < crux.count else { continue }
            tally.rolled += 1
            let expected = replay(crux, on: stack, c)
            guard expected == top.pretty() else {
                tally.rollInconclusive += 1
                continue
            }
            if replay(rolled, on: stack, c) != expected {
                tally.findings.append("seed \(seed) .\(stack): the rolled crux replays otherwise: "
                                      + CodeItem(rolled).pretty().prefix(200))
            }
        }
    }

    @Test func `watching, flipping and forcing decisions, rolling and full size hold on random programs`() {
        let instructions = Runner().definedInstructions
        let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }
        var tally = Tally()
        for seed in (1...UInt64(Self.programs)).map({ $0 &+ 900_000 &+ FuzzSeed.shift }) {
            let c = DualModeStress.makeCase(seed: seed, instructions: instructions, loopers: loopers)
            tally.programs += 1
            let (plain, plainTime) = Self.run(c, logging: false)
            let (logged, loggedTime) = Self.run(c, logging: true)
            tally.plain += plainTime
            tally.logged += loggedTime
            let ratio = loggedTime / max(plainTime, 1e-4)
            if ratio > tally.slowestRatio.ratio, loggedTime > 0.01 { tally.slowestRatio = (ratio, seed) }
            // Watching decisions must change nothing the run computes.
            if DualModeStress.signatureHash(plain).hash != DualModeStress.signatureHash(logged).hash {
                tally.findings.append("seed \(seed) (\(c.regime)): the decision log changed the run")
            }
            let log = logged.decisionLog ?? []
            tally.decisions += log.count
            tally.mostDecisions = max(tally.mostDecisions, log.count)
            tally.selections += log.count { $0.isSelection && $0.naming != .count }
            tally.counts += log.count { $0.naming == .count }

            Self.counterfactuals(c, log: log, into: &tally)
            Self.rolling(logged, c, seed: seed, into: &tally)
        }
        Self.report(tally)
        #expect(tally.findings.isEmpty, "\(tally.findings.count) findings")
    }
}
