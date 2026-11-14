//
//  Crux Attribution Totals.swift
//  PlungeTests
//
//  What the attribution experiment counts, summed over every program, and its
//  report.
//

import Foundation

/// How many times something was tried, and how many times it happened.
nonisolated struct Tally {
    var tried = 0, hit = 0
    mutating func add(_ happened: Bool) {
        tried += 1
        if happened { hit += 1 }
    }
    var percent: String { tried == 0 ? "–" : String(format: "%.1f%%", 100 * Double(hit) / Double(tried)) }
    var summary: String { "\(percent) of \(tried)" }
}

/// Tallies by kind of token.
nonisolated struct KindTallies {
    var byKind: [String: Tally] = [:]
    mutating func add(_ kind: String, _ happened: Bool) { byKind[kind, default: Tally()].add(happened) }
    var total: Tally {
        byKind.values.reduce(Tally()) { Tally(tried: $0.tried + $1.tried, hit: $0.hit + $1.hit) }
    }
    var summary: String {
        byKind.sorted { $0.value.tried > $1.value.tried }.map { "\($0.key) \($0.value.percent)" }
            .joined(separator: ", ")
    }
}

nonisolated struct AttributionTotals {
    // The programs.
    var programs = 0, tokens = 0, executed = 0, steps = 0, results = 0, nontrivial = 0
    var contributing = 0, contributingExecuted = 0, contributingNeverRan = 0, silent = 0
    var silentByKind: [String: Int] = [:], contributingByKind: [String: Int] = [:]
    var chunks = 0, largestChunkShare = 0.0, sharedTokens = 0
    var unknownNodes = 0, walkedNodes = 0, elided = 0
    var pushedNodes = 0, pushedNodesInResults = 0
    var routingContributors: [String: Int] = [:], routingExample: [String: String] = [:]
    var plainSeconds = 0.0, attributedSeconds = 0.0, walkSeconds = 0.0, divergent = 0

    // Deleting one token.
    var silentDeletionChanges = KindTallies(), liveDeletionChanges = Tally()
    /// Does a result that lists the deleted token lose its value, and one that doesn't keep it?
    var dependentsLost = Tally(), othersKept = Tally(), rareDependentsLost = Tally()
    var othersKeptAfterSilent = Tally(), othersKeptAfterLive = Tally(), othersKeptByKind = KindTallies()
    /// The same, by exact crux.
    var cruxDependentsLost = Tally(), cruxOthersKept = Tally(), cruxOthersKeptByKind = KindTallies()
    var survivors: [String] = []

    // Reproducing a result.
    var cruxReplay = Tally(), sliceTop = Tally(), sliceAnywhere = Tally()
    var routedTop = Tally(), routedAnywhere = Tally(), complementTop = Tally(), complementAnywhere = Tally()
    var appendedTop = Tally(), appendedRestIntact = Tally(), prependedFound = Tally(), prependedOthers = Tally()
    var cruxLength = 0, sliceLength = 0

    // Rebuilding the final state.
    var rebuiltExactly = Tally(), rebuiltItems = Tally(), rebuildSkipped = 0
    var rebuildLength = 0, rebuildTokens = 0, rebuildSteps = 0, rebuildFailures: [String] = []

    // Results as functions of the inputs.
    var readingInputs = 0, readingInputsConstantFree = 0, inputCruxLength = 0
    var shapesPerProgram = 0, allShapes = Set<String>()
    var pushedExamined = 0, pushedReadingInputs = 0, pushedShapes = 0

    // MARK: - The report

    func per(_ count: Int) -> String { String(format: "%.1f", Double(count) / Double(max(programs, 1))) }
    func pct(_ part: Int, _ whole: Int) -> String {
        whole == 0 ? "–" : String(format: "%.1f%%", 100 * Double(part) / Double(whole))
    }
    static func counts(_ counts: [String: Int]) -> String {
        counts.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
    }
    func mean(_ total: Int, over tally: Tally) -> String {
        String(format: "%.1f", Double(total) / Double(max(tally.tried, 1)))
    }

    var report: String {
        (programLines + deletionLines + reproductionLines + rebuildLines + functionLines + timeLines)
            .joined(separator: "\n")
    }

    var programLines: [String] {
        [
            "Crux attribution over \(programs) random programs",
            "",
            "Per program (mean): \(per(tokens)) tokens, \(per(executed)) of them ran, \(per(steps)) steps,",
            "  \(per(results)) results, \(per(nontrivial)) with two or more tokens.",
            "Tokens that ran and are in some result's history: \(pct(contributingExecuted, executed)).",
            "Tokens that ran and are in none: \(pct(silent, executed)).",
            "Contributing tokens that never ran (held as data in a block): \(pct(contributingNeverRan, contributing)).",
            "Contributing tokens feeding more than one result: \(pct(sharedTokens, contributing)).",
            "Chunks per program: \(per(chunks)); the largest holds "
                + String(format: "%.0f%%", 100 * largestChunkShare / Double(max(programs, 1)))
                + " of the contributing tokens.",
            "",
            "Contributing tokens by kind: \(Self.counts(contributingByKind))",
            "Tokens that ran but contribute nothing, by kind: \(Self.counts(silentByKind))",
            "",
            "History nodes walked: \(walkedNodes); with no known step: \(unknownNodes) "
                + "(\(pct(unknownNodes, walkedNodes))); elided stand-ins met: \(elided).",
            "History nodes pushed during the runs: \(pushedNodes); still held by a final result: "
                + "\(pct(pushedNodesInResults, pushedNodes)).",
            ""
        ]
    }

    var deletionLines: [String] {
        [
            "Deleting a token that ran but contributes nothing changes the final state: "
                + "\(silentDeletionChanges.total.summary) (\(silentDeletionChanges.summary))",
            "Deleting a contributing token changes it: \(liveDeletionChanges.summary).",
            "",
            "Deleting one token that ran, per result with two or more tokens:",
            "  results that list the token lose their value: \(dependentsLost.summary)",
            "  results that don't list it keep their value: \(othersKept.summary)",
            "  results that list it, among values unique on their stack, lose it: \(rareDependentsLost.summary)",
            "  kept when the deleted token is in no history: \(othersKeptAfterSilent.percent); "
                + "in some other result's: \(othersKeptAfterLive.percent)",
            "    by kind of deleted token: \(othersKeptByKind.summary)",
            "  by exact crux: results that list the token lose their crux \(cruxDependentsLost.summary); "
                + "results that don't keep it \(cruxOthersKept.summary)",
            "    by kind of deleted token: \(cruxOthersKeptByKind.summary)",
            ""
        ]
    }

    var reproductionLines: [String] {
        [
            "Reproducing a result (\(cruxReplay.tried) sampled results):",
            "  its crux, replayed: \(cruxReplay.percent) on top of its stack",
            "  its tokens alone, in program order: \(sliceTop.percent) on top, \(sliceAnywhere.percent) anywhere",
            "  plus every structural and control token that ran: \(routedTop.percent) on top, "
                + "\(routedAnywhere.percent) anywhere",
            "  the whole program less other results' tokens: \(complementTop.percent) on top, "
                + "\(complementAnywhere.percent) anywhere",
            "  its crux after its program (runs that ended in time): \(appendedTop.percent) on top; everything else "
                + "as it was \(appendedRestIntact.percent), of \(appendedTop.tried)",
            "  its crux before its program: found \(prependedFound.percent); the program's other results found "
                + "\(prependedOthers.percent)",
            "  mean crux \(mean(cruxLength, over: cruxReplay)) items; mean token set "
                + "\(mean(sliceLength, over: cruxReplay)) tokens",
            ""
        ]
    }

    var rebuildLines: [String] {
        [
            "Rebuilding the final state from cruxes (every item's crux, stack by stack, bottom first):",
            "  exactly: \(rebuiltExactly.summary) programs (\(rebuildSkipped) skipped as too long); "
                + "items in place, from the bottom: \(rebuiltItems.percent)",
            "  length: \(rebuildLength) crux items for \(rebuildTokens) program tokens and \(rebuildSteps) steps",
            ""
        ]
    }

    var functionLines: [String] {
        [
            "Results as functions of the inputs (results with two or more tokens):",
            "  reading at least one input: \(readingInputs) (\(per(readingInputs)) a program); with no constant: "
                + "\(pct(readingInputsConstantFree, readingInputs)); mean crux "
                + String(format: "%.1f", Double(inputCruxLength) / Double(max(readingInputs, 1))) + " items",
            "  distinct abstract cruxes: \(per(shapesPerProgram)) a program; \(allShapes.count) across all programs",
            "  over every node pushed (first 3,000 a program): \(pushedExamined) examined, "
                + "\(pushedReadingInputs) reading an input, \(per(pushedShapes)) distinct abstract cruxes a program",
            ""
        ]
    }

    var timeLines: [String] {
        var lines = [
            "Time: plain runs " + String(format: "%.2f", plainSeconds) + " s; attributed runs "
                + String(format: "%.2f", attributedSeconds) + " s; walking back " + String(format: "%.2f", walkSeconds)
                + " s.",
            "Attributed runs whose final state differs from the plain run: \(divergent).",
            "",
            "Structural and control tokens found in histories:"
        ]
        for (name, count) in routingContributors.sorted(by: { $0.value > $1.value }).prefix(20) {
            lines.append("  \(name) ×\(count): \(routingExample[name] ?? "")")
        }
        return lines
    }
}
