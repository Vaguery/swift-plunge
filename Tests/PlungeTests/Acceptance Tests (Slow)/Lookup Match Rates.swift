//
//  Lookup Match Rates.swift
//  PlungeTests
//
//  Measures how often pattern lookups
//  find something in the stacks random programs actually build. Each attempt
//  is one of three outcomes:
//  - hit: a match was found and copied;
//  - miss: there was a probe and something below it, and nothing matched;
//  - starved: there was nothing to search (no probe, nothing below it, or no
//    start index for a `…From`).
//  The prediction: Nearest hits most, then Prefix, Containing and
//  Equal. A dictionary type would sit below all of them.
//

@testable import Plunge
import Testing

@Suite @MainActor
struct LookupMatchRates {

    struct Tally { var hit = 0, miss = 0, starved = 0 }

    /// The stack each lookup searches, read off its declared output.
    static let searched: [PushInstruction: PushStack] = {
        var result: [PushInstruction: PushStack] = [:]
        for name in Interpreter.lookupBehaviors.keys {
            guard case .results(let stacks) = Interpreter.language[name]!.produces else { continue }
            result[name] = stacks.first { $0 != .int } ?? .int
        }
        return result
    }()

    static func kind(_ name: PushInstruction) -> String {
        let raw = name.rawValue.replacingOccurrences(of: "From", with: "")
        for kind in ["Nearest", "Prefix", "Containing", "Shape", "Equal"] where raw.hasSuffix(kind) { return kind }
        return "?"
    }

    @Test func `how often lookups find something in random programs`() {
        let lookups = Array(Self.searched.keys).sorted { $0.rawValue < $1.rawValue }
        let mix = InstructionMix([.constant: 2, .input: 1, .stackFamily: 1, .comparison: 1, .other: 2],
                                 focus: lookups, weight: 1.5)
        var byInstruction: [PushInstruction: Tally] = [:]

        for seed in 0..<300 {
            let inty = Interpreter()
            withFuzzSeed(UInt64(seed)) {
                RandomCode.setRandomConstants(in: inty)
                inty.load(program: RandomCode.randomProgram(120, mix: mix))
            }
            inty.config.stepLimit = 2_000
            while inty.counter < inty.config.stepLimit, let next = inty.stacks[.exec]!.first {
                guard let instruction = (next as? InstructionItem)?.value, let stack = Self.searched[instruction] else {
                    inty.step()
                    continue
                }
                // What there is to search once a start index (for `…From`) is taken.
                let takesStart = instruction.rawValue.hasSuffix("From")
                let before = inty.stacks[stack]!.count
                var depth = before, start = 1
                if takesStart {
                    if let first = inty.stacks[.int]!.first as? IntItem {
                        start = max(1, first.value)
                        if stack == .int { depth -= 1 }
                    } else {
                        depth = 0
                    }
                }
                let searchable = depth >= 2 && start < depth
                inty.step()
                // A hit always leaves the searched stack deeper than it was.
                let grew = inty.stacks[stack]!.count > before
                if grew {
                    byInstruction[instruction, default: Tally()].hit += 1
                } else if searchable {
                    byInstruction[instruction, default: Tally()].miss += 1
                } else {
                    byInstruction[instruction, default: Tally()].starved += 1
                }
            }
        }

        var byKind: [String: Tally] = [:]
        for (name, tally) in byInstruction {
            byKind[Self.kind(name), default: Tally()].hit += tally.hit
            byKind[Self.kind(name), default: Tally()].miss += tally.miss
            byKind[Self.kind(name), default: Tally()].starved += tally.starved
        }
        func line(_ label: String, _ t: Tally) -> String {
            let attempts = t.hit + t.miss + t.starved
            let searched = t.hit + t.miss
            let hitRate = searched == 0 ? 0 : 100 * Double(t.hit) / Double(searched)
            return "\(label): \(attempts) attempts, \(t.starved) starved, \(t.hit) hits of \(searched) searches"
                + " (\(hitRate.formatted(.number.precision(.fractionLength(0))))%)"
        }
        print("lookup match rates, 300 random programs:")
        for kind in ["Nearest", "Prefix", "Containing", "Shape", "Equal"] {
            if let tally = byKind[kind] { print("  " + line(kind, tally)) }
        }
        for name in byInstruction.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            print("    " + line(name.rawValue, byInstruction[name]!))
        }

        // Nearest misses only when it can measure nothing: it should hit on
        // (nearly) every search it can make.
        let nearest = byKind["Nearest"] ?? Tally()
        #expect(nearest.hit + nearest.miss > 0)
        #expect(Double(nearest.hit) >= 0.95 * Double(nearest.hit + nearest.miss))
    }
}
