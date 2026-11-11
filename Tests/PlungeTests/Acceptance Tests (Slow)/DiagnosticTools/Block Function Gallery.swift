//
//  Block Function Gallery.swift
//  PlungeTests
//
//  A gallery of random flat blocks, at the Fibonacci genome's block lengths, each
//  beside the functions `codePushAllFunctions` would make of it under the current
//  sketch (`Block Functions.swift`): holes for every missing argument, every push
//  whose crux uses a hole kept, in order, repeats included, under the derivation
//  limit of 100 steps. Then how derivation's cost scales with block length, up to
//  the largest block of a 500-item genome. Run solo; it writes
//  `block-function-gallery.md` to $TMPDIR:
//
//      PUSH_FUNCTION_PROBE=1 swift test --filter BlockFunctionGallery
//

import Foundation
import Testing
@testable import Plunge

@Suite @MainActor
struct BlockFunctionGallery {

    typealias Probe = FunctionOutcome

    static let derivationLimit = 100
    static let galleryLengths = [1, 2, 3, 5, 8, 13, 21]
    static let samplesPerLength = 12
    static let maxShown = 25

    /// A colored mark per hole type.
    static let marks: [PushStack: String] = [
        .int: "🟦", .double: "🟪", .bool: "🟩", .char: "🟫", .string: "🟧",
        .vecInt: "🔵", .vecDouble: "🟣", .vecBool: "🟢", .vecString: "🟠",
        .code: "⬛", .iterator: "🔶", .binding: "🔗"
    ]

    struct Sample {
        let block: CodeItem
        let situation: Probe.Situation
    }

    /// A random flat block of `length` tokens, drawn as the probe's everything
    /// regime draws a program's: uniform over the language, keeping only the
    /// input tokens it binds, with every constant set.
    static func sample(length: Int, seed: UInt64) -> Sample {
        withFuzzSeed(seed) {
            let constants = Probe.appConstants()
            let inputs = Probe.randomInputs()
            let pool = RandomCode.allInstructions.filter { !Interpreter.inputSlots.contains($0) || inputs[$0] != nil }
            let tokens: [any Item] = (0..<length).map { _ in
                InstructionItem(pool[Int.random(in: 0..<pool.count, using: &fuzzRNG)])
            }
            let block = CodeItem(tokens)
            let s = Probe.Situation(natural: false, collection: VecIntItem([]), block: block,
                                    inputs: inputs, constants: constants, stacks: [:])
            return Sample(block: block, situation: s)
        }
    }

    @Test(.enabled(if: FunctionOutcomeProbe.enabled))
    func `a gallery of blocks and their functions`() throws {
        var text = Self.header()
        for length in Self.galleryLengths {
            text += "\n## Blocks of \(length)\n\n| # | block | functions, in the order pushed |\n|---:|---|---|\n"
            for i in 0..<Self.samplesPerLength {
                let sample = Self.sample(length: length, seed: UInt64(length * 1_000 + i))
                text += Self.row(i + 1, sample)
            }
        }
        text += Self.scaling()
        let url = FileManager.default.temporaryDirectory.appending(path: "block-function-gallery.md")
        try text.write(to: url, atomically: true, encoding: .utf8)
        print("written to \(url.path())")
    }

    static func header() -> String {
        var text = "# Block function gallery\n\n"
        text += "Random flat blocks at the Fibonacci genome's block lengths, each beside the functions "
        text += "`codePushAllFunctions` would push for it under the current sketch:\n\n"
        text += "- the block is stepped in a sandbox; before each instruction, every argument it is missing is "
        text += "supplied as a **hole**;\n"
        text += "- every item pushed (to any stack but `.exec` and `.error`) whose crux uses a hole is a function of "
        text += "its holes, listed in the order pushed, repeats included;\n"
        text += "- a block that needs more than \(derivationLimit) steps is refused and yields nothing.\n\n"
        text += "Each function is shown as its signature, its body (the crux) with the holes marked, and "
        text += "**= the value** it had in the sandbox, with the holes at their first placeholders. "
        text += "*Ignores its holes* marks a function whose value did not change when its holes got two other "
        text += "sets of placeholders.\n\n"
        text += "Programs bind a uniform 1–10 inputs, from `.input0` up, to random values of random types, and set "
        text += "every constant; the values a block names are listed under it. Blocks are drawn uniformly from the "
        text += "language (864 instructions), keeping only the bound input tokens.\n\n"
        text += "⚠️ lists the errors the block raised in the sandbox: refusals its placeholders caused (an empty "
        text += "vector borrowed from a constant, a 0 divisor), or other instructions' complaints.\n\n"
        text += "**Holes:** " + PushStack.allCases.compactMap { stack in
            marks[stack].map { "\($0) \(stack)" }
        }.joined(separator: " · ") + ". A hole is written as its mark, its type and its order among the "
        text += "function's holes of that type: 🟦**int₀**, 🟦**int₁**.\n"
        return text
    }

    /// One block's row: the block and the values it names, then its functions.
    static func row(_ n: Int, _ sample: Sample) -> String {
        let s = sample.situation
        let conversion = Probe.convert(sample.block, in: s, charged: false, limit: derivationLimit)
        var left = "`" + escaped(Probe.render(sample.block)) + "`"
        let named = Probe.tokens(in: sample.block.value).filter { s.inputs[$0] != nil || s.constants[$0] != nil }
            .sorted { $0.rawValue < $1.rawValue }
        if !named.isEmpty {
            left += "<br>*where* " + named.map { token in
                let value = s.inputs[token] ?? s.constants[token]!
                return "`.\(token.rawValue)` = `" + escaped(clipped(Probe.render(value))) + "`"
            }.joined(separator: ", ")
        }
        left += "<br>*\(conversion.steps) steps, \(conversion.holesMade) holes*"
        if !conversion.errors.isEmpty {
            let shown = conversion.errors.prefix(3).map { "`" + escaped(clipped($0)) + "`" }
            let more = conversion.errors.count > 3 ? " … +\(conversion.errors.count - 3)" : ""
            left += "<br>⚠️ *sandbox errors:* " + shown.joined(separator: ", ") + more
        }

        var right: String
        if conversion.exceeded {
            right = "⛔ **refused**: over \(derivationLimit) steps"
        } else if conversion.functions.isEmpty {
            right = "— none —"
        } else {
            let shown = conversion.functions.prefix(maxShown).enumerated().map { index, f in
                "\(index + 1). " + describe(f, in: s)
            }
            right = shown.joined(separator: "<br>")
            if conversion.functions.count > maxShown {
                right += "<br>… and \(conversion.functions.count - maxShown) more"
            }
        }
        return "| \(n) | \(left) | \(right) |\n"
    }

    /// `f` as its signature, its body with the holes marked, and its value.
    static func describe(_ f: Probe.BlockFunction, in s: Probe.Situation) -> String {
        var names: [PushInstruction: String] = [:]
        var counts: [PushStack: Int] = [:]
        for hole in f.holes {
            let n = counts[hole.stack, default: 0]
            counts[hole.stack] = n + 1
            names[hole.marker] = (marks[hole.stack] ?? "⬜") + "**\(hole.stack)\(subscripted(n))**"
        }
        var pieces: [String] = []
        var run: [String] = []
        func flush() {
            if !run.isEmpty { pieces.append("`" + escaped(run.joined(separator: " ")) + "`") }
            run = []
        }
        for leaf in f.body {
            if let hole = f.hole(leaf), let name = names[hole.marker] {
                flush()
                pieces.append(name)
            } else if let token = (leaf as? InstructionItem)?.value {
                run.append("." + token.rawValue)
            } else {
                run.append(Probe.render(leaf))
            }
        }
        flush()
        let signature = "(" + f.holes.map { "\($0.stack)" }.joined(separator: ", ") + ") → \(f.output)"
        var text = "*\(signature)*: " + pieces.joined(separator: " ")
        text += " **=** `" + escaped(clipped(Probe.render(f.value))) + "`"
        if !Probe.responds(f, in: s) { text += " · *ignores its holes*" }
        return text
    }

    // MARK: - Scaling

    /// Derivation's cost by block length, up to the largest block of a
    /// 500-item genome, without the limit (up to the probe's 1,000 steps).
    static func scaling() -> String {
        let lengths = FibonacciGenome.blockLengths(forGenomeOf: 500)
        var text = "\n## How derivation scales with block length\n\n"
        let listed = lengths.map(String.init).joined(separator: ", ")
        text += "200 random blocks at each length of a 500-item genome's blocks (\(listed)), converted with a "
        text += "limit of 1,000 steps to see how many they need.\n\n"
        text += "| length | median steps | 90th pct | 99th pct | over 100 | over 1,000 (refused) "
        text += "| functions per block |\n"
        text += "|---:|---:|---:|---:|---:|---:|---:|\n"
        for length in Array(Set(lengths)).sorted() {
            var steps: [Int] = []
            var over100 = 0, refused = 0, functions = 0
            for i in 0..<200 {
                let sample = sample(length: length, seed: UInt64(1_000_000 + length * 1_000 + i))
                let c = Probe.convert(sample.block, in: sample.situation, charged: false, limit: 1_000)
                steps.append(c.steps)
                if c.steps > 100 { over100 += 1 }
                if c.exceeded { refused += 1 }
                functions += c.functions.count
            }
            steps.sort()
            let percent = FunctionOutcomeProbe.percent
            let cells = ["\(length)", "\(steps[100])", "\(steps[180])", "\(steps[198])", percent(over100, 200),
                         percent(refused, 200), BlockFunctionCensus.mean(functions, 200)]
            text += "| " + cells.joined(separator: " | ") + " |\n"
        }
        return text
    }

    static func subscripted(_ n: Int) -> String {
        String(String(n).map { "₀₁₂₃₄₅₆₇₈₉".map { $0 }[Int(String($0))!] })
    }

    static func escaped(_ text: String) -> String {
        text.replacing("|", with: "\\|").replacing("\n", with: " ")
    }

    static func clipped(_ text: String) -> String {
        text.count > 60 ? String(text.prefix(57)) + "…" : text
    }
}
