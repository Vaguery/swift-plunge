//
//  Starvation Function Census.swift
//  PlungeTests
//
//  If every missing-arguments refusal also pushed a function (the instruction,
//  the arguments that were present, and a hole for each one missing), what
//  would a program's `.function` stack hold, and would map, filter and reduce
//  find something to use when they fire? Measured on the probe's programs,
//  without changing the interpreter: each starvation is detected as the error
//  it raises, and its shortfall read from the instruction's signature.
//
//      PUSH_FUNCTION_PROBE=1 swift test --filter StarvationFunctionCensus
//

import Foundation
import Testing
@testable import Plunge

@Suite
struct StarvationFunctionCensus {

    typealias Probe = FunctionOutcome

    /// The function a starved instruction would make: its holes by stack, the
    /// arguments it found, and the stacks its result goes to.
    struct Partial {
        let holes: [PushStack: Int]
        let present: Int
        let outputs: Set<PushStack>
    }

    static let elementOf: [PushStack: PushStack] = [
        .vecInt: .int, .vecDouble: .double, .vecBool: .bool, .vecString: .string, .string: .char
    ]

    /// `token`'s shortfall on `inty`'s stacks as a partial function, or nil if
    /// its signature shows none (a count set by a value).
    static func partial(_ token: PushInstruction, in inty: Interpreter) -> Partial? {
        guard let signature = Probe.runner.signature(of: token) else { return nil }
        var wanted = signature.consumes
        for (stack, count) in signature.reads { wanted[stack, default: 0] += count }
        for (stack, count) in signature.needs { wanted[stack] = max(wanted[stack] ?? 0, count) }
        var holes: [PushStack: Int] = [:]
        var present = 0
        for (stack, count) in wanted {
            let have = inty.stacks[stack]?.count ?? 0
            present += min(have, count)
            if have < count { holes[stack] = count - have }
        }
        guard !holes.isEmpty else { return nil }
        var outputs: Set<PushStack> = []
        if case .results = signature.produces { outputs = Set(signature.produces.valueStacks) }
        return Partial(holes: holes, present: present, outputs: outputs)
    }

    static func fits(_ p: Partial, _ family: Probe.Family, _ element: PushStack) -> Bool {
        let n = p.holes[element] ?? 0
        switch family {
        case .map: return n >= 1 && !p.outputs.isDisjoint(with: Probe.scalarStacks)
        case .filter: return n >= 1 && p.outputs.contains(.bool)
        case .reduce: return n >= 2 && p.outputs.contains(element)
        }
    }

    struct Tally {
        var programs = 0, steps = 0, starvations = 0, unclassified = 0, partials = 0, bare = 0, unknownOutput = 0
        var holeCounts: [Int: Int] = [:]
        var outputs: [String: Int] = [:], signatures: [String: Int] = [:]
        /// Per family: natural firings with a non-empty collection, and those
        /// for which some earlier starvation in the run made a fitting function.
        var firings: [String: Int] = [:], served: [String: Int] = [:]
        /// Per family and element type: programs whose starvations made at
        /// least one fitting function.
        var offering: [String: Int] = [:]
    }

    static func census(_ regime: Probe.Regime, programs: Int) -> Tally {
        var t = Tally()
        for seed in 0..<programs {
            let drawn = withFuzzSeed(UInt64(seed)) { Probe.draw(regime) }
            let inty = Interpreter()
            inty.config.stepLimit = Probe.budget
            inty.load(inputs: drawn.inputs, constants: drawn.constants, program: drawn.program)
            var made: [Partial] = []
            while inty.counter < inty.config.stepLimit, let next = inty.stacks[.exec]!.first {
                let token = (next as? InstructionItem)?.value
                if let token, let (family, stack) = Probe.functionInstructions[token],
                   !(inty.stacks[stack]?.isEmpty ?? true), let element = elementOf[stack] {
                    t.firings["\(family)", default: 0] += 1
                    if made.contains(where: { fits($0, family, element) }) { t.served["\(family)", default: 0] += 1 }
                }
                let shortfall = token.flatMap { partial($0, in: inty) }
                let errors = inty.stacks[.error]!.count
                inty.step()
                guard inty.stacks[.error]!.count > errors,
                      let error = inty.stacks[.error]!.first as? ErrorItem, error.kind == .missingArgument else {
                    continue
                }
                t.starvations += 1
                guard let p = shortfall else { t.unclassified += 1; continue }
                made.append(p)
                count(p, into: &t)
            }
            t.programs += 1
            t.steps += inty.counter
            for element in [PushStack.int, .double, .bool, .char, .string] {
                for family in Probe.Family.allCases where made.contains(where: { fits($0, family, element) }) {
                    t.offering["\(element) \(family)", default: 0] += 1
                }
            }
        }
        return t
    }

    static func count(_ p: Partial, into t: inout Tally) {
        t.partials += p.present > 0 ? 1 : 0
        t.bare += p.present == 0 ? 1 : 0
        t.unknownOutput += p.outputs.isEmpty ? 1 : 0
        t.holeCounts[min(p.holes.values.reduce(0, +), 4), default: 0] += 1
        for output in p.outputs { t.outputs["\(output)", default: 0] += 1 }
        let holes = p.holes.keys.sorted { $0.rawValue < $1.rawValue }
            .map { stack in Array(repeating: "\(stack)", count: p.holes[stack]!).joined(separator: ", ") }
        let output = p.outputs.isEmpty ? "?" : p.outputs.map { "\($0)" }.sorted().joined(separator: "+")
        t.signatures["(" + holes.joined(separator: ", ") + ") → " + output, default: 0] += 1
    }

    @Test(.enabled(if: FunctionOutcomeProbe.enabled))
    func `what would starved instructions make`() throws {
        let programs = Int(ProcessInfo.processInfo.environment["PUSH_FUNCTION_PROBE_PROGRAMS"] ?? "") ?? 300
        var text = "# Starvation function census\n\n\(programs) programs per regime, as in the function outcome probe. "
        text += "Each missing-arguments refusal is read as the function it could push: the instruction, the "
        text += "arguments present (bound), a hole for each one missing.\n"
        for regime in Probe.Regime.allCases {
            text += "\n## \(regime.rawValue)\n" + Self.render(Self.census(regime, programs: programs))
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "starvation-function-census.md")
        try text.write(to: url, atomically: true, encoding: .utf8)
        print(text)
    }

    static func render(_ t: Tally) -> String {
        let percent = FunctionOutcomeProbe.percent
        let mean = BlockFunctionCensus.mean
        var text = "\n\(t.starvations) starvations in \(t.steps) steps (\(mean(t.starvations, t.programs)) per "
        text += "program, \(percent(t.starvations, t.steps)) of steps); \(t.unclassified) not readable from the "
        text += "signature. Of the rest, \(t.partials) found some arguments, \(t.bare) found none (the bare "
        text += "instruction); \(t.unknownOutput) have an output not fixed by the signature.\n\n"
        text += "Holes per function: " + (1...4).map { "\($0 == 4 ? "4+" : "\($0)"): \(t.holeCounts[$0] ?? 0)" }
            .joined(separator: ", ") + ".\n\nOutputs: "
        text += t.outputs.sorted { $0.value > $1.value }.prefix(8).map { "\($0.key) \($0.value)" }
            .joined(separator: ", ") + ".\n\n"
        text += "| family | natural firings on a collection | a fitting function already made |\n|---|---:|---:|\n"
        for family in Probe.Family.allCases {
            let fired = t.firings["\(family)"] ?? 0, served = t.served["\(family)"] ?? 0
            text += "| \(family) | \(fired) | \(served) (\(percent(served, fired))) |\n"
        }
        text += "\n| element | programs offering a map | a filter | a reduce |\n|---|---:|---:|---:|\n"
        for element in [PushStack.int, .double, .bool, .char, .string] {
            let cells = Probe.Family.allCases.map { percent(t.offering["\(element) \($0)"] ?? 0, t.programs) }
            text += "| \(element) | " + cells.joined(separator: " | ") + " |\n"
        }
        text += "\n| signature | count |\n|---|---:|\n"
        text += t.signatures.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(15)
            .map { "| `\($0.key)` | \($0.value) |" }.joined(separator: "\n") + "\n"
        return text
    }
}
