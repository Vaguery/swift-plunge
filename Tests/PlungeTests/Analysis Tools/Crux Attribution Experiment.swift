//
//  Crux Attribution Experiment.swift
//  PlungeTests
//
//  Attribution checked over random programs (`Crux Attribution.swift`).
//
//  For each program, every result's tokens are found, and then:
//
//  - **Deleting tokens.** Tokens that ran are deleted one at a time. Do the
//    results that list a token lose their value (and their exact crux), and do
//    the others keep theirs?
//  - **Slicing and transplanting.** For a sample of results: the program cut
//    down to the result's tokens, with and without the structural and control
//    tokens that ran, and less every other result's tokens; the result's crux
//    replayed alone, after its program and before it.
//  - **Rebuilding.** Every item's crux, stack by stack, bottom item first, run on
//    a fresh interpreter. Does it rebuild the final state?
//  - **Functions.** Which results read the inputs, and how many distinct
//    abstract cruxes they make.
//
//  Off unless `PUSH_ATTRIBUTION` is set to the number of programs.
//  `PUSH_ATTRIBUTION_QUICK=1` skips the crux-identity deletions, the slowest
//  part. Run:
//
//      PUSH_ATTRIBUTION=300 swift test -c release -Xswiftc -enable-testing \
//          --filter CruxAttributionExperiment
//
//  The report is written to `PUSH_ATTRIBUTION_DIR` (default: the temporary
//  directory) as `crux-attribution.txt`. Programs come from the dual-mode soak's
//  generator, cut to at most 300 tokens (every third to 40).
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct CruxAttributionExperiment {

    nonisolated static let programs: Int? =
        ProcessInfo.processInfo.environment["PUSH_ATTRIBUTION"].flatMap(Int.init)

    @Test(.enabled(if: CruxAttributionExperiment.programs != nil))
    func `map every result's history back onto the program`() throws {
        let environment = ProcessInfo.processInfo.environment
        let dir = environment["PUSH_ATTRIBUTION_DIR"].map { URL(fileURLWithPath: $0) } ?? URL.temporaryDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let firstSeed = environment["PUSH_ATTRIBUTION_SEED"].flatMap(UInt64.init) ?? 1
        let quick = environment["PUSH_ATTRIBUTION_QUICK"] != nil
        let instructions = Runner().definedInstructions
        let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }

        var totals = AttributionTotals()
        var examples: [String] = []
        for seed in firstSeed..<(firstSeed + UInt64(Self.programs ?? 0)) {
            let made = DualModeStress.makeCase(seed: seed, instructions: instructions, loopers: loopers)
            var settings = InterpreterSettings()
            settings.stepLimit = seed % 2 == 0 ? 1_000 : 5_000
            settings.maxLiveWeight = 256_000
            let length = min(made.program.count, seed % 3 == 0 ? 40 : 300)
            let c = DualModeStress.Case(seed: seed, program: Array(made.program.prefix(length)), inputs: made.inputs,
                                        constants: made.constants, settings: settings, regime: "attribution")
            var study = Study(c, into: &totals)
            study.census(&totals)
            study.deletions(&totals)
            if !quick { study.cruxDeletions(&totals) }
            study.reproductions(&totals)
            study.rebuild(&totals)
            study.functions(&totals)
            if examples.count < 8, let example = study.example() { examples.append(example) }
        }
        let report = totals.report
            + "\n\nRebuild failures:\n" + totals.rebuildFailures.joined(separator: "\n")
            + "\n\nSurvivors (a listed token deleted, the value still there):\n"
            + totals.survivors.joined(separator: "\n") + "\n\n" + examples.joined(separator: "\n\n")
        try report.write(to: dir.appending(path: "crux-attribution.txt"), atomically: true, encoding: .utf8)
        print(report)
    }
}

/// One program, studied.
nonisolated struct Study {
    typealias Result = CruxAttribution.Result

    let c: DualModeStress.Case
    let plain: Interpreter
    let baseline: [PushStack: [String]]
    let run: CruxAttribution.Run
    let results: [Result]
    /// Results with two or more tokens.
    let tracked: [Result]
    /// Every token some result's history passes through.
    let union: Set<Int>
    var rng: StressRNG

    var table: TokenTable { run.table }

    init(_ c: DualModeStress.Case, into totals: inout AttributionTotals) {
        self.c = c
        let clock = ContinuousClock()
        var start = clock.now
        plain = CruxAttribution.plainRun(c.program, c)
        totals.plainSeconds += CruxAttribution.seconds(clock.now - start)
        baseline = CruxAttribution.finalState(plain)
        run = CruxAttribution.run(c.program, inputs: c.inputs, constants: c.constants, settings: c.settings)
        totals.attributedSeconds += run.seconds
        if CruxAttribution.finalState(run.interpreter) != baseline { totals.divergent += 1 }
        start = clock.now
        results = CruxAttribution.results(of: run)
        totals.walkSeconds += CruxAttribution.seconds(clock.now - start)
        tracked = results.filter { $0.attribution.tokens.count >= 2 }
        union = results.reduce(into: Set<Int>()) { $0.formUnion($1.attribution.tokens) }
        rng = StressRNG(state: c.seed &* 0x9E37_79B9)
    }

    static func rendered(_ item: any Item) -> String { String(item.pretty().prefix(300)) }

    func kind(_ token: Int) -> String { CruxAttribution.kind(of: table.items[token]) }

    func runPlain(_ program: [any Item], stepLimit: Int? = nil) -> Interpreter {
        let redo = Interpreter()
        redo.config = c.settings
        redo.config.recordsProvenance = false
        if let stepLimit { redo.config.stepLimit = stepLimit }
        redo.load(inputs: c.inputs, constants: c.constants, program: program)
        redo.run()
        return redo
    }

    func runRecording(_ program: [any Item]) -> Interpreter {
        let redo = Interpreter()
        redo.config = c.settings
        redo.config.recordsProvenance = true
        redo.config.maxCallWeight = 10_000_000
        redo.config.maxCallDepth = 1_000_000
        redo.load(inputs: c.inputs, constants: c.constants, program: program)
        redo.run()
        return redo
    }

    // MARK: - What the program looks like, combed out

    func census(_ totals: inout AttributionTotals) {
        totals.programs += 1
        totals.tokens += table.count
        totals.executed += run.executed.count
        totals.steps += run.stepTokens.count
        totals.results += results.count
        totals.nontrivial += tracked.count
        totals.contributing += union.count
        totals.contributingExecuted += union.intersection(run.executed).count
        totals.contributingNeverRan += union.subtracting(run.executed).count
        let silent = run.executed.subtracting(union)
        totals.silent += silent.count
        for token in silent { totals.silentByKind[kind(token), default: 0] += 1 }
        for token in union { totals.contributingByKind[kind(token), default: 0] += 1 }
        for token in union where ["structural", "control"].contains(kind(token)) {
            let name = table.items[token].pretty()
            totals.routingContributors[name, default: 0] += 1
            if totals.routingExample[name] == nil,
               let r = results.first(where: { $0.attribution.tokens.contains(token) }) {
                totals.routingExample[name] = "\(r.label) \(r.item.pretty().prefix(60)) ← "
                    + String(r.item.crux().map { $0.pretty() }.joined(separator: " ").prefix(120))
            }
        }
        for r in results {
            totals.unknownNodes += r.attribution.unknownNodes
            totals.walkedNodes += r.attribution.nodes
            totals.elided += r.attribution.elided
        }
        totals.pushedNodes += run.nodeSteps.count
        let held = heldNodes()
        totals.pushedNodesInResults += run.nodeSteps.keys.filter { held.contains($0) }.count

        let chunks = CruxAttribution.chunks(results)
        totals.chunks += chunks.count
        var users: [Int: Int] = [:]
        for r in results { for token in r.attribution.tokens { users[token, default: 0] += 1 } }
        totals.sharedTokens += users.values.filter { $0 > 1 }.count
        let largest = chunks.map { $0.reduce(into: Set<Int>()) { $0.formUnion(results[$1].attribution.tokens) }.count }
            .max() ?? 0
        if !union.isEmpty { totals.largestChunkShare += Double(largest) / Double(union.count) }
    }

    /// Every history node a final result still holds.
    func heldNodes() -> Set<CruxSharing.Key> {
        var held = Set<CruxSharing.Key>()
        for r in results {
            var pending: [any Item] = [r.item]
            while let item = pending.popLast() {
                CruxAttribution.appendContained(item, to: &pending)
                guard let key = CruxSharing.key(item), held.insert(key).inserted else { continue }
                pending.append(contentsOf: item.call)
            }
        }
        return held
    }

    // MARK: - Deleting tokens

    func valuesPresent(_ inty: Interpreter) -> [PushStack: Set<String>] {
        var found: [PushStack: Set<String>] = [:]
        for stack in PushStack.allStacks where stack != .exec && stack != .error {
            found[stack] = Set(inty.stacks[stack]!.map(Self.rendered))
        }
        return found
    }

    mutating func deletions(_ totals: inout AttributionTotals) {
        var valueCounts: [PushStack: [String: Int]] = [:]
        for stack in PushStack.allStacks where stack != .exec && stack != .error {
            for item in plain.stacks[stack]! { valueCounts[stack, default: [:]][Self.rendered(item), default: 0] += 1 }
        }
        let probes = Array(run.executed.sorted().shuffled(using: &rng).prefix(16))
        for token in probes where !tracked.isEmpty {
            let after = valuesPresent(runPlain(CruxAttribution.deleting(c.program, token)))
            for r in tracked {
                let value = Self.rendered(r.item)
                let kept = after[r.stack]!.contains(value)
                if r.attribution.tokens.contains(token) {
                    totals.dependentsLost.add(!kept)
                    if valueCounts[r.stack]?[value] == 1 {
                        totals.rareDependentsLost.add(!kept)
                        if kept, totals.survivors.count < 40, Int.random(in: 0..<6, using: &rng) == 0 {
                            totals.survivors.append(survivor(token, r))
                        }
                    }
                } else {
                    totals.othersKept.add(kept)
                    totals.othersKeptByKind.add(kind(token), kept)
                    if union.contains(token) { totals.othersKeptAfterLive.add(kept) } else {
                        totals.othersKeptAfterSilent.add(kept)
                    }
                }
            }
        }
        // Whole final state, after deleting a token that feeds nothing, or one that does.
        for token in Array(run.executed.subtracting(union).sorted().shuffled(using: &rng).prefix(12)) {
            let changed = CruxAttribution.finalState(runPlain(CruxAttribution.deleting(c.program, token))) != baseline
            totals.silentDeletionChanges.add(kind(token), changed)
        }
        for token in Array(union.sorted().shuffled(using: &rng).prefix(6)) {
            totals.liveDeletionChanges.add(
                CruxAttribution.finalState(runPlain(CruxAttribution.deleting(c.program, token))) != baseline)
        }
    }

    func survivor(_ token: Int, _ r: Result) -> String {
        let crux = r.item.crux().map { $0.pretty() }.joined(separator: " ")
        return "seed \(c.seed) deleted #\(token) \(kind(token)) \(table.items[token].pretty().prefix(40)) "
            + "(path \(table.paths[token])); \(r.label) = \(r.item.pretty().prefix(50)); "
            + "tokens \(r.attribution.tokens.sorted()); crux: \(crux.prefix(150))"
    }

    static func cruxText(_ item: any Item) -> String? {
        guard item.callWeight < 3_000, item.weight < 10_000 else { return nil }
        return item.crux().map { $0.pretty() }.joined(separator: " ")
    }

    /// The same deletions judged by exact crux, which cannot come back by coincidence.
    mutating func cruxDeletions(_ totals: inout AttributionTotals) {
        guard !tracked.isEmpty else { return }
        let recorded = runRecording(c.program)
        let wanted: [String?] = tracked.map { r in
            r.depth < recorded.stacks[r.stack]!.count ? Self.cruxText(recorded.stacks[r.stack]![r.depth]) : nil
        }
        for token in Array(run.executed.sorted().shuffled(using: &rng).prefix(8)) {
            let after = runRecording(CruxAttribution.deleting(c.program, token))
            var cruxes: [PushStack: Set<String>] = [:]
            for stack in PushStack.allStacks where stack != .exec && stack != .error {
                cruxes[stack] = Set(after.stacks[stack]!.compactMap(Self.cruxText))
            }
            for (r, crux) in zip(tracked, wanted) {
                guard let crux else { continue }
                let kept = cruxes[r.stack]!.contains(crux)
                if r.attribution.tokens.contains(token) {
                    totals.cruxDependentsLost.add(!kept)
                } else {
                    totals.cruxOthersKept.add(kept)
                    totals.cruxOthersKeptByKind.add(kind(token), kept)
                }
            }
        }
    }
}
