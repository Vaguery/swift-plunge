//
//  Crux Comb Export.swift
//  PlungeTests
//
//  Combing a program: the run's final state rebuilt as a sequence of cruxes,
//  one per item, every item of every crux traced to the program token and the
//  step it came from (`CruxAttribution.traced`). Written out as JSON for
//  drawing; the drawings are the *Combing Push Programs* page.
//
//  Each crux is the flattened tree, with no dup or yank to share a value, so
//  every item in the combed program comes from exactly one place. A shared value
//  is written out once per use, which a drawing shows as a fan.
//
//  Off unless `PUSH_COMB_EXPORT` names the output file. Run:
//
//      PUSH_COMB_EXPORT=/tmp/comb.json swift test -c release -Xswiftc -enable-testing \
//          --filter CruxCombExport
//
//  `PUSH_COMB_SEED` and `PUSH_COMB_PROGRAMS` choose the seeds (default 1 and
//  400); programs whose combed form passes `PUSH_COMB_MAX` items (default 900)
//  are left out. The test fails if any program does not rebuild exactly.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct CruxCombExport {

    nonisolated static let output: String? = ProcessInfo.processInfo.environment["PUSH_COMB_EXPORT"]

    struct Token: Encodable {
        let text: String, kind: String, depth: Int, parent: Int
        let steps: [Int]
    }
    struct CombedItem: Encodable {
        let text: String
        let token: Int
        let step: Int
        let result: Int
    }
    struct Result: Encodable {
        let stack: String, depth: Int, value: String
        let tokens: [Int]
        let start: Int, end: Int
        let crux: String
    }
    struct Sample: Encodable {
        let seed: UInt64
        let tokens: [Token]
        let steps: Int
        let results: [Result]
        let combed: [CombedItem]
        let combedSteps: Int
        let rebuiltExactly: Bool
    }

    @Test(.enabled(if: CruxCombExport.output != nil))
    func `comb programs and export them`() throws {
        let instructions = Runner().definedInstructions
        let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }
        let environment = ProcessInfo.processInfo.environment
        let firstSeed = environment["PUSH_COMB_SEED"].flatMap(UInt64.init) ?? 1
        let count = environment["PUSH_COMB_PROGRAMS"].flatMap(Int.init) ?? 400
        let maxCombed = environment["PUSH_COMB_MAX"].flatMap(Int.init) ?? 900
        var samples: [Sample] = []
        for seed in firstSeed..<(firstSeed + UInt64(count)) {
            if let sample = Self.comb(DualModeStress.makeCase(seed: seed, instructions: instructions, loopers: loopers),
                                      seed: seed, maxCombed: maxCombed) {
                samples.append(sample)
            }
        }
        try JSONEncoder().encode(samples).write(to: URL(fileURLWithPath: Self.output!))
        let exact = samples.filter(\.rebuiltExactly).count
        print("COMB: \(samples.count) samples written; \(exact) rebuilt exactly")
        #expect(exact == samples.count, "every combed program rebuilds its final state")
    }

    /// One program combed, or nil when its combed form is too long to draw.
    static func comb(_ made: DualModeStress.Case, seed: UInt64, maxCombed: Int) -> Sample? {
        var settings = InterpreterSettings()
        settings.stepLimit = 1_000
        settings.maxLiveWeight = 256_000
        let lengths = [20, 30, 40, 60, 80, 120, 160, 200, 300]
        let program = Array(made.program.prefix(min(made.program.count, lengths[Int(seed % UInt64(lengths.count))])))
        let run = CruxAttribution.run(program, inputs: made.inputs, constants: made.constants, settings: settings)

        // Every final item's crux, stack by stack, bottom first.
        var combed: [CombedItem] = []
        var results: [Result] = []
        var cruxes: [[any Item]] = []
        for stack in PushStack.allStacks where stack != .exec && stack != .error {
            for (depth, item) in run.interpreter.stacks[stack]!.enumerated().reversed() {
                let traced = CruxAttribution.traced(item, in: run)
                let start = combed.count, index = results.count
                combed += traced.map {
                    CombedItem(text: String($0.item.pretty().prefix(40)), token: $0.token, step: $0.step, result: index)
                }
                cruxes.append(traced.map(\.item))
                results.append(Result(stack: stack.rawValue, depth: depth, value: String(item.pretty().prefix(60)),
                                      tokens: CruxAttribution.attribution(of: item, in: run).tokens.sorted(),
                                      start: start, end: combed.count,
                                      crux: traced.map { $0.item.pretty() }.joined(separator: " ")))
                if combed.count > maxCombed { return nil }
            }
        }
        guard !results.isEmpty else { return nil }
        let redo = CruxAttribution.rebuild(cruxes, inputs: made.inputs, constants: made.constants, settings: settings)
        let exact = CruxAttribution.finalState(redo) == CruxAttribution.finalState(run.interpreter)

        var runs: [Int: [Int]] = [:]
        for (step, token) in run.stepTokens.enumerated() where token >= 0 { runs[token, default: []].append(step) }
        let tokens = (0..<run.table.count).map { t in
            let item = run.table.items[t]
            return Token(text: item.exactly(CodeItem.self) != nil ? "( … )" : String(item.pretty().prefix(40)),
                         kind: CruxAttribution.kind(of: item), depth: run.table.paths[t].count - 1,
                         parent: run.table.parents[t], steps: runs[t] ?? [])
        }
        return Sample(seed: seed, tokens: tokens, steps: run.stepTokens.count, results: results, combed: combed,
                      combedSteps: redo.counter, rebuiltExactly: exact)
    }
}
