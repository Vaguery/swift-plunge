//
//  Stack Flow Probe.swift
//  PlungeTests
//
//  Created by Bill Tozier on 7/16/26.
//
//  A diagnostic, not an assertion: it drives every registered Behavior with a
//  fully seeded interpreter and reports which stacks each one leaves deeper or
//  shallower. The point is to see where a random program's items will PILE UP and
//  where they will DRY UP — which is the shape of argument starvation.
//
//  Disabled by default and run by hand, like `behaviorCoverageTest`. Re-run it
//  after adding instructions to see whether the balance moves.
//

@testable import Plunge
import Testing
import DequeModule

@Suite
struct StackFlowProbe {

    nonisolated static let disabledTests = true

    /// One plausible item per stack. Deliberately *not* minimal: strings have
    /// spaces so `stringPushAllWords` has work to do, vectors have several elements, and
    /// the iterator has a body that pushes a `.bool` — which is worth remembering
    /// when reading the results, since playing it therefore shows up as a bool
    /// producer.
    func sample(for stack: PushStack, _ n: Int) -> any Item {
        switch stack {
        case .bool:      BoolItem(n % 2 == 0)
        case .int:       IntItem(n + 2)
        case .double:    DoubleItem(Double(n) + 1.5)
        case .char:      CharItem(Character(UnicodeScalar(97 + UInt8(n % 26))))
        case .string:    StringItem(["ab cd", "ef", "gh ij"][n % 3])
        case .code:      CodeItem([IntItem(n + 1)])
        case .exec:      IntItem(n + 100)
        case .vecBool:   VecBoolItem([true, false])
        case .vecInt:    VecIntItem([n + 1, n + 2])
        case .vecDouble: VecDoubleItem([1.5, 2.5])
        case .vecString: VecStringItem(["pq", "rs"])
        case .iterator:  IteratorItem(kind: .counting(stride: 1), origin: IntItem(0),
                                      destination: IntItem(5), body: CodeItem([BoolItem(true)]),
                                      emits: true)
        case .binding:       BindingItem(key: 3, bound: IntItem(4))
        case .error:     ErrorItem("x")
        }
    }

    @Test(.disabled(if: StackFlowProbe.disabledTests))
    func `probe stack flows`() {
        var inputs: [PushInstruction: any Item] = [:]
        for i in 0..<10 { inputs[PushInstruction(rawValue: "input\(i)")!] = IntItem(i) }
        var constants: [PushInstruction: any Item] = [:]
        for s in [PushStack.int, .double, .string, .char, .vecInt, .vecDouble, .vecString, .vecBool] {
            for i in 0..<10 {
                if let n = PushInstruction(rawValue: "\(s)\(i)") { constants[n] = sample(for: s, i) }
            }
        }

        var rows: [String] = []
        for name in Interpreter.language.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            let behavior = Interpreter.language[name]!
            let inty = Interpreter()
            var initial: [PushStack: [any Item]] = [:]
            // `.exec` is left empty: seeding it would just drain into other stacks
            // when we run below, drowning every real signal. `.error` is never
            // seeded.
            for s in PushStack.allStacks where s != .error && s != .exec {
                initial[s] = (0..<6).map { sample(for: s, $0) }
            }
            inty.load(inputs: inputs, constants: constants, stacks: initial)

            let before = PushStack.allStacks.reduce(into: [PushStack: Int]()) { $0[$1] = inty.stacks[$1]!.count }
            behavior.act(on: inty)
            // Let an iterator actually deliver, so a sequence shows its output
            // rather than just the iterator it built.
            inty.run(stepLimit: 60)
            let after = PushStack.allStacks.reduce(into: [PushStack: Int]()) { $0[$1] = inty.stacks[$1]!.count }

            let deltas = PushStack.allStacks.compactMap { s -> String? in
                let d = after[s]! - before[s]!
                return d == 0 ? nil : "\(s):\(d > 0 ? "+" : "")\(d)"
            }
            let takes = behavior.parameters.map { "\($0)" }.joined(separator: ",")
            rows.append("\(name.rawValue)\t[\(takes)]\t\(deltas.joined(separator: " "))")
        }
        print("=====FLOWS=====")
        for r in rows { print(r) }
        print("=====END=====")

        // Guards the probe itself rather than the language.
        #expect(rows.count == Interpreter.language.count)
    }
}
