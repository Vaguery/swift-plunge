//
//  CruxFailureReport.swift
//  PlungeTests — DiagnosticTools
//
//  **Tally verdicts so a sweep is readable, and keep enough of each kind to act
//  on.**
//
//  A raw count is nearly useless for exploration. "95 broken" said almost nothing;
//  splitting the same 95 by *kind* said a great deal —
//
//      debris 825 -> 0     the fix landed
//      not a fixed point   74 -> 48
//      wrong value         70 -> 45
//      produced nothing    2 -> 2      untouched, so: a different bug
//
//  — because a category that does not move under a change is a category that
//  change did not address. That table is what turned one investigation into three
//  separate bugs.
//
//  Two other things this records deliberately:
//
//  - **Inconclusive claims.** A reconstruction that ran out of steps proves
//    nothing, and if it is not counted it silently reads as success. Ignoring this
//    is precisely how 93 non-bugs got filed as issue #27.
//  - **Crux length.** The correlation between failure and crux size is what
//    pointed at the step budget in the first place. Free to collect, and it has
//    already earned its keep once.
//

import DequeModule
import Foundation
@testable import Plunge


/// Accumulated verdicts from a sweep, split by kind and by culprit.
@MainActor
struct CruxFailureReport {
    /// Every claim that was actually judged — `.holds` plus `.broken`. Excludes
    /// inconclusives, because nothing was learned about those.
    private(set) var judged = 0
    private(set) var inconclusive = 0
    private(set) var broken = 0

    private(set) var byKind: [CruxFailureKind: Int] = [:]
    /// Keyed by the *last* instruction in the failing item's `call`. For a
    /// `reading`-recorded item that is the cleanup tail rather than the producing
    /// instruction, which identifies the **recording shape** — often the more
    /// useful cut, and the reason #27's tally pointed at `reading`'s same-stack
    /// branch. Treat it as a fingerprint, not an accusation:
    /// `RootCauseFinder` is what attributes blame.
    private(set) var byCulprit: [String: Int] = [:]
    private(set) var cruxLengths: [Int] = []

    /// A few failures of each kind, kept whole so there is something to work with
    /// without re-running the sweep.
    private(set) var examples: [CruxFailureKind: [Example]] = [:]
    var examplesPerKind = 3

    @MainActor
    struct Example {
        var why: String
        var itemDescription: String
        var cruxDescription: String
        var cruxLength: Int
        var seed: UInt64
        var caseId: String
        var swept: SweptItem
    }

    init() {}

    mutating func record(_ verdict: CruxVerdict, for swept: SweptItem) {
        switch verdict {
        case .inconclusive:
            inconclusive += 1
        case .holds:
            judged += 1
        case .broken(let kind, let why):
            judged += 1
            broken += 1
            byKind[kind, default: 0] += 1
            let crux = swept.item.crux()
            cruxLengths.append(crux.count)
            let culprit = swept.item.call
                .compactMap { ($0 as? InstructionItem)?.value }
                .last.map { ".\($0)" } ?? "(no instruction in call)"
            byCulprit[culprit, default: 0] += 1
            if examples[kind, default: []].count < examplesPerKind {
                examples[kind, default: []].append(Example(
                    why: why,
                    itemDescription: swept.item.pretty(),
                    cruxDescription: CodeItem(crux).pretty(),
                    cruxLength: crux.count,
                    seed: swept.seed,
                    caseId: swept.caseId,
                    swept: swept))
            }
        }
    }

    /// Median crux length among failures — the number that first suggested the
    /// step budget was the problem rather than the provenance.
    var medianFailingCruxLength: Int? {
        guard !cruxLengths.isEmpty else { return nil }
        return cruxLengths.sorted()[cruxLengths.count / 2]
    }

    /// A legible summary. `detail` includes the kept examples, truncated — pass
    /// false when sweeping repeatedly and only the shape of the tally matters.
    func summary(detail: Bool = true, cruxPrefix: Int = 220) -> String {
        var out = "\(judged) claims judged; \(broken) broken; \(inconclusive) inconclusive"
        if inconclusive > 0 {
            out += "\n  ⚠︎ \(inconclusive) reconstructions did not finish — those claims were NOT checked."
        }
        if let median = medianFailingCruxLength {
            out += "\n  median failing crux: \(median) items"
        }
        if !byKind.isEmpty {
            out += "\n\nby kind:"
            for kind in CruxFailureKind.allCases where byKind[kind] != nil {
                out += "\n  \(kind.rawValue.padding(toLength: 20, withPad: " ", startingAt: 0)) \(byKind[kind]!)"
            }
        }
        if !byCulprit.isEmpty {
            out += "\n\nby culprit (last instruction in the failing item's call):"
            for (name, n) in byCulprit.sorted(by: { $0.value > $1.value }).prefix(12) {
                out += "\n  \(name.padding(toLength: 30, withPad: " ", startingAt: 0)) \(n)"
            }
        }
        guard detail, !examples.isEmpty else { return out }
        out += "\n\nexamples:"
        for kind in CruxFailureKind.allCases {
            for e in examples[kind] ?? [] {
                out += "\n  [\(kind.rawValue)] \(e.caseId)"
                out += "\n     item: \(e.itemDescription.prefix(100))"
                out += "\n     why:  \(e.why.prefix(160))"
                out += "\n     crux (\(e.cruxLength) items): \(e.cruxDescription.prefix(cruxPrefix))"
            }
        }
        return out
    }
}
