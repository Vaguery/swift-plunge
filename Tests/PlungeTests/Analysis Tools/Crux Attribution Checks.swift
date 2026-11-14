//
//  Crux Attribution Checks.swift
//  PlungeTests
//
//  The attribution experiment's later checks: slicing and transplanting a
//  result, rebuilding the final state, results as functions of the inputs, and
//  a small program written out.
//

import Foundation
@testable import Plunge

nonisolated extension Study {

    // MARK: - Slicing and transplanting

    /// Whether `program` leaves `r`'s value on top of its stack, and anywhere on it.
    func reproduces(_ r: Result, _ program: [any Item], room: Int) -> (top: Bool, anywhere: Bool) {
        let items = runPlain(program, stepLimit: room).stacks[r.stack]!
        let want = Self.rendered(r.item)
        return (items.first.map(Self.rendered) == want, items.contains { Self.rendered($0) == want })
    }

    mutating func reproductions(_ totals: inout AttributionTotals) {
        let routing = run.executed.filter { ["structural", "control"].contains(kind($0)) }
        let sample = tracked.filter { $0.item.weight < 10_000 }.shuffled(using: &rng).prefix(6)
        for r in sample {
            let tokens = r.attribution.tokens
            let others = union.subtracting(tokens)
            let limit = c.settings.stepLimit
            let alone = reproduces(r, CruxAttribution.sliced(c.program) { tokens.contains($0) }, room: limit)
            totals.sliceTop.add(alone.top)
            totals.sliceAnywhere.add(alone.anywhere)
            let withRouting = CruxAttribution.sliced(c.program) { tokens.contains($0) || routing.contains($0) }
            let routed = reproduces(r, withRouting, room: limit)
            totals.routedTop.add(routed.top)
            totals.routedAnywhere.add(routed.anywhere)
            let complement = reproduces(r, CruxAttribution.sliced(c.program) { !others.contains($0) }, room: limit)
            totals.complementTop.add(complement.top)
            totals.complementAnywhere.add(complement.anywhere)
            let crux = r.item.crux()
            totals.cruxLength += crux.count
            totals.sliceLength += tokens.count
            totals.cruxReplay.add(reproduces(r, crux, room: max(limit, crux.count * 20)).top)
            transplant(r, crux, &totals)
        }
    }

    /// The crux after its program, then before it.
    func transplant(_ r: Result, _ crux: [any Item], _ totals: inout AttributionTotals) {
        let room = c.settings.stepLimit + crux.count * 20
        let want = Self.rendered(r.item)
        if plain.counter < c.settings.stepLimit {
            let after = CruxAttribution.finalState(runPlain(c.program + crux, stepLimit: room))
            var rest = after
            let onTop = after[r.stack]?.first == want
            if onTop { rest[r.stack] = Array(after[r.stack]!.dropFirst()) }
            totals.appendedTop.add(onTop)
            totals.appendedRestIntact.add(rest == baseline)
        }
        let before = runPlain(crux + c.program, stepLimit: room)
        totals.prependedFound.add(before.stacks[r.stack]!.contains { Self.rendered($0) == want })
        let found = Set(PushStack.allStacks.flatMap { stack in
            before.stacks[stack]!.map { "\(stack) " + Self.rendered($0) }
        })
        for other in tracked where other.label != r.label {
            totals.prependedOthers.add(found.contains("\(other.stack) " + Self.rendered(other.item)))
        }
    }

    // MARK: - Rebuilding the final state

    func rebuild(_ totals: inout AttributionTotals) {
        let recorded = runRecording(c.program)
        var cruxes: [[any Item]] = []
        var length = 0
        for stack in PushStack.allStacks where stack != .exec && stack != .error {
            for item in recorded.stacks[stack]!.reversed() {
                cruxes.append(item.crux())
                length += cruxes.last!.count
            }
        }
        guard length <= 100_000 else { totals.rebuildSkipped += 1; return }
        totals.rebuildLength += length
        totals.rebuildTokens += table.count
        totals.rebuildSteps += plain.counter
        let got = CruxAttribution.finalState(
            CruxAttribution.rebuild(cruxes, inputs: c.inputs, constants: c.constants, settings: c.settings))
        totals.rebuiltExactly.add(got == baseline)
        var firstWrong: String?
        for (stack, want) in baseline.sorted(by: { $0.key < $1.key }) {
            let have = got[stack] ?? []
            for (w, h) in zip(want.reversed(), have.reversed()) { totals.rebuiltItems.add(w == h) }
            for _ in 0..<max(0, want.count - have.count) { totals.rebuiltItems.add(false) }
            if firstWrong == nil, want != have {
                let diff = zip(want.reversed(), have.reversed()).first { $0 != $1 }
                    .map { "\($0.0.prefix(50)) vs \($0.1.prefix(50))" } ?? "length"
                firstWrong = ".\(stack): wanted \(want.count) items, got \(have.count); first difference from the "
                    + "bottom: \(diff)"
            }
        }
        if let firstWrong, totals.rebuildFailures.count < 25 {
            totals.rebuildFailures.append("seed \(c.seed): \(firstWrong)")
        }
    }

    // MARK: - Results as functions of the inputs

    func functions(_ totals: inout AttributionTotals) {
        var shapes = Set<String>()
        for r in tracked where r.item.weight < 10_000 {
            let crux = r.item.crux()
            guard let (shape, constants) = CruxAttribution.abstractShape(crux) else { continue }
            totals.readingInputs += 1
            if constants == 0 { totals.readingInputsConstantFree += 1 }
            totals.inputCruxLength += crux.count
            shapes.insert(shape)
        }
        totals.shapesPerProgram += shapes.count
        totals.allShapes.formUnion(shapes)
        var pushedShapes = Set<String>()
        for item in run.pushed where item.weight < 10_000 && item.callWeight < 2_000 {
            totals.pushedExamined += 1
            guard let (shape, _) = CruxAttribution.abstractShape(item.crux()) else { continue }
            totals.pushedReadingInputs += 1
            pushedShapes.insert(shape)
        }
        totals.pushedShapes += pushedShapes.count
    }

    // MARK: - A small program written out

    /// The program with each token marked by the results it feeds (A, B, …), and
    /// those results' cruxes; nil for a program too large or too plain to show.
    func example() -> String? {
        guard table.count <= 40, tracked.count >= 2 else { return nil }
        var lines = ["── seed \(c.seed): \(table.count) tokens, \(run.stepTokens.count) steps ──"]
        let shown = Array(tracked.prefix(8))
        let letters = Array("ABCDEFGH")
        var marks = [String](repeating: "", count: table.count)
        for (i, r) in shown.enumerated() { for token in r.attribution.tokens { marks[token].append(letters[i]) } }
        for token in 0..<table.count {
            let indent = String(repeating: "  ", count: table.paths[token].count - 1)
            let ran = run.executed.contains(token) ? "ran" : "   "
            let item = table.items[token]
            let text = item.exactly(CodeItem.self) != nil ? "( … )" : String(item.pretty().prefix(50))
            let mark = marks[token].isEmpty ? "·" : marks[token]
            let column = mark.padding(toLength: 8, withPad: " ", startingAt: 0)
            lines.append("  " + String(format: "%3d", token) + " \(ran) \(column) " + indent + text)
        }
        for (i, r) in shown.enumerated() {
            lines.append("  \(letters[i]) = \(r.label): \(r.item.pretty().prefix(70))")
            lines.append("      crux: \(r.item.crux().map { $0.pretty() }.joined(separator: " ").prefix(160))")
        }
        return lines.joined(separator: "\n")
    }
}

nonisolated extension CruxAttribution {
    /// `program` run on `c`'s environment, recording nothing.
    static func plainRun(_ program: [any Item], _ c: DualModeStress.Case) -> Interpreter {
        let inty = Interpreter()
        inty.config = c.settings
        inty.config.recordsProvenance = false
        inty.load(inputs: c.inputs, constants: c.constants, program: program)
        inty.run()
        return inty
    }
}
