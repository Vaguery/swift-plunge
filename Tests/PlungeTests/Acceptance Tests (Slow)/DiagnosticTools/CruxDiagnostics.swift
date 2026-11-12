//
//  CruxDiagnostics.swift
//  PlungeTests — DiagnosticTools
//
//  **Does one item's crux honor its claim, and if not, how does it fail?**
//
//  This is the single place that re-runs a crux and judges the result. Everything
//  else in DiagnosticTools is about *finding* items worth asking about (CruxSweep),
//  *attributing* a failure to the instruction that caused it (RootCauseFinder), or
//  *summarizing* many answers (CruxFailureReport). The judging happens here, once,
//  so a change to what "broken" means lands in one file.
//
//  ## Why a verdict rather than an optional String
//
//  The obvious signature — return nil when fine, a reason when broken — hides a
//  third outcome that matters, and hiding it caused a real false alarm. A crux is
//  `crux()` flattening a call *DAG* into a postfix program, re-emitting a shared
//  node once per path, so it is routinely far longer than the run that built it: a
//  loop folding an accumulator leaves one body-copy per pass. Re-run under the
//  original `stepLimit` it gets cut off mid-way, and comparing the item against a
//  half-finished stack reports a bug that is not there. That was **93 of the 95
//  failures** first filed as issue #27, every one of which reproduces correctly
//  given room to finish.
//
//  So a reconstruction that does not finish is judged separately from one that
//  ran and gave the wrong answer. What to do about it is `HaltPolicy`: either
//  report `.inconclusive` (safe, but an unchecked claim then looks exactly like a
//  passing one in a tally — silence), or flush the un-executed `.exec` remainder
//  and judge what is there, with any failure annotated as possibly a budget
//  artifact. The remainder never ran and cannot be replicated after the fact, so
//  keeping it serves nothing either way.
//
//  Whichever is chosen, **count the inconclusives** — `CruxFailureReport` does, and
//  a sweep with many of them is quieter than its pass count suggests.
//

import DequeModule
import Foundation
@testable import Plunge


/// How a crux failed to honor its claim. The four are genuinely different
/// diagnoses, and lumping them together makes a sweep much harder to read: a
/// hundred `.debris` findings are usually one bug, a hundred `.wrongValue`
/// findings usually are not.
enum CruxFailureKind: String, CaseIterable, Sendable {
    /// The crux ran to completion and left nothing on the item's resting stack.
    /// Typically a refusal upstream — a guard rejected something the crux pushed,
    /// so the instruction that needed it found no argument. Check `.error`.
    case producedNothing = "produced nothing"

    /// Something came to rest, but not this item's value. The classic
    /// wrong-instruction record (`charGTE` recording `.charGT`), and the reason
    /// re-running beats reading the code.
    case wrongValue = "wrong value"

    /// The value came back, but the reproduction's own crux differs from the one
    /// that produced it — so "the crux" is not well defined for this item.
    case notAFixedPoint = "not a fixed point"

    /// The value came back on top of litter. Invisible to any check that reads
    /// only `.first`, and harmless until the fragment is embedded as an argument,
    /// at which point the litter shifts every argument position of the enclosing
    /// instruction, breaking the composition invariant.
    case debris = "debris"
}


/// What to do when a reconstruction does not finish.
///
/// The unexecuted remainder on `.exec` is program text that never ran. It is not
/// part of any item's history and **there is no way to replicate it ex post
/// facto**, so leaving it in place cannot help: it is neither a result to compare
/// nor debris the fragment produced.
///
/// The two policies differ in what they do about that, and the trade is real:
///
/// - `.reportInconclusive` refuses to judge. Safe, because the values on the other
///   stacks are half-computed and comparing them reports bugs that are not there —
///   that is exactly how 93 non-bugs became issue #27. Costs *silence*: an
///   unchecked claim looks identical to a passing one in a tally.
/// - `.flushExecAndJudge` clears `.exec` and judges what is there, annotating any
///   failure so a truncated run is never mistaken for a provenance bug. No
///   silence, at the price of failures that may be artifacts of the budget.
///
/// **The choice is currently moot**: at `stepScale` 20 — and, measured, even at 1 —
/// no reconstruction in a 15,138-claim sweep failed to finish. It matters only if
/// cruxes grow faster than the budget, which is what loops do.
enum HaltPolicy: Sendable {
    case reportInconclusive
    case flushExecAndJudge
}


/// What asking cost, and what came back.
enum CruxVerdict: Sendable {
    /// The claim holds: right value, on the right stack, a fixed point, no litter.
    case holds

    /// Nothing is known. The reconstruction did not finish, so there is no stack
    /// state worth judging. **Not** a synonym for `.holds` — see the file note.
    case inconclusive(String)

    /// The claim is false, and this is how.
    case broken(CruxFailureKind, String)

    var isBroken: Bool { if case .broken = self { true } else { false } }
    var isInconclusive: Bool { if case .inconclusive = self { true } else { false } }

    /// The human-readable half of a `.broken` or `.inconclusive` verdict.
    var explanation: String? {
        switch self {
        case .holds:                     nil
        case .inconclusive(let why):     why
        case .broken(_, let why):        why
        }
    }
}


/// Re-run one item's crux on a fresh interpreter and judge what happens.
///
/// Returns `.holds` when there is nothing to check as well as when the check
/// passes: an empty `call` means the item is a literal, and a literal reproduces
/// itself trivially; an item with no resting stack is an instruction token, which
/// executes rather than coming anywhere to rest to be compared.
///
/// ## The two budgets, and why neither is the program's
///
/// **Steps** are sized by the crux, not by the run that produced it, for the
/// DAG-flattening reason in the file note. `stepScale` is the multiplier; 20 is
/// generous enough that nothing legitimate has needed more, and it is a parameter
/// so a sweep chasing a suspected non-termination can lower it deliberately.
///
/// **Size caps** come from `InterpreterSettings.reconstructing`, which relaxes
/// them. Those caps bound a *population* run — they are a throughput compromise,
/// not a semantic one — and a reconstruction is one individual explaining itself.
/// Without the relaxation the interpreter refuses its own reconstruction: an
/// `IteratorItem` may hold an origin larger than `maxCodePoints`, because
/// `SizeLimits.overflow(of:)` only measures `flatSize` when the item *is* a
/// `CodeItem`, but rebuilding pushes that origin through `.code` where the cap
/// does apply.
///
/// Some settings deliberately do not relax, because each would change what the
/// replay *computes* rather than what it may hold — `maxCallWeight`, the depth
/// caps and `stepLimit`. The reasons are on
/// `InterpreterSettings.reconstructing`.
func inspectCrux(
    of item: any Item,
    inputs: [PushInstruction: any Item],
    constants: [PushInstruction: any Item],
    settings: InterpreterSettings,
    stepScale: Int = 20,
    onHalt: HaltPolicy = .flushExecAndJudge
) -> CruxVerdict {
    guard !item.call.isEmpty else { return .holds }
    guard let resting = PushStack.defaultStack(for: item) else { return .holds }

    let crux = item.crux()
    // A folded loop (`seed ( body ) K .execDoTimes`) is short but runs long, so
    // the budget follows the steps the crux takes, not its length.
    let room = max(settings.stepLimit, CruxCompression.replaySteps(crux) * stepScale)
    let redo = Interpreter.recordingProvenance()
    redo.config = settings.reconstructing
    redo.config.stepLimit = room
    redo.load(inputs: inputs, constants: constants, program: crux)
    redo.run(stepLimit: room)

    // Whatever is left on `.exec` never ran, so it is not a result and not debris.
    // Either refuse to judge, or clear it and judge — carrying a caveat so a
    // budget artifact can never be read as a provenance bug. See `HaltPolicy`.
    var truncated = false
    if !redo.stacks[.exec]!.isEmpty {
        switch onHalt {
        case .reportInconclusive:
            return .inconclusive(
                "reconstruction unfinished: \(crux.count)-item crux still had "
                + "\(redo.stacks[.exec]!.count) on .exec after \(room) steps")
        case .flushExecAndJudge:
            truncated = true
            redo.stacks[.exec]!.removeAll()
        }
    }
    /// Appended to any failure from a truncated run, so the caveat travels with
    /// the finding rather than living in the reader's memory.
    let caveat = truncated
        ? " ⚠︎ RECONSTRUCTION WAS TRUNCATED at \(room) steps and .exec flushed —"
          + " this may be a step-budget artifact rather than a provenance bug;"
          + " re-check with a larger stepScale before believing it"
        : ""

    guard let reproduced = redo.stacks[resting]!.first else {
        return .broken(.producedNothing, "crux produced nothing on .\(resting)" + caveat)
    }
    guard reproduced.pretty() == item.pretty() else {
        return .broken(.wrongValue,
                       "crux produced \(reproduced.pretty()), wanted \(item.pretty())" + caveat)
    }
    // Idempotence: re-running a reconstruction must reconstruct the same way, or
    // the crux is not a fixed point and "the crux" is not well defined.
    let again = CodeItem(reproduced.crux()).pretty()
    guard again == CodeItem(crux).pretty() else {
        return .broken(.notAFixedPoint,
                       "crux is not a fixed point: re-running it yields \(again)" + caveat)
    }
    // The composition invariant. `.error` is ignored — a crux may legitimately
    // re-raise — and `.exec` is known drained by the guard above. What the load
    // itself puts on a stack (the inputs' bindings on `.binding`) is the environment,
    // not debris.
    let baseline = loadedBaseline(inputs: inputs, constants: constants)
    var debris: [String] = []
    for stack in PushStack.allStacks where stack != .error {
        let found = redo.stacks[stack]!.count
        let wanted = baseline[stack, default: 0] + ((stack == resting) ? 1 : 0)
        if found != wanted { debris.append(".\(stack) holds \(found), wanted \(wanted)") }
    }
    if !debris.isEmpty {
        return .broken(.debris, "crux leaves debris — " + debris.joined(separator: "; ") + caveat)
    }
    return .holds
}


/// How many items each stack holds once `inputs` and `constants` are loaded and
/// nothing has run: the bindings `.binding` starts with, zero elsewhere.
func loadedBaseline(inputs: [PushInstruction: any Item],
                    constants: [PushInstruction: any Item]) -> [PushStack: Int] {
    let empty = Interpreter()
    empty.load(inputs: inputs, constants: constants, program: [])
    return Dictionary(uniqueKeysWithValues: PushStack.allCases.map { ($0, empty.stacks[$0]!.count) })
}


/// The pass/fail face of `inspectCrux`, for callers that only branch on "is this
/// broken" — chiefly `CruxFuzzTests`.
///
/// **`.inconclusive` reads as nil here**, which is correct for an assertion (an
/// unfinished reconstruction is not evidence of a bug) and misleading for an
/// investigation (it is not evidence of correctness either). Exploratory work
/// should call `inspectCrux` and count the inconclusives.
func brokenClaim(
    about item: any Item,
    inputs: [PushInstruction: any Item],
    constants: [PushInstruction: any Item],
    settings: InterpreterSettings
) -> String? {
    guard case .broken(_, let why) = inspectCrux(
        of: item, inputs: inputs, constants: constants, settings: settings
    ) else { return nil }
    return why
}
