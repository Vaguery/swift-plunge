//
//  RootCauseFinder.swift
//  PushInterpreterTests — DiagnosticTools
//
//  **Which instruction actually broke, as opposed to which item noticed?**
//
//  This is the tool that turned issue #27 from a statistic into three bugs, and it
//  is the one worth reaching for first.
//
//  A crux is built from its children's cruxes, so **one broken record poisons every
//  ancestor**. A sweep reporting 95 broken items is not reporting 95 bugs; it is
//  reporting one bug seen from 95 places, or a handful of bugs plus their shadows.
//  Worse, the items that surface are the *composites* — the big ones at the top of
//  a call tree, whose cruxes ran to tens of thousands of characters. Reading those
//  by eye taught me nothing across several attempts.
//
//  Walking **down** to the deepest failing node and asking what produced *that*
//  collapsed the same 95 items into six root causes in a single run:
//
//      .boolEq                     120     (all one cause — a step-budget artifact)
//      .vecDoubleReplaceFirst        9
//      .boolXor                      2
//      .iteratorFromCode             1     <- a real bug, and the last one standing
//      .iteratorFromCodeDoPoints     1     <- the same real bug
//      .vecIntReadItems              1
//
//  The counts are almost the least useful column. What mattered was that two
//  entries had a count of *one* and were the only genuine provenance failures in
//  177,779 claims. A tally by frequency would have buried them.
//

import DequeModule
import Foundation
@testable import PushInterpreter


/// A failing node with no failing descendant — the deepest point at which
/// something actually went wrong.
@MainActor
struct CruxRootCause {
    var item: any Item
    var verdict: CruxVerdict
    /// How far below the item the sweep surfaced this node was found. A large
    /// depth means the surfaced item was mostly innocent.
    var depth: Int

    /// The instruction this node's `call` names **first**.
    ///
    /// First rather than last, deliberately, and the opposite of
    /// `CruxFailureReport.byCulprit`. Law 3 records arguments before the
    /// instruction, so for a directly-produced value the first instruction in a
    /// `call` is usually the producer, while the last is often cleanup appended by
    /// `reading` or `selecting`. Producer is what you want when assigning blame;
    /// the cleanup tail is what you want when grouping by recording *shape*. Both
    /// cuts are useful, which is why the two tools disagree on purpose.
    var producer: String {
        item.call.compactMap { ($0 as? InstructionItem)?.value }
            .first.map { ".\($0)" } ?? "(no instruction in call)"
    }
}


/// Every deepest failing node under `item`, itself included.
///
/// Recurses into any child that also fails, and reports a node only when none of
/// its children do. An item that fails purely because a descendant does therefore
/// never appears — which is the whole point.
///
/// `maxDepth` is a cycle-and-cost guard. Provenance is a DAG and a shared node is
/// visited once per path, so a deep tree can be walked far more times than it has
/// nodes; 40 has been ample.
///
/// **Cost warning.** This re-runs a crux per node visited, and the nodes near the
/// root are the expensive ones. Filter to failing items before calling it — never
/// walk a whole sweep.
@MainActor
func deepestFailures(
    under item: any Item,
    inputs: [PushInstruction: any Item],
    constants: [PushInstruction: any Item],
    settings: InterpreterSettings,
    depth: Int = 0,
    maxDepth: Int = 40
) -> [CruxRootCause] {
    guard depth < maxDepth else { return [] }

    var deeper: [CruxRootCause] = []
    for child in item.call {
        guard !child.call.isEmpty,
              PushStack.defaultStack(for: child) != nil
        else { continue }
        if inspectCrux(of: child, inputs: inputs, constants: constants,
                       settings: settings).isBroken {
            deeper += deepestFailures(under: child, inputs: inputs, constants: constants,
                                      settings: settings, depth: depth + 1, maxDepth: maxDepth)
        }
    }
    guard deeper.isEmpty else { return deeper }

    let verdict = inspectCrux(of: item, inputs: inputs, constants: constants, settings: settings)
    return verdict.isBroken ? [CruxRootCause(item: item, verdict: verdict, depth: depth)] : []
}


/// Root causes across a whole sweep, tallied by producing instruction.
///
/// The intended shape of an exploratory run:
///
/// ```swift
/// let sweep = CruxSweep(seeds: CruxSweep.spacedSeeds(40), casesPerSeed: 40)
/// let causes = rootCauses(in: sweep)
/// print(rootCauseSummary(causes))
/// ```
///
/// Read the summary for *entries with small counts you do not recognize*, not for
/// the biggest number. The big entries are usually one systemic cause; the
/// singletons are where the interesting bugs were both times.
@MainActor
func rootCauses(in sweep: CruxSweep) -> [CruxRootCause] {
    var found: [CruxRootCause] = []
    sweep.forEachClaim { swept in
        guard inspectCrux(of: swept.item, inputs: swept.inputs,
                          constants: swept.constants, settings: sweep.settings).isBroken
        else { return }
        found += deepestFailures(under: swept.item,
                                 inputs: swept.inputs,
                                 constants: swept.constants,
                                 settings: sweep.settings)
    }
    return found
}


/// A legible tally of root causes by producing instruction, rarest last so the
/// singletons are easy to find.
@MainActor
func rootCauseSummary(_ causes: [CruxRootCause], examplesPerProducer: Int = 1) -> String {
    var grouped: [String: [CruxRootCause]] = [:]
    for cause in causes { grouped[cause.producer, default: []].append(cause) }

    var out = "\(causes.count) root failures across \(grouped.count) producing instructions"
    for (producer, group) in grouped.sorted(by: { $0.value.count > $1.value.count }) {
        out += "\n\n  \(producer): \(group.count)"
        for cause in group.prefix(examplesPerProducer) {
            out += "\n      depth \(cause.depth), call.count=\(cause.item.call.count)"
            out += "\n      item: \(cause.item.pretty().prefix(90))"
            out += "\n      why:  \((cause.verdict.explanation ?? "?").prefix(140))"
            out += "\n      crux: \(CodeItem(cause.item.crux()).pretty().prefix(200))"
        }
    }
    return out
}
