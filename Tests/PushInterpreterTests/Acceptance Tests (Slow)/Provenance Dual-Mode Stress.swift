//
//  Provenance Dual-Mode Stress.swift
//  PushInterpreterTests
//
//  A long soak for Phase 2's provenance gate: as many random programs as a time
//  budget allows, each run twice — provenance recording off and on — on a fresh
//  interpreter, in parallel across cores. For every program:
//
//  - both runs must compute exactly the same thing (every stack's values and
//    weights, the error stack, live weight, step count and printout);
//  - the recording-off run must leave no `call` anywhere, at any depth;
//  - neither run may take unreasonably long (a hang inside one step is the
//    failure class `stepLimit` cannot see);
//  - for a sample of programs, the recording-on run's top results must have
//    cruxes that replay to the same value (reported, not asserted: a replay that
//    runs out of budget is inconclusive, not a bug).
//
//  Off unless `PUSH_STRESS_SECONDS` is set. Run alone, in release:
//
//      PUSH_STRESS_SECONDS=7200 swift test -c release -Xswiftc -enable-testing \
//          --filter ProvenanceDualModeStress
//
//  **Each run explores new programs.** Every finished batch is recorded in a
//  ledger (`Soak/dual-mode-ledger.tsv` at the package root, or
//  `PUSH_STRESS_LEDGER`): its seed range, the date, how many instructions the
//  language had, and what it found. A run starts after the highest seed the
//  ledger has checked, so a clean run is never repeated; a batch that crashes is
//  not recorded, so the next run meets it again. `PUSH_STRESS_SEED` picks the
//  first seed instead, to reproduce something. `PUSH_STRESS_DIR` is where the
//  progress log, summary and any failing programs are written (default: the
//  temporary directory). Every program is a pure function of its seed (and of
//  the language it is drawn from), so any finding replays with
//  `DualModeStress.check(seed:...)` or `PUSH_STRESS_TRACE=lo-hi`.
//

import Foundation
@testable import PushInterpreter
import Testing

/// splitmix64, one per program, so programs are independent of scheduling.
nonisolated struct StressRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

nonisolated enum DualModeStress {

    /// The ledger of checked seed ranges, at the package root.
    static let defaultLedger = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "Soak/dual-mode-ledger.tsv")

    /// The first seed no ledger line has checked: one past the highest range end.
    static func nextUnchecked(in ledger: URL) -> UInt64 {
        guard let text = try? String(contentsOf: ledger, encoding: .utf8) else { return 0 }
        return text.split(separator: "\n").compactMap { line -> UInt64? in
            let fields = line.split(separator: "\t")
            guard fields.count >= 2, !line.hasPrefix("#") else { return nil }
            return UInt64(fields[1])
        }.max() ?? 0
    }

    /// Appends one line to the ledger, creating it with a header if need be.
    static func record(_ line: String, in ledger: URL) {
        let manager = FileManager.default
        if !manager.fileExists(atPath: ledger.path) {
            try? manager.createDirectory(at: ledger.deletingLastPathComponent(), withIntermediateDirectories: true)
            manager.createFile(atPath: ledger.path, contents: Data(
                "# from\tto (exclusive)\tdate\tinstructions\tresult\n".utf8))
        }
        guard let handle = try? FileHandle(forWritingTo: ledger) else { return }
        _ = try? handle.seekToEnd()
        handle.write(Data((line + "\n").utf8))
        try? handle.close()
    }

    /// One program and everything needed to run it again.
    struct Case: Sendable {
        let seed: UInt64
        let program: [any Item]
        let inputs: [PushInstruction: any Item]
        let constants: [PushInstruction: any Item]
        let settings: InterpreterSettings
        let regime: String
    }

    /// What one dual run found.
    struct Outcome: Sendable {
        var seed: UInt64
        var regime = ""
        var steps = 0
        var mismatch: String?
        var offCallSites: [String] = []
        var seconds: (off: Double, on: Double) = (0, 0)
        var cruxHolds = 0
        var cruxBroken: [String] = []
        var cruxInconclusive = 0
        var walkTruncated = false
        var hashTruncated = false
    }

    // MARK: - Generating a program from a seed

    static func makeCase(seed: UInt64, instructions: [PushInstruction], loopers: [PushInstruction]) -> Case {
        var rng = StressRNG(state: seed &* 0x2545_F491_4F6C_DD1D &+ 0x5EED)
        // Log-distributed 50…5,000 tokens: many modest programs, a long tail of big ones.
        let length = Int(exp(Double.random(in: log(50.0)...log(5_000.0), using: &rng)))
        let loopBias = Double.random(in: 0...0.3, using: &rng)

        func literal(depth: Int) -> any Item {
            switch Int.random(in: 0..<100, using: &rng) {
            case 0..<22: return IntItem(Int.random(in: -20...20, using: &rng))
            case 22..<25: return IntItem(Int.random(in: Int.min...Int.max, using: &rng))   // overflow bait
            case 25..<40: return DoubleItem(Double.random(in: -100...100, using: &rng))
            case 40..<50: return BoolItem(Bool.random(using: &rng))
            case 50..<60:
                let words = (0..<Int.random(in: 0...4, using: &rng)).map { _ in
                    String((0..<Int.random(in: 1...8, using: &rng)).map { _ in
                        "abcdefghij klm".randomElement(using: &rng)!
                    })
                }
                return StringItem(words.joined(separator: " "))
            case 60..<65: return CharItem("abcxyz 019".randomElement(using: &rng)!)
            case 65..<70: return VecIntItem((0..<Int.random(in: 0...6, using: &rng)).map { _ in Int.random(in: -9...9, using: &rng) })
            case 70..<73: return VecDoubleItem((0..<Int.random(in: 0...4, using: &rng)).map { _ in Double.random(in: -5...5, using: &rng) })
            case 73..<76: return VecBoolItem((0..<Int.random(in: 0...5, using: &rng)).map { _ in Bool.random(using: &rng) })
            case 76..<79: return VecStringItem((0..<Int.random(in: 0...3, using: &rng)).map { _ in ["a", "bc", "def", ""].randomElement(using: &rng)! })
            case 79..<82:
                // A literal pair, keyed among the input slots and just past them, so
                // keyed lookups, pops and unpacks meet pairs the program did not bind.
                guard depth < 5 else { return IntItem(Int.random(in: 0...9, using: &rng)) }
                let bound = literal(depth: depth + 1)
                guard !(bound is BindingItem) else { return bound }
                return BindingItem(key: Int.random(in: -2...12, using: &rng), bound: bound)
            default:
                guard depth < 5 else { return IntItem(Int.random(in: 0...9, using: &rng)) }
                return CodeItem((0..<Int.random(in: 0...10, using: &rng)).map { _ in token(depth: depth + 1) })
            }
        }

        func token(depth: Int) -> any Item {
            let roll = Double.random(in: 0..<1, using: &rng)
            if roll < loopBias, let looper = loopers.randomElement(using: &rng) {
                return InstructionItem(looper)
            }
            if roll < 0.7 { return InstructionItem(instructions.randomElement(using: &rng)!) }
            return literal(depth: depth)
        }

        let program = (0..<length).map { _ in token(depth: 0) }

        var inputs: [PushInstruction: any Item] = [:]
        for i in 0..<10 where Bool.random(using: &rng) {
            inputs[PushInstruction(rawValue: "input\(i)")!] = literal(depth: 2)
        }
        // Typed constant slots get a value of their own type when bound.
        var constants: [PushInstruction: any Item] = [:]
        let typed: [(String, () -> any Item)] = [
            ("int", { IntItem(Int.random(in: -50...50, using: &rng)) }),
            ("double", { DoubleItem(Double.random(in: -50...50, using: &rng)) }),
            ("string", { StringItem(["x", "hello there", ""].randomElement(using: &rng)!) }),
            ("char", { CharItem("qrs".randomElement(using: &rng)!) }),
            ("vecInt", { VecIntItem([1, 2, 3].shuffled(using: &rng)) }),
            ("vecDouble", { VecDoubleItem([0.5, 1.5]) }),
            ("vecString", { VecStringItem(["p", "q"]) }),
            ("vecBool", { VecBoolItem([true, false]) })
        ]
        for (prefix, make) in typed {
            for i in 0..<10 where Int.random(in: 0..<3, using: &rng) == 0 {
                if let slot = PushInstruction(rawValue: "\(prefix)\(i)") { constants[slot] = make() }
            }
        }

        // Limits from PlungeGP's search settings up to "a server with RAM to spare":
        // the point is long, large, arbitrary runs, not a tidy population.
        var settings = InterpreterSettings()
        let regime: String
        func scaled(_ factor: Int, steps: Int, liveWeight: Int) {
            settings.stepLimit = steps
            settings.maxStackDepth *= factor
            settings.maxStringLength *= factor
            settings.maxVectorLength *= factor
            settings.maxCodePoints *= factor
            settings.maxItemWeight *= factor
            settings.maxLiveWeight = liveWeight
        }
        switch seed % 10 {
        case 0, 1, 2:
            regime = "search"      // PlungeGP's population settings
            settings.stepLimit = 1_000
            settings.maxLiveWeight = 256_000
        case 3, 4:
            regime = "default"
            settings.stepLimit = 5_000
        case 5, 6, 7:
            regime = "big"
            scaled(10, steps: 100_000, liveWeight: 100_000_000)
        default:
            regime = "huge"
            scaled(100, steps: 1_000_000, liveWeight: 200_000_000)
        }
        return Case(seed: seed, program: program, inputs: inputs, constants: constants,
                    settings: settings, regime: regime)
    }

    // MARK: - Running it both ways

    static func run(_ c: Case, recording: Bool) -> (Interpreter, Double) {
        let inty = Interpreter()
        inty.config = c.settings
        inty.config.recordsProvenance = recording
        inty.load(inputs: c.inputs, constants: c.constants, program: c.program)
        let clock = ContinuousClock()
        let start = clock.now
        inty.run()
        let elapsed = clock.now - start
        return (inty, Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
    }

    /// Everything a run computes, hashed structurally as it is read: every stack's
    /// depth, every item's type and content weight, and its contents — scalars by
    /// their rendering, blocks walked with an explicit stack (open, children, close)
    /// so neither nesting depth nor `pretty()`'s size × depth cost can stall it.
    /// `budget` caps the nodes rendered; the per-item weights and stack depths are
    /// always hashed in full, so a truncated hash still compares every item.
    /// (Hasher is seeded per process; both runs of a program are hashed in one.)
    static func signatureHash(_ inty: Interpreter, budget: Int = 5_000_000) -> (hash: Int, truncated: Bool) {
        var hasher = Hasher()
        var remaining = budget
        for stack in PushStack.allStacks {
            hasher.combine(stack)
            hasher.combine(inty.stacks[stack]!.count)
            for item in inty.stacks[stack]! {
                hasher.combine(ObjectIdentifier(type(of: item)))
                hasher.combine(item.weight)
                var pending: [any Item] = [item]
                while remaining > 0, let next = pending.popLast() {
                    remaining -= 1
                    if let block = next as? CodeItem {
                        hasher.combine("(\(block.value.count)")
                        pending.append(contentsOf: block.value.reversed())
                    } else if let iterator = next as? IteratorItem {
                        hasher.combine("iter \(iterator.value) \(iterator.laps) \(iterator.burial) \(iterator.emits)")
                        pending.append(iterator.origin)
                        if let destination = iterator.destination { pending.append(destination) }
                        if let body = iterator.body { pending.append(body) }
                    } else {
                        hasher.combine(next.pretty())
                    }
                }
            }
        }
        hasher.combine(inty.liveWeight)
        hasher.combine(inty.counter)
        hasher.combine(inty.printout)
        return (hasher.finalize(), remaining <= 0)
    }

    /// Everything a run computes, as text — only built to report a mismatch.
    static func signature(_ inty: Interpreter) -> String {
        let stacks = PushStack.allStacks.map { stack in
            "\(stack): " + inty.stacks[stack]!.prefix(50).map { item in
                item.weight < 10_000 ? "\(item.pretty())#\(item.weight)" : "<\(type(of: item)) weight \(item.weight)>"
            }.joined(separator: " ")
        }
        return (stacks + ["liveWeight \(inty.liveWeight)", "counter \(inty.counter)", "printout \(inty.printout)"])
            .joined(separator: "\n")
    }

    /// How deeply `item`'s call tree nests (iteratively, so measuring cannot itself overflow).
    static func callDepth(_ item: any Item) -> Int {
        var deepest = 0
        var pending: [(any Item, Int)] = [(item, 0)]
        while let (next, depth) = pending.popLast() {
            deepest = max(deepest, depth)
            pending += next.call.map { ($0, depth + 1) }
        }
        return deepest
    }

    /// Every place inside `item` that carries a `call` — walked with an explicit
    /// stack, since blocks legally nest up to `maxCodeDepth` and a recursive walk
    /// that deep overflows a worker thread (it did, here, at depth 965).
    ///
    /// `budget` caps the nodes visited: copied blocks share storage, so a big run
    /// can hold structure whose every path is far longer than what is stored, and
    /// walking all of it would stall the soak. A walk that runs out is counted as
    /// truncated rather than passed silently.
    static func callBearing(_ item: any Item, budget: inout Int) -> [String] {
        var found: [String] = []
        var pending: [any Item] = [item]
        while budget > 0, let next = pending.popLast() {
            budget -= 1
            if !next.call.isEmpty, found.count < 3 { found.append(String(next.pretty().prefix(80))) }
            if let block = next as? CodeItem { pending.append(contentsOf: block.value) }
            if let iterator = next as? IteratorItem {
                pending.append(iterator.origin)
                if let destination = iterator.destination { pending.append(destination) }
                if let body = iterator.body { pending.append(body) }
            }
        }
        return found
    }

    /// Replays the crux of each stack's top item from a recording run.
    static func checkCruxes(_ c: Case, _ on: Interpreter, into outcome: inout Outcome,
                            stage: @Sendable (String) -> Void = { _ in }) {
        for stack in PushStack.allStacks where stack != .error && stack != .exec {
            // Items too big to render cheaply are skipped: comparing a replay renders both.
            guard let item = on.stacks[stack]!.first, !item.call.isEmpty, item.weight < 100_000,
                  let resting = PushStack.defaultStack(for: item) else { continue }
            stage("    crux of .\(stack) top (callWeight \(item.callWeight), call depth \(callDepth(item)))")
            let crux = item.crux()
            stage("    crux has \(crux.count) items; replaying")
            let room = max(c.settings.stepLimit, crux.count * 20)
            let redo = Interpreter()
            redo.config = c.settings.reconstructing
            redo.config.stepLimit = room
            redo.load(inputs: c.inputs, constants: c.constants, program: crux)
            redo.run(stepLimit: room)
            stage("    replayed: \(redo.counter) steps, exec left \(redo.stacks[.exec]!.count); comparing")
            if !redo.stacks[.exec]!.isEmpty {
                outcome.cruxInconclusive += 1
            } else if redo.stacks[resting]!.first?.pretty() == item.pretty() {
                outcome.cruxHolds += 1
            } else {
                outcome.cruxBroken.append(
                    "seed \(c.seed) .\(stack): \(item.pretty().prefix(60)) ← reproduced "
                    + "\(redo.stacks[resting]!.first.map { String($0.pretty().prefix(60)) } ?? "nothing")")
            }
        }
    }

    static func check(seed: UInt64, instructions: [PushInstruction], loopers: [PushInstruction],
                      cruxSampleEvery: UInt64, stage: @Sendable (String) -> Void = { _ in }) -> Outcome {
        let c = makeCase(seed: seed, instructions: instructions, loopers: loopers)
        var outcome = Outcome(seed: seed, regime: c.regime)
        stage("run off (\(c.regime), \(c.program.count) tokens)")
        // The off run is summarized and released before the on run starts, so a
        // huge program never holds two interpreters' worth of stacks at once.
        var offSeconds = 0.0, offCounter = 0, offHash = 0
        do {
            let (off, seconds) = run(c, recording: false)
            offSeconds = seconds
            offCounter = off.counter
            let deepestBlock = PushStack.allStacks.flatMap { off.stacks[$0]! }
                .compactMap { ($0 as? CodeItem)?.nestingDepth }.max() ?? 0
            stage("hash off (deepest block \(deepestBlock), \(off.liveWeight) live weight)")
            (offHash, outcome.hashTruncated) = signatureHash(off)
            stage("call walk")
            var budget = 2_000_000
            outcome.offCallSites = PushStack.allStacks.flatMap { stack in
                off.stacks[stack]!.flatMap { callBearing($0, budget: &budget) }
            }
            outcome.walkTruncated = budget <= 0
        }
        stage("run on")
        let (on, onSeconds) = run(c, recording: true)
        outcome.seconds = (offSeconds, onSeconds)
        outcome.steps = on.counter
        stage("hash on (off \(offCounter) steps, on \(on.counter) steps)")
        if signatureHash(on).hash != offHash {
            // Re-run off to report the difference in full.
            let (offAgain, _) = run(c, recording: false)
            outcome.mismatch = "off:\n\(signature(offAgain).prefix(2_000))\non:\n\(signature(on).prefix(2_000))"
        }
        stage("crux replay")
        if cruxSampleEvery > 0, seed % cruxSampleEvery == 0 {
            checkCruxes(c, on, into: &outcome, stage: stage)
        }
        return outcome
    }
}


@Suite @MainActor
struct ProvenanceDualModeStress {

    nonisolated static let budget: Double? =
        ProcessInfo.processInfo.environment["PUSH_STRESS_SECONDS"].flatMap(Double.init)

    @Test(.enabled(if: ProvenanceDualModeStress.budget != nil))
    func `thousands of random programs compute the same with recording off and on`() async throws {
        let environment = ProcessInfo.processInfo.environment
        let budget = Self.budget ?? 0
        let ledger = environment["PUSH_STRESS_LEDGER"].map { URL(fileURLWithPath: $0) } ?? DualModeStress.defaultLedger
        let firstSeed = environment["PUSH_STRESS_SEED"].flatMap(UInt64.init) ?? DualModeStress.nextUnchecked(in: ledger)
        let dir = environment["PUSH_STRESS_DIR"].map { URL(fileURLWithPath: $0) } ?? URL.temporaryDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let progressURL = dir.appending(path: "stress-progress.log")
        let summaryURL = dir.appending(path: "stress-summary.txt")
        let findingsURL = dir.appending(path: "stress-findings.txt")
        FileManager.default.createFile(atPath: progressURL.path, contents: nil)
        FileManager.default.createFile(atPath: findingsURL.path, contents: nil)
        let progress = try FileHandle(forWritingTo: progressURL)
        let findings = try FileHandle(forWritingTo: findingsURL)
        func append(_ handle: FileHandle, _ line: String) {
            handle.write(Data((line + "\n").utf8))
            try? handle.synchronize()
        }

        let instructions = Runner().definedInstructions
        let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }
        let batchSize: UInt64 = 120
        let cruxSampleEvery: UInt64 = 25
        let slowSeconds = 60.0
        func peakResidentMB() -> Int {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            return Int(usage.ru_maxrss / 1_048_576)   // bytes on macOS
        }

        let clock = ContinuousClock()
        let started = clock.now
        func elapsed() -> Double {
            let d = clock.now - started
            return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
        }

        var programs = 0, steps = 0
        var mismatches = 0, offCallPrograms = 0, truncatedWalks = 0, truncatedHashes = 0
        var cruxHolds = 0, cruxBroken = 0, cruxInconclusive = 0
        var slow: [(seconds: Double, seed: UInt64, regime: String)] = []
        var byRegime: [String: Int] = [:]
        var slowest = (seconds: 0.0, seed: UInt64(0))
        var next = firstSeed

        append(progress, "start: budget \(Int(budget)) s, first seed \(firstSeed), \(instructions.count) instructions, batch \(batchSize), ledger \(ledger.path)")

        // Trace mode: `PUSH_STRESS_TRACE=lo-hi` runs those seeds one at a time, still on
        // a worker thread, logging each seed before it runs — to pin down a crash.
        if let trace = environment["PUSH_STRESS_TRACE"]?.split(separator: "-").compactMap({ UInt64($0) }),
           trace.count == 2 {
            let stageLog: @Sendable (String) -> Void = { line in
                progress.write(Data(("  " + line + "\n").utf8))
                try? progress.synchronize()
            }
            for seed in trace[0]..<trace[1] {
                append(progress, "trace seed \(seed)")
                let outcome = await Task.detached {
                    DualModeStress.check(seed: seed, instructions: instructions, loopers: loopers, cruxSampleEvery: 1,
                                         stage: stageLog)
                }.value
                if outcome.mismatch != nil || !outcome.offCallSites.isEmpty || !outcome.cruxBroken.isEmpty {
                    append(progress, "  finding at seed \(seed)")
                }
            }
            append(progress, "trace done")
            return
        }

        while elapsed() < budget {
            let range = next..<(next + batchSize)
            // Written before the batch runs, so a crash or hang names the seeds in flight.
            append(progress, String(format: "%8.0f s  running seeds %llu..<%llu", elapsed(), range.lowerBound, range.upperBound))
            let outcomes = await withTaskGroup(of: DualModeStress.Outcome.self) { group in
                for seed in range {
                    group.addTask {
                        DualModeStress.check(seed: seed, instructions: instructions, loopers: loopers,
                                             cruxSampleEvery: cruxSampleEvery)
                    }
                }
                var all: [DualModeStress.Outcome] = []
                for await outcome in group { all.append(outcome) }
                return all
            }
            var batchFindings: [String] = []
            for o in outcomes {
                if o.mismatch != nil { batchFindings.append("mismatch \(o.seed)") }
                if !o.offCallSites.isEmpty { batchFindings.append("off-call \(o.seed)") }
                if !o.cruxBroken.isEmpty { batchFindings.append("crux \(o.seed)") }
                programs += 1
                steps += o.steps
                byRegime[o.regime, default: 0] += 1
                let worst = max(o.seconds.off, o.seconds.on)
                if worst > slowest.seconds { slowest = (worst, o.seed) }
                if worst > slowSeconds { slow.append((worst, o.seed, o.regime)) }
                if o.walkTruncated { truncatedWalks += 1 }
                if o.hashTruncated { truncatedHashes += 1 }
                cruxHolds += o.cruxHolds
                cruxInconclusive += o.cruxInconclusive
                if let mismatch = o.mismatch {
                    mismatches += 1
                    if mismatches <= 20 { append(findings, "MISMATCH seed \(o.seed) (\(o.regime))\n\(mismatch)\n") }
                }
                if !o.offCallSites.isEmpty {
                    offCallPrograms += 1
                    if offCallPrograms <= 20 {
                        append(findings, "OFF-CALL seed \(o.seed): \(o.offCallSites.prefix(3).joined(separator: " | "))")
                    }
                }
                for line in o.cruxBroken {
                    cruxBroken += 1
                    if cruxBroken <= 50 { append(findings, "CRUX \(line)") }
                }
            }
            next = range.upperBound
            DualModeStress.record([
                "\(range.lowerBound)", "\(range.upperBound)", Date.now.formatted(.iso8601),
                "\(instructions.count)", batchFindings.isEmpty ? "passed" : batchFindings.sorted().joined(separator: ", "),
            ].joined(separator: "\t"), in: ledger)
            append(progress, String(
                format: "%8.0f s  done %d programs, %d steps; mismatches %d, off-call %d, slow %d (worst %.2f s, seed %llu); crux holds %d, broken %d, inconclusive %d; peak RSS %d MB",
                elapsed(), programs, steps, mismatches, offCallPrograms, slow.count, slowest.seconds, slowest.seed,
                cruxHolds, cruxBroken, cruxInconclusive, peakResidentMB()))
        }

        let summary = """
        provenance dual-mode stress — \(Int(elapsed())) s, seeds \(firstSeed)..<\(next)
        programs: \(programs) (\(byRegime.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))), each run with recording off and on
        interpreter steps (recording on): \(steps)
        value mismatches between modes: \(mismatches) (content hash truncated at 5M nodes for \(truncatedHashes) programs; their weights and depths are still compared in full)
        programs whose recording-off run left a call anywhere: \(offCallPrograms) (walk truncated at 2M nodes for \(truncatedWalks) programs)
        runs over \(slowSeconds) s: \(slow.count); slowest \(String(format: "%.2f", slowest.seconds)) s (seed \(slowest.seed))
        sampled crux replays (every \(cruxSampleEvery)th program, top of each stack): holds \(cruxHolds), broken \(cruxBroken), inconclusive (out of budget) \(cruxInconclusive)
        peak resident memory: \(peakResidentMB()) MB
        findings: \(findingsURL.path)
        """
        append(progress, summary)
        try summary.write(to: summaryURL, atomically: true, encoding: .utf8)
        print(summary)

        #expect(mismatches == 0, "recording off changed what \(mismatches) programs compute")
        #expect(offCallPrograms == 0, "\(offCallPrograms) recording-off runs built provenance")
    }
}
