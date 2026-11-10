//
//  Provenance Test Helpers.swift
//  PlungeTests
//
//  `recordsProvenance` is off by default. Tests that pin what a Behavior records
//  (`callString`, `crux()`, `call`, `callWeight`, the round-trip sweeps) ask for it
//  with `Interpreter.recordingProvenance()`; everything else runs with the default,
//  so its value assertions exercise the path a search actually takes.
//

@testable import Plunge
import Testing

extension Interpreter {
    /// A fresh interpreter that records provenance, for tests that check it.
    static func recordingProvenance() -> Interpreter {
        let inty = Interpreter()
        inty.config.recordsProvenance = true
        return inty
    }

    /// A copy of this interpreter's state — stacks, bindings, counters, settings —
    /// with provenance recording off. Recorders are not copied.
    func offRecordingTwin() -> Interpreter {
        let twin = Interpreter()
        twin.config = config
        twin.config.recordsProvenance = false
        twin.stacks = stacks
        twin.inputs = inputs
        twin.constants = constants
        twin.program = program
        twin.printout = printout
        twin.counter = counter
        twin.lastRunawayCheck = lastRunawayCheck
        twin.recomputeLiveWeight()
        return twin
    }

    /// Everything a run computes, as text: every stack's items (`pretty()`, which
    /// never shows provenance, plus content weight), the step counter and the
    /// printout. Two runs that differ only in provenance agree.
    ///
    /// Not `liveWeight`: behavior tests often load stacks by writing to them
    /// directly, which skips its bookkeeping, so the tested interpreter's figure is
    /// stale while a twin's is recomputed. (`Provenance Off Parity Tests` compares
    /// it, on interpreters loaded the accounted way.)
    var valueSignature: String {
        let stackLines = PushStack.allStacks.map { stack in
            "\(stack): " + stacks[stack]!.map { "\($0.pretty())#\($0.weight)" }.joined(separator: " ")
        }
        return (stackLines + ["counter \(counter)", "printout \(printout)"]).joined(separator: "\n")
    }
}

extension InterpreterSettings {
    /// Default settings with provenance recording on, for tests that read a crux.
    static var recordingProvenance: InterpreterSettings {
        var settings = InterpreterSettings()
        settings.recordsProvenance = true
        return settings
    }
}
