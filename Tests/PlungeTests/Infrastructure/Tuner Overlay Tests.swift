//
//  Tuner Overlay Tests.swift
//  PlungeTests
//
//  Tuners as an overlay on a crux (2026-11-16): the sites found, and the crux
//  written out with chosen tuners, each once, replaying to the tuned value.
//

@testable import Plunge
import Testing

@Suite
struct TunerOverlayTests {
    static let inputs: [PushInstruction: any Item] = [.input0: DoubleItem(3), .input1: DoubleItem(-2)]

    static func top(_ program: [any Item], on stack: PushStack = .double,
                    inputs: [PushInstruction: any Item] = inputs) -> any Item {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, program: program)
        inty.run(stepLimit: 10_000)
        return inty.stacks[stack]!.first!
    }

    static func replay(_ program: [any Item], on stack: PushStack = .double,
                       inputs: [PushInstruction: any Item] = inputs) -> Double? {
        let redo = Interpreter()
        redo.config = redo.config.reconstructing
        redo.load(inputs: inputs, program: program)
        redo.run(stepLimit: 100_000)
        let item = redo.stacks[stack]!.first
        return item?.exactly(DoubleItem.self)?.value ?? item?.exactly(IntItem.self).map { Double($0.value) }
    }

    static func ins(_ names: PushInstruction...) -> [any Item] { names.map { InstructionItem($0) } }
    static func count(_ name: PushInstruction, in program: [any Item]) -> Int {
        program.reduce(0) { total, item in
            total + ((item as? CodeItem).map { count(name, in: $0.value) }
                ?? (item.exactly(InstructionItem.self)?.value == name ? 1 : 0))
        }
    }

    @Test func `each input slot is one site, however often it is read; constants are not sites`() {
        // x·x + y + 2.5
        let item = Self.top(Self.ins(.input0, .input0, .doubleMultiply, .input1, .doubleAdd) + [DoubleItem(2.5)]
                            + Self.ins(.doubleAdd))
        let overlay = item.distilledCrux().tunerOverlay
        #expect(overlay.sites.map(\.label) == [".input0", ".input1"])
        #expect(overlay.sites.allSatisfy { $0.stack == .double })
    }

    @Test func `neutral is the crux itself, and a setting replays to the tuned value`() {
        let item = Self.top(Self.ins(.input0, .input0, .doubleMultiply, .input1, .doubleAdd))
        let overlay = item.distilledCrux().tunerOverlay
        #expect(Self.replay(overlay.program) == 7)
        #expect(Self.replay(overlay.program([0: .neutral, 1: .neutral])) == 7)
        // x → 2x + 1 on both reads: (2·3 + 1)² + (−2) = 47.
        let tuned = overlay.program([0: TunerOverlay.Setting(scale: 2, offset: 1)])
        #expect(Self.replay(tuned) == 47)
        // Each read of x carries the tuner: two multiplies of x, plus x·x's own.
        #expect(Self.count(.doubleMultiply, in: tuned) == 3)
    }

    @Test func `a value used twice is tuned once, where it is made`() {
        // ⌊x⌋ dup min: the floor is one node, used twice.
        let item = Self.top(Self.ins(.input0, .doubleFloor, .doubleDup, .doubleMin))
        let overlay = item.distilledCrux().tunerOverlay
        let tuned = overlay.program([0: TunerOverlay.Setting(scale: 2, offset: 0.5)])
        #expect(Self.count(.doubleMultiply, in: tuned) == 1)
        #expect(Self.replay(tuned) == 6)      // ⌊2·3 + 0.5⌋ = 6
    }

    @Test func `an observed value is a site of its own`() {
        // The depth of .double, observed: 2.
        let depth = Self.top([DoubleItem(1), DoubleItem(2)] + Self.ins(.doubleStackDepth), on: .int)
        let overlay = depth.distilledCrux().tunerOverlay
        #expect(overlay.sites.count == 1)
        #expect(overlay.sites.first?.stack == .int)
        if case .observation(let source) = overlay.sites.first?.kind { #expect(source == .doubleStackDepth) }
        let tuned = overlay.program([0: TunerOverlay.Setting(scale: 3, offset: 1)])
        #expect(Self.replay(tuned, on: .int) == 7)   // 3·2 + 1
    }

    @Test func `a loop's body is written once, with the tuner where the input is read`() {
        // x, then five passes of `1.5 .doubleMultiply`.
        let item = Self.top(Self.ins(.input0) + [IntItem(5), CodeItem([DoubleItem(1.5)] + Self.ins(.doubleMultiply))]
                            + Self.ins(.execDoTimes))
        let overlay = item.distilledCrux().tunerOverlay
        #expect(overlay.sites.map(\.label) == [".input0"])
        let tuned = overlay.program([0: TunerOverlay.Setting(scale: 1, offset: 1)])
        #expect(Self.count(.execDoTimes, in: tuned) == 1)
        let expected = 4 * 1.5 * 1.5 * 1.5 * 1.5 * 1.5
        #expect(abs((Self.replay(tuned) ?? 0) - expected) < 1e-9)
    }
}
