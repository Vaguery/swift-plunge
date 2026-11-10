//
//  CruxSweep.swift
//  PushInterpreterTests — DiagnosticTools
//
//  **Generate a corpus of random programs, run them, and hand back every item
//  that makes a claim worth checking.**
//
//  The boilerplate this replaces is about fifteen lines, and every exploratory
//  session so far has rewritten it slightly differently — which matters more than
//  the typing, because the parameters that differ between two sweeps are exactly
//  the ones you need to state when reporting what you found.
//
//  ## Sweep several seeds
//
//  The default is eight seeds rather than one, because **one seed cannot see a
//  rare class.** Issue #27 ran about 1 failure per 1,900 claims: the single-seed
//  `CruxFuzzTests` reported zero on seed 20_260_715 while a 40-seed sweep found
//  95. If a sweep reports clean, the first question is whether it looked at enough
//  different worlds, and `spacedSeeds` exists so that answer is one number.
//
//  ## The RNG is global, and that is load-bearing
//
//  `fuzzRNG` is a `nonisolated(unsafe)` global. Swift Testing runs suites in
//  parallel, so **any other enabled test drawing from it consumes this sweep's
//  stream mid-generation** and the run stops being reproducible. Diagnostic runs
//  should be `.disabled` by default and invoked alone with `--filter`, exactly as
//  `CruxFuzzTests` documents. A sweep that will not reproduce is worth very little
//  when the thing you are chasing is 1 in 1,900.
//

import DequeModule
import Foundation
@testable import PushInterpreter


/// One item a swept program left behind, with everything needed to interrogate it
/// or to write it out as a replayable case.
///
/// `inputs` and `constants` are captured per program: a crux naming `.input3` or
/// `.vecDouble8` only reproduces against the bindings it was recorded under, so
/// they travel with the item rather than being re-derived later.
@MainActor
struct SweptItem {
    var item: any Item
    /// The stack it was found resting on. Usually — but not necessarily — equal to
    /// `PushStack.defaultStack(for: item)`; a mismatch is itself interesting.
    var foundOn: PushStack
    var inputs: [PushInstruction: any Item]
    var constants: [PushInstruction: any Item]
    /// The program that produced it, for writing a replayable case out.
    var program: [any Item]
    var seed: UInt64
    var caseIndex: Int

    /// A stable identifier for this program, suitable as a filename.
    var caseId: String { "crux-\(seed)-\(caseIndex)" }
}


/// A parameterized corpus of random programs.
///
/// Every field is a knob an investigation has wanted at least once. `mix` is the
/// least obvious: it reweights the generated programs by `InstructionRole`, so
/// `.enriched(.other)` buys more computing and less stack furniture.
///
/// Note what it *cannot* do. The tags are `.constant`, `.input`, `.stackFamily` and
/// `.other`, so there is no way to concentrate **loops** — and loops are where
/// provenance has been hardest (the cycling-walker bug that closed #27 appeared
/// once in 1,600 programs and could not be hunted deliberately). A mix keyed on
/// `Interpreter.reEntrantInstructions` is the obvious missing lever.
@MainActor
struct CruxSweep {
    var seeds: [UInt64]
    var casesPerSeed: Int
    /// Plushy tokens per random genome. Longer programs nest more deeply, which is
    /// where provenance gets hard — and where cruxes get long enough that the
    /// step budget starts to matter.
    var programItems: Int
    var settings: InterpreterSettings
    var mix: InstructionMix
    /// Which stacks to harvest. `.error` is excluded by default: an ErrorItem is a
    /// literal that reproduces itself, so it says nothing about provenance.
    var stacks: [PushStack]

    init(
        seeds: [UInt64] = CruxSweep.spacedSeeds(8),
        casesPerSeed: Int = 20,
        programItems: Int = 150,
        stepLimit: Int = 3_000,
        mix: InstructionMix = .equalShares,
        stacks: [PushStack]? = nil
    ) {
        self.seeds = seeds
        self.casesPerSeed = casesPerSeed
        self.programItems = programItems
        var s = InterpreterSettings.recordingProvenance   // it checks cruxes
        s.stepLimit = stepLimit
        self.settings = s
        self.mix = mix
        self.stacks = stacks ?? PushStack.allStacks.filter { $0 != .error }
    }

    var programCount: Int { seeds.count * casesPerSeed }

    /// Seeds spaced by a prime, so consecutive streams do not overlap.
    ///
    /// The spacing is the point. Seeds 1…8 would draw heavily overlapping
    /// sequences from a linear generator and buy far less independence than the
    /// count suggests.
    static func spacedSeeds(_ count: Int, from base: UInt64 = 20_260_726) -> [UInt64] {
        (0..<count).map { base &+ UInt64($0) &* 7919 }
    }

    /// Run the corpus, calling `visit` once per item that records a `call` and has
    /// a stack to come to rest on — the two conditions that make a provenance
    /// claim checkable at all.
    ///
    /// Items are visited as they are found, rather than collected, so a sweep of
    /// hundreds of thousands of claims does not hold them all at once.
    func forEachClaim(_ visit: (SweptItem) throws -> Void) rethrows {
        for seed in seeds {
            fuzzRNG = SeededRNG(seed: seed)
            for caseIndex in 0..<casesPerSeed {
                let program = FibonacciGenome.translate(
                    RandomCode.randomProgram(programItems, mix: mix))

                let inty = Interpreter.recordingProvenance()
                inty.config = settings
                inty.load(program: program)
                RandomCode.setRandomInputs(in: inty)
                RandomCode.setRandomConstants(in: inty)
                let inputs = inty.inputs
                let constants = inty.constants
                inty.run(stepLimit: settings.stepLimit)

                for stack in stacks {
                    for item in inty.stacks[stack]! {
                        guard !item.call.isEmpty,
                              PushStack.defaultStack(for: item) != nil
                        else { continue }
                        try visit(SweptItem(
                            item: item, foundOn: stack,
                            inputs: inputs, constants: constants,
                            program: program, seed: seed, caseIndex: caseIndex))
                    }
                }
            }
        }
    }

    /// Inspect every claim and accumulate the verdicts.
    ///
    /// The one-line form of the loop every investigation starts with. Reach for
    /// `forEachClaim` when you need to do something other than judge — walking
    /// call trees, measuring crux sizes, writing cases out.
    func report(
        stepScale: Int = 20,
        onHalt: HaltPolicy = .flushExecAndJudge
    ) -> CruxFailureReport {
        var report = CruxFailureReport()
        forEachClaim { swept in
            report.record(
                inspectCrux(of: swept.item,
                            inputs: swept.inputs,
                            constants: swept.constants,
                            settings: settings,
                            stepScale: stepScale,
                            onHalt: onHalt),
                for: swept)
        }
        return report
    }
}


@MainActor
extension SweptItem {
    /// Write this item's program out as a replayable `EvaluationRequest`, so a
    /// case survives without depending on the RNG — the reproduction path that
    /// still works when someone else's test has eaten the stream.
    ///
    /// Returns the file URL, or nil if encoding or writing failed.
    @discardableResult
    func writeReplayCase(
        into directory: URL? = nil,
        settings: InterpreterSettings
    ) -> URL? {
        let dir = directory ?? FileManager.default.temporaryDirectory
            .appending(path: "push-crux-diagnostics")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let request = EvaluationRequest(
            individuals: [Individual(id: caseId, program: program, constants: constants)],
            trainingCases: [TrainingCase(id: caseId, inputs: inputs)],
            pairings: [Pairing(individual: caseId, trainingCase: caseId)],
            configuration: RunnerConfiguration(settings: settings)
        )
        let url = dir.appending(path: "\(caseId).json")
        guard let data = try? JSONEncoder().encode(request),
              (try? data.write(to: url)) != nil
        else { return nil }
        return url
    }
}
