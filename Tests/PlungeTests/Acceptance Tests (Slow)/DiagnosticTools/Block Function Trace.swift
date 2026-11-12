//
//  Block Function Trace.swift
//  PlungeTests
//
//  One block converted step by step, printing the sandbox's stacks, the holes
//  supplied and the functions read after each step. A teaching aid for the
//  function-stack design; run solo:
//
//      PUSH_FUNCTION_PROBE=1 swift test --filter BlockFunctionTrace
//

import Testing
@testable import Plunge

@Suite
struct BlockFunctionTrace {

    typealias Probe = FunctionOutcome

    @Test(.enabled(if: FunctionOutcomeProbe.enabled))
    func `trace one conversion`() {
        var constants: [PushInstruction: any Item] = [:]
        for (i, n) in [4, 9, 7, 2, 6, 1, 8, 3, 5, 0].enumerated() {
            constants[PushInstruction(rawValue: "int\(i)")!] = IntItem(n)
        }
        let inputs: [PushInstruction: any Item] = [.input0: StringItem("dog"), .input1: IntItem(10)]
        let blocks: [[any Item]] = [
            [InstructionItem(.input3), InstructionItem(.int2), InstructionItem(.intAdd),
             InstructionItem(.input1), InstructionItem(.intGT), InstructionItem(.boolNot)],
            // Bindings: a local variable, a key the parent made, a binding taken apart.
            [InstructionItem(.intRef), InstructionItem(.bindingDeref), InstructionItem(.intAdd)],
            [IntItem(12), InstructionItem(.bindingDeref)],
            [InstructionItem(.bindingUnpack)]
        ]
        for block in blocks {
            print("\n==== " + Probe.render(CodeItem(block)))
            print(Self.trace(CodeItem(block), inputs: inputs, constants: constants))
        }
    }

    static func trace(_ block: CodeItem, inputs: [PushInstruction: any Item],
                      constants: [PushInstruction: any Item]) -> String {
        let used = Probe.tokens(in: block.value)
        var registry = Probe.HoleRegistry(avoiding: used, constants: constants)
        let blockConstants = used.filter { constants[$0] != nil }
        let sub = Self.sandbox(block, inputs: inputs, constants: constants)
        var names: [PushInstruction: String] = [:]
        func show(_ item: any Item) -> String {
            if item.call.count == 1, let hole = registry.hole(item.call[0]) {
                return Probe.render(item) + "⟨" + (names[hole.marker] ?? "?") + "⟩"
            }
            return Probe.render(item)
        }
        func stacks() -> String {
            [PushStack.exec, .int, .bool, .binding, .error].map { stack in
                "    \(stack): [" + sub.stacks[stack]!.map(show).joined(separator: ", ") + "]"
            }.joined(separator: "\n")
        }
        var text = "start\n" + stacks() + "\n"
        var counts: [PushStack: Int] = [:]
        while sub.counter < sub.config.stepLimit, let next = sub.stacks[.exec]!.first {
            text += "\nstep \(sub.counter + 1): " + Probe.render(next)
            if let token = (next as? InstructionItem)?.value {
                let before = registry.made
                _ = Probe.supplyHoles(for: token, in: sub, registry: &registry)
                for hole in registry.holes.values where names[hole.marker] == nil {
                    let n = counts[hole.stack, default: 0]
                    names[hole.marker] = "\(hole.stack)\(n)"
                    counts[hole.stack] = n + 1
                }
                if registry.made > before { text += "   (holes supplied: \(registry.made - before))\n" + stacks() }
            }
            let before = Dictionary(uniqueKeysWithValues: Probe.holeStacks.map {
                ($0, sub.stacks[$0]!.map(Probe.fingerprint))
            })
            sub.step()
            text += "\n  after\n" + stacks() + "\n"
            guard !Probe.rearranges(next) else { continue }
            for stack in Probe.holeStacks {
                for item in Probe.fresh(before[stack]!, Array(sub.stacks[stack]!)) {
                    var one = Probe.Conversion()
                    Probe.read(item, on: stack, registry, blockConstants, into: &one)
                    let crux = Self.crux(of: item, registry, names)
                    let verdict = one.functions.first.map { "FUNCTION \($0.signature)" }
                        ?? (one.bareHoles > 0 ? "bare hole, not kept" : "no hole, not kept")
                    text += "  pushed \(show(item)) on .\(stack); crux: \(crux)  → \(verdict)\n"
                }
            }
        }
        return text
    }

    /// A recording sandbox loaded with `block`, as a conversion's.
    static func sandbox(_ block: CodeItem, inputs: [PushInstruction: any Item],
                        constants: [PushInstruction: any Item]) -> Interpreter {
        let sub = Interpreter()
        sub.config = Interpreter.defaultSettings
        sub.config.recordsProvenance = true
        sub.config.stepLimit = 100
        sub.load(inputs: inputs, constants: constants, program: block.value)
        return sub
    }

    /// `item`'s crux, with each hole written by its name.
    static func crux(of item: any Item, _ registry: Probe.HoleRegistry,
                     _ names: [PushInstruction: String]) -> String {
        guard let body = CruxSharing.crux(of: item, limit: 300) else { return "(too long)" }
        return body.map { leaf in
            if let hole = registry.hole(leaf) { return "⟨\(names[hole.marker] ?? "?")⟩" }
            return Probe.render(leaf)
        }.joined(separator: " ")
    }
}
