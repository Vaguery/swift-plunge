//
//  Provenance Off Parity Tests.swift
//  PlungeTests
//
//  With `recordsProvenance` off, Behaviors skip building provenance altogether: every
//  `call` expression is written inside `recording(…)` (see `ProvenanceRecording`) and
//  is never evaluated. Two things must then hold, for the whole language:
//
//  1. **Nothing a program computes changes.** Every stack — values, errors, weights —
//     is identical with recording on and off. Provenance is explanation, never input.
//  2. **Nothing is built.** With recording off, no result carries a `call`, at any
//     depth (inside code blocks and iterators too). This is the guarantee the old
//     strip-on-push gave after the fact; now it holds at construction.
//
//  The sweeps reuse the crux round-trip harness's seeded interpreter, so they drive
//  every registered Behavior with the same plausible arguments it does, and also run
//  each one starved (no arguments) and nearly starved.
//

@testable import Plunge
import Testing

@Suite
struct ProvenanceOffParityTests {

    let harness = CruxRoundTripTests()

    func seeded(depth: Int, recording: Bool) -> Interpreter {
        harness.seeded(depth: depth, recording: recording)
    }

    /// Everything a run computes, as text: each stack's items (rendered with
    /// `pretty()`, which never shows provenance, and their content `weight`), the
    /// live weight, and the step counter.
    func signature(of inty: Interpreter) -> String {
        let stacks = PushStack.allStacks.map { stack in
            "\(stack): " + inty.stacks[stack]!.map { "\($0.pretty())#\($0.weight)" }.joined(separator: " ")
        }
        return (stacks + ["liveWeight \(inty.liveWeight)", "counter \(inty.counter)"]).joined(separator: "\n")
    }

    /// Every place inside `item` that carries a `call`: the item itself, the items
    /// in a code block, and an iterator's origin, destination and body.
    func callBearing(_ item: any Item) -> [String] {
        var found: [String] = item.call.isEmpty ? [] : [item.pretty()]
        if let block = item as? CodeItem {
            found += block.value.flatMap(callBearing)
        }
        if let iterator = item as? IteratorItem {
            found += callBearing(iterator.origin)
            if let destination = iterator.destination { found += callBearing(destination) }
            if let body = iterator.body { found += callBearing(body) }
        }
        return found
    }

    // MARK: - Values are unchanged

    @Test(arguments: [0, 1, 4])
    func `every behavior computes the same values with recording off`(depth: Int) {
        var mismatches: [String] = []
        for name in Interpreter.language.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            let on = seeded(depth: depth, recording: true)
            let off = seeded(depth: depth, recording: false)
            Interpreter.language[name]!.act(on: on)
            Interpreter.language[name]!.act(on: off)
            let (onSignature, offSignature) = (signature(of: on), signature(of: off))
            if onSignature != offSignature {
                mismatches.append(".\(name):\n  on:  \(onSignature)\n  off: \(offSignature)")
            }
        }
        #expect(mismatches.isEmpty, "recording off changed what these compute:\n\(mismatches.joined(separator: "\n"))")
    }

    /// Whole programs, including loops, iterators and side-effecting behaviors, under
    /// the settings the search uses: the throughput benchmark's 200 seeded programs.
    @Test func `random programs compute the same values with recording off`() {
        let benchmark = ThroughputBenchmark()
        var mismatches = 0
        var firstMismatch = ""
        for (index, program) in benchmark.benchmarkPrograms().enumerated() {
            let signatures = [true, false].map { recording in
                let inty = Interpreter()
                inty.config = benchmark.searchSettings(recordsProvenance: recording)
                inty.load(program: program)
                inty.run()
                return signature(of: inty)
            }
            if signatures[0] != signatures[1] {
                mismatches += 1
                if firstMismatch.isEmpty {
                    firstMismatch = "program \(index):\n  on:  \(signatures[0])\n  off: \(signatures[1])"
                }
            }
        }
        #expect(mismatches == 0, "\(mismatches) of 200 programs differ; first:\n\(firstMismatch)")
    }

    // MARK: - Nothing is built

    /// Each behavior's own results, as it returns them — before `push` sees them —
    /// plus whatever it left on the stacks, walked to every depth.
    @Test func `with recording off, no behavior builds any provenance`() {
        var builders: [String] = []
        for name in Interpreter.language.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            let behavior = Interpreter.language[name]!
            let inty = seeded(depth: 4, recording: false)
            let planner = Planner(for: inty)
            guard case .ready(let arguments, let claims) = planner.plan(behavior.requirements) else { continue }
            planner.commit(claims)
            let routers = behavior.computeResults(from: arguments, on: inty)
            let returned = routers.flatMap { callBearing($0.item) }
            let left = PushStack.allStacks.flatMap { inty.stacks[$0]!.flatMap(callBearing) }
            if !returned.isEmpty || !left.isEmpty {
                builders.append(".\(name): \((returned + left).prefix(3).joined(separator: ", "))")
            }
        }
        #expect(builders.isEmpty,
                "these build provenance with recording off (\(builders.count)):\n\(builders.joined(separator: "\n"))")
    }
}
