//
//  InstructionScalingProbe.swift
//  PlungeTests — DiagnosticTools
//
//  **Which instructions get expensive when their arguments have grown as large as
//  the size limits allow?**
//
//  In a random program, an instruction's output is fed back to later instructions,
//  so arguments can grow until a size cap stops them: strings and vectors of
//  `maxStringLength`/`maxVectorLength`, blocks of `maxCodePoints`, counts in the
//  thousands. An instruction whose cost is fine on small arguments but superlinear
//  on large ones is a cost every long random run can hit. This times one execution of
//  every defined instruction on every stack filled with small items, then with items
//  at the limits, and ranks them by the large case.
//
//  It only reports. Run in release, alone:
//
//      PUSH_SCALING=1 swift test -c release --filter InstructionScalingProbe
//
//  The table is printed and written to `PUSH_SCALING_OUT` if that is set.
//

@testable import Plunge
import Testing
import Foundation
import DequeModule

@Suite
struct InstructionScalingProbe {

    nonisolated static let enabled = ProcessInfo.processInfo.environment["PUSH_SCALING"] != nil

    /// Eight items per stack, varied enough that comparisons and searches do real work.
    func stacks(large: Bool, settings: InterpreterSettings) -> StackSet {
        let n = large ? settings.maxVectorLength : 3
        let length = large ? settings.maxStringLength : 5
        var rng = ThroughputBenchmark.SeededRNG(state: large ? 0xB16 : 0x5A11)
        func word() -> String {
            String((0..<Int.random(in: 1...8, using: &rng)).map { _ in "abcde".randomElement(using: &rng)! })
        }
        func sentence(_ length: Int) -> String {
            var text = ""
            while text.count < length - 9 { text += word() + " " }
            return String(text.prefix(length))
        }
        /// A block of about `points` points, nested a few levels.
        func block(_ points: Int, depth: Int = 0) -> CodeItem {
            var items: [any Item] = []
            var used = 1
            while used < points {
                if depth < 6, points - used > 20, Int.random(in: 0..<8, using: &rng) == 0 {
                    let inner = block(min(points - used, Int.random(in: 10...(points / 4 + 10), using: &rng)), depth: depth + 1)
                    used += inner.flatSize
                    items.append(inner)
                } else {
                    items.append(Int.random(in: 0..<3, using: &rng) == 0
                                 ? IntItem(Int.random(in: 0...9, using: &rng))
                                 : InstructionItem([.intAdd, .intDup, .boolAnd, .stringConcat].randomElement(using: &rng)!))
                    used += 1
                }
            }
            return CodeItem(items)
        }
        var set = StackSet()
        for index in 0..<8 {
            set[.int]!.append(IntItem(large ? [1_000, 999, 0, -1_000, 500, 7, 1_000_000, 3][index] : [3, 2, 0, -1, 1, 4, 2, 3][index]))
            set[.double]!.append(DoubleItem(large ? 1e6 + Double(index) : 1.5 + Double(index)))
            set[.bool]!.append(BoolItem(index % 2 == 0))
            set[.char]!.append(CharItem(Character(String("abcde ".randomElement(using: &rng)!))))
            set[.string]!.append(StringItem(sentence(length)))
            set[.vecInt]!.append(VecIntItem((0..<n).map { _ in Int.random(in: -50...50, using: &rng) }))
            set[.vecDouble]!.append(VecDoubleItem((0..<n).map { _ in Double.random(in: -5...5, using: &rng) }))
            set[.vecBool]!.append(VecBoolItem((0..<n).map { _ in Bool.random(using: &rng) }))
            set[.vecString]!.append(VecStringItem((0..<n).map { _ in large ? sentence(20) : word() }))
            set[.code]!.append(block(large ? settings.maxCodePoints - 1 : 4))
            set[.iterator]!.append(IteratorItem(kind: .counting(stride: 1), origin: IntItem(0),
                                                destination: IntItem(large ? settings.stepLimit : 3),
                                                body: block(large ? 200 : 2), emits: true, cursor: 0, burial: 0))
        }
        return set
    }

    /// Median nanoseconds for one execution of `instruction` from `template`.
    func time(_ instruction: PushInstruction, from template: StackSet, settings: InterpreterSettings,
              repetitions: Int) -> Double {
        var samples: [Double] = []
        let clock = ContinuousClock()
        for _ in 0..<repetitions {
            let interpreter = Interpreter(stacks: template)
            interpreter.config = settings
            interpreter.stacks[.exec]!.prepend(InstructionItem(instruction))
            interpreter.recomputeLiveWeight()
            let start = clock.now
            interpreter.step()
            let elapsed = clock.now - start
            samples.append(Double(elapsed.components.attoseconds) / 1e9 + Double(elapsed.components.seconds) * 1e9)
            withExtendedLifetime(interpreter) {}
        }
        return samples.sorted()[samples.count / 2]
    }

    @Test(.enabled(if: InstructionScalingProbe.enabled))
    func `instruction cost at the size limits`() throws {
        var settings = InterpreterSettings()
        settings.stepLimit = 1_000
        let small = stacks(large: false, settings: settings)
        let large = stacks(large: true, settings: settings)
        let instructions = Runner().definedInstructions

        // Warm up the language table and code paths.
        for instruction in instructions.prefix(50) { _ = time(instruction, from: small, settings: settings, repetitions: 2) }

        var rows: [(name: String, small: Double, large: Double)] = []
        for instruction in instructions {
            let smallNs = time(instruction, from: small, settings: settings, repetitions: 15)
            let largeNs = time(instruction, from: large, settings: settings, repetitions: 15)
            rows.append((instruction.rawValue, smallNs, largeNs))
        }
        rows.sort { $0.large > $1.large }

        func us(_ ns: Double) -> String { (ns / 1_000).formatted(.number.precision(.fractionLength(1))) }
        let total = rows.reduce(0) { $0 + $1.large }
        var lines = ["instruction scaling: one execution, all stacks at the size limits (strings \(settings.maxStringLength),"
                     + " vectors \(settings.maxVectorLength), blocks \(settings.maxCodePoints) points) vs small items;"
                     + " median of 15, µs",
                     "", "| instruction | small µs | at limits µs | ratio |", "|---|---:|---:|---:|"]
        for row in rows.prefix(60) {
            let ratio = row.large / max(row.small, 1)
            lines.append("| \(row.name) | \(us(row.small)) | \(us(row.large)) | \(ratio.formatted(.number.precision(.fractionLength(0))))× |")
        }
        let over100 = rows.filter { $0.large > 100_000 }.count
        let over10 = rows.filter { $0.large > 10_000 }.count
        lines.append("")
        lines.append("\(rows.count) instructions; \(over10) over 10 µs and \(over100) over 100 µs at the limits;"
                     + " median at the limits \(us(rows[rows.count / 2].large)) µs; sum \(us(total)) µs")
        let report = lines.joined(separator: "\n")
        print(report)
        if let path = ProcessInfo.processInfo.environment["PUSH_SCALING_OUT"] {
            try report.write(toFile: path, atomically: true, encoding: .utf8)
        }
        #expect(!rows.isEmpty)
    }
}
