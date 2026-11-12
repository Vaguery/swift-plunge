//
//  Sandbox Nesting Census.swift
//  PlungeTests
//
//  How often does a sandbox start another sandbox? Two things start a
//  sub-interpreter today: the 15 map/filter/reduce instructions, and
//  `vecFromIterator` with a body. This walks the probe's random programs by hand
//  and, at every spawn, shadows the nested runs it starts (one per element, with
//  the same bindings), recursively, counting spawns by depth. Then the same for
//  a derivation of each of the program's own blocks, with holes supplied (the
//  `codePushAllFunctions` sketch), where a spawner always has its arguments.
//
//  The shadow is approximate for reduce: it binds each element beside its
//  predecessor rather than the running accumulator. That changes values, not
//  whether a spawner fires.
//
//      PUSH_FUNCTION_PROBE=1 swift test --filter SandboxNestingCensus
//

import Foundation
import Testing
@testable import Plunge

@Suite
struct SandboxNestingCensus {

    typealias Probe = FunctionOutcome

    struct Tally {
        var programs = 0
        /// Spawns by the depth of the sandbox they start (1 = started by the root).
        var spawns: [Int: Int] = [:]
        /// Programs by the deepest sandbox any of their spawns reached.
        var deepest: [Int: Int] = [:]
        var blocks = 0, blocksSpawning = 0, derivationSpawns = 0
        var derivationDeepest: [Int: Int] = [:]
        /// Root-started spawns any of whose runs raised an error, and those
        /// errors by kind.
        var spawnsErring = 0
        var applicationErrors: [String: Int] = [:]
        /// Errors raised inside derivations: by an instruction that took a
        /// hole-built argument, by one that took none (by kind), or by one whose
        /// arguments its signature cannot name.
        var tainted = 0, unreadable = 0
        var clean: [String: Int] = [:]
        var blocksWithClean = 0, programsWithClean = 0
    }

    typealias Run = (program: [any Item], bindings: [PushInstruction: any Item])

    /// The runs `token` would start in `inty`, as (program, input bindings), or
    /// nil if it would not start any (missing arguments, an empty collection).
    static func nestedRuns(_ token: PushInstruction, in inty: Interpreter) -> [Run]? {
        if token == .vecFromIterator {
            guard let iterator = inty.stacks[.iterator]!.first as? IteratorItem, let body = iterator.body,
                  let items = iterator.collected(recording: .off), !items.isEmpty else { return nil }
            return items.map { ([$0] + body.value, [:]) }
        }
        guard let (family, stack) = Probe.functionInstructions[token],
              let block = inty.stacks[.code]!.first as? CodeItem,
              let collection = inty.stacks[stack]!.first, let elements = Probe.elements(of: collection),
              !elements.isEmpty else { return nil }
        if family == .reduce {
            return zip(elements, elements.dropFirst()).map { (block.value, [.input0: $0, .input1: $1]) }
        }
        return elements.map { (block.value, [.input0: $0]) }
    }

    /// A sub-interpreter as `Interpreter.run(_:binding:in:)` makes one.
    static func shadow(_ program: [any Item], _ bindings: [PushInstruction: any Item],
                       from parent: Interpreter) -> Interpreter {
        let sub = Interpreter()
        sub.config = Interpreter.defaultSettings
        sub.config.recordsProvenance = false
        sub.config.stepLimit = max(0, parent.config.stepLimit - parent.counter)
        var inputs = parent.inputs
        for (slot, value) in bindings { inputs[slot] = value }
        sub.load(inputs: inputs, constants: parent.constants, program: program)
        return sub
    }

    /// Runs `inty` to the end by hand, shadowing every spawn; returns the
    /// deepest sandbox reached. `inty` is at `depth` (0 = the root).
    static func explore(_ inty: Interpreter, depth: Int, into t: inout Tally) -> Int {
        var deepest = depth
        while inty.counter < inty.config.stepLimit, let next = inty.stacks[.exec]!.first {
            if let token = (next as? InstructionItem)?.value, let runs = nestedRuns(token, in: inty) {
                t.spawns[depth + 1, default: 0] += 1
                var erred = false
                for (program, bindings) in runs {
                    let sub = shadow(program, bindings, from: inty)
                    deepest = max(deepest, explore(sub, depth: depth + 1, into: &t))
                    for case let error as ErrorItem in sub.stacks[.error]! where depth == 0 {
                        t.applicationErrors["\(error.kind)", default: 0] += 1
                        erred = true
                    }
                }
                t.spawnsErring += erred ? 1 : 0
            }
            inty.step()
        }
        return deepest
    }

    /// A derivation of `block` with holes supplied; returns the deepest sandbox
    /// its spawns reached (1 if none: the derivation is itself a sandbox).
    static func derive(_ block: CodeItem, _ drawn: Probe.Drawn, into t: inout Tally) -> Int {
        var registry = Probe.HoleRegistry(avoiding: Probe.tokens(in: block.value), constants: drawn.constants)
        let sub = Interpreter()
        sub.config = Interpreter.defaultSettings
        sub.config.recordsProvenance = true
        sub.config.stepLimit = 100
        sub.load(inputs: drawn.inputs, constants: drawn.constants, program: block.value)
        var deepest = 1, spawned = false, cleanHere = false
        while sub.counter < sub.config.stepLimit, let next = sub.stacks[.exec]!.first {
            var touches: Bool? = false
            let errors = sub.stacks[.error]!.count
            defer {
                for case let error as ErrorItem in sub.stacks[.error]!.prefix(sub.stacks[.error]!.count - errors) {
                    switch touches {
                    case .some(true): t.tainted += 1
                    case .some(false): t.clean["\(error.kind)", default: 0] += 1; cleanHere = true
                    case .none: t.unreadable += 1
                    }
                }
            }
            if let token = (next as? InstructionItem)?.value {
                _ = Probe.supplyHoles(for: token, in: sub, registry: &registry)
                touches = takesHole(token, in: sub, registry)
                if let runs = nestedRuns(token, in: sub) {
                    spawned = true
                    t.derivationSpawns += 1
                    var inner = Tally()
                    for (program, bindings) in runs {
                        deepest = max(deepest, explore(shadow(program, bindings, from: sub), depth: 2, into: &inner))
                    }
                }
            }
            sub.step()
        }
        t.blocksSpawning += spawned ? 1 : 0
        t.blocksWithClean += cleanHere ? 1 : 0
        return deepest
    }

    /// Whether any argument `token` will take in `sub` was built from a hole;
    /// nil if its signature cannot name its arguments.
    static func takesHole(_ token: PushInstruction, in sub: Interpreter, _ registry: Probe.HoleRegistry) -> Bool? {
        guard let signature = Probe.runner.signature(of: token) else { return nil }
        var wanted = signature.consumes
        for (stack, count) in signature.reads { wanted[stack, default: 0] += count }
        for (stack, count) in signature.needs { wanted[stack] = max(wanted[stack] ?? 0, count) }
        for (stack, count) in wanted {
            for item in sub.stacks[stack]!.prefix(count) {
                if item.call.contains(where: { registry.hole($0) != nil }) { return true }
                guard let body = CruxSharing.crux(of: item, limit: 300) else { return true }
                if body.contains(where: { registry.hole($0) != nil }) { return true }
            }
        }
        return false
    }

    static func census(_ regime: Probe.Regime, programs: Int) -> Tally {
        var t = Tally()
        for seed in 0..<programs {
            let drawn = withFuzzSeed(UInt64(seed)) { Probe.draw(regime) }
            let inty = Interpreter()
            inty.config.stepLimit = Probe.budget
            inty.load(inputs: drawn.inputs, constants: drawn.constants, program: drawn.program)
            t.deepest[explore(inty, depth: 0, into: &t), default: 0] += 1
            t.programs += 1
            var programDeepest = 0
            let cleanBefore = t.blocksWithClean
            for case let block as CodeItem in drawn.program {
                t.blocks += 1
                programDeepest = max(programDeepest, derive(block, drawn, into: &t))
            }
            t.programsWithClean += t.blocksWithClean > cleanBefore ? 1 : 0
            t.derivationDeepest[programDeepest, default: 0] += 1
        }
        return t
    }

    @Test(.enabled(if: FunctionOutcomeProbe.enabled))
    func `how deep sandboxes nest`() throws {
        let programs = Int(ProcessInfo.processInfo.environment["PUSH_FUNCTION_PROBE_PROGRAMS"] ?? "") ?? 300
        var text = "# Sandbox nesting census\n\n\(programs) programs per regime, as in the function outcome probe.\n"
        for regime in Probe.Regime.allCases {
            text += "\n## \(regime.rawValue)\n" + Self.render(Self.census(regime, programs: programs))
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "sandbox-nesting-census.md")
        try text.write(to: url, atomically: true, encoding: .utf8)
        print(text)
    }

    static func errors(_ t: Tally) -> String {
        let percent = FunctionOutcomeProbe.percent
        func kinds(_ counts: [String: Int]) -> String {
            counts.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        }
        let spawns = t.spawns[1] ?? 0
        var text = "\n**Errors in applications.** \(t.spawnsErring) of \(spawns) root spawns "
        text += "(\(percent(t.spawnsErring, spawns))) had a run raise an error: " + kinds(t.applicationErrors) + ".\n\n"
        let total = t.tainted + t.unreadable + t.clean.values.reduce(0, +)
        text += "**Errors in derivations.** \(total) in all: \(t.tainted) (\(percent(t.tainted, total))) by an "
        text += "instruction that took a hole-built argument; \(t.unreadable) whose arguments the signature can't "
        text += "name; the rest took no hole: " + kinds(t.clean) + ". \(t.blocksWithClean) blocks "
        text += "(\(percent(t.blocksWithClean, t.blocks))), in \(t.programsWithClean) programs "
        text += "(\(percent(t.programsWithClean, t.programs))), raise at least one of those.\n"
        return text
    }

    static func render(_ t: Tally) -> String {
        let percent = FunctionOutcomeProbe.percent
        func row(_ counts: [Int: Int]) -> String {
            counts.keys.sorted().map { "depth \($0): \(counts[$0]!) (\(percent(counts[$0]!, t.programs)))" }
                .joined(separator: ", ")
        }
        var text = "\n**Running the programs.** Spawns by the depth of the sandbox started: "
        text += t.spawns.keys.sorted().map { "depth \($0): \(t.spawns[$0]!)" }.joined(separator: ", ")
        text += ".\n\nPrograms by the deepest sandbox reached: " + row(t.deepest) + ".\n\n"
        text += "**Deriving the programs' blocks** (each derivation is a depth-1 sandbox). \(t.blocks) blocks; "
        text += "\(t.blocksSpawning) (\(percent(t.blocksSpawning, t.blocks))) start a sandbox inside the "
        text += "derivation, \(t.derivationSpawns) spawns in all.\n\n"
        text += "Programs by the deepest sandbox any of their derivations reached: " + row(t.derivationDeepest) + ".\n"
        return text + errors(t)
    }
}
