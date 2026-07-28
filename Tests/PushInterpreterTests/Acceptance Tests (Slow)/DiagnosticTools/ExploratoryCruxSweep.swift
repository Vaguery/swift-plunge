//
//  ExploratoryCruxSweep.swift
//  PushInterpreterTests — DiagnosticTools
//
//  **Worked examples of the tools in this folder, and the starting point for an
//  exploratory session.**
//
//  Every test here is `.disabled` by default. They are instruments, not
//  assertions: they answer "is anything wrong, and where" rather than pinning a
//  behaviour, and a couple of them run for a minute. The suite's standing
//  assertions live in `Crux RoundTrip Tests.swift` and
//  `Composition Invariant Tests.swift`.
//
//  ## Running one
//
//  Flip `disabled` below and run the test **alone**:
//
//      swift test --filter ExploratoryCruxSweep
//
//  Alone is not a formality. `fuzzRNG` is a global and Swift Testing runs suites
//  in parallel, so another enabled test drawing from it consumes this sweep's
//  stream mid-generation and the run stops being reproducible. See the note in
//  `CruxSweep.swift`.
//
//  ## How to read a result
//
//  In order, because each question is cheap and rules out a lot:
//
//  1. **Are there inconclusives?** A reconstruction that ran out of steps checked
//     nothing. If that count is large the sweep is quieter than it looks, and
//     raising `stepScale` is the first move.
//  2. **Which categories moved?** Compare against the previous run. A category
//     that does not move under a change is one the change did not address.
//  3. **What are the root causes?** Not the tally by frequency — the *singletons*.
//     Both real bugs found this way had a count of 1 among 177,779 claims.
//

import DequeModule
import Foundation
import Testing
@testable import PushInterpreter


@Suite @MainActor
struct ExploratoryCruxSweep {

    // nonisolated so `.disabled(if:)` can read it from the @Test macro's Sendable
    // context under Swift 6 language mode.
    nonisolated static let disabled = true


    /// **The first thing to run.** A broad sweep, tallied by failure kind and by
    /// recording shape.
    ///
    /// Widen `spacedSeeds` before widening `casesPerSeed`: more worlds finds rare
    /// classes faster than more programs in the same world.
    @Test(.disabled(if: ExploratoryCruxSweep.disabled))
    func `broad sweep`() {
        let sweep = CruxSweep(seeds: CruxSweep.spacedSeeds(12), casesPerSeed: 20)
        let report = sweep.report()
        print("=== BROAD SWEEP (\(sweep.programCount) programs) ===")
        print(report.summary())
        fflush(stdout)
    }


    /// **The second thing to run**, once the first says something is wrong.
    ///
    /// Walks each failing item's call tree down to the nodes that actually broke,
    /// so a hundred poisoned ancestors collapse to the handful of instructions
    /// responsible. Slower than the broad sweep — it re-runs a crux per node — so
    /// it is pointed at fewer programs by default.
    @Test(.disabled(if: ExploratoryCruxSweep.disabled))
    func `root causes`() {
        let sweep = CruxSweep(seeds: CruxSweep.spacedSeeds(12), casesPerSeed: 20)
        let causes = rootCauses(in: sweep)
        print("=== ROOT CAUSES (\(sweep.programCount) programs) ===")
        print(causes.isEmpty ? "none — no failing claims to attribute"
                             : rootCauseSummary(causes))
        fflush(stdout)
    }


    /// **Hunt a suspected class on purpose** rather than waiting to stumble on it.
    ///
    /// `.enriched(_:)` concentrates one `InstructionRole` at a third of the draw.
    /// `.other` is the tag that computes — everything that is not a constant, an
    /// input, or stack furniture — so enriching it is the closest available lever
    /// for "more work per program, less shuffling".
    ///
    /// There is no `.iterator` tag, which is worth knowing when hunting the
    /// cycling-walker class that closed issue #27: an ordinary sweep produced
    /// exactly one example in 1,600 programs, and no mix here concentrates loops
    /// directly. Reaching that class reliably would want a mix keyed on
    /// `PushInstruction.iterators` — a genuine gap in the generator, not something
    /// this file can paper over.
    @Test(.disabled(if: ExploratoryCruxSweep.disabled))
    func `work-enriched sweep`() {
        let sweep = CruxSweep(
            seeds: CruxSweep.spacedSeeds(12),
            casesPerSeed: 20,
            mix: .enriched(.other))
        let report = sweep.report()
        print("=== WORK-ENRICHED SWEEP (\(sweep.programCount) programs) ===")
        print(report.summary())
        fflush(stdout)
    }


    /// **How quiet is the sweep really?**
    ///
    /// Counts claims whose reconstruction did not finish at several step budgets.
    /// Unfinished claims are not checked, and they do not appear as failures, so a
    /// sweep can report clean while judging much less than it seems to. Worth
    /// re-running whenever cruxes get longer — which is what loops do.
    @Test(.disabled(if: ExploratoryCruxSweep.disabled))
    func `how much is actually being checked`() {
        let sweep = CruxSweep(seeds: CruxSweep.spacedSeeds(6), casesPerSeed: 20)
        print("=== COVERAGE BY STEP BUDGET (\(sweep.programCount) programs) ===")
        for scale in [1, 5, 20, 100] {
            let report = sweep.report(stepScale: scale)
            print("  stepScale \(String(format: "%4d", scale)): "
                  + "\(report.judged) judged, \(report.broken) broken, "
                  + "\(report.inconclusive) inconclusive")
        }
        fflush(stdout)
    }
}
