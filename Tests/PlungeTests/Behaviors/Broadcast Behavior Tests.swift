//
//  Broadcast Behavior Tests.swift
//  PlungeTests
//
//  Broadcast vector operations (2026-11-15): `v k .op`, every element of the top
//  vector with the top scalar of its element type. And `.vecBoolXor`, the
//  element-wise exclusive or.
//

@testable import Plunge
import Testing

@Suite
struct BroadcastBehaviorTests {

    typealias Elementwise = ElementwiseBehaviorTests

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    @Test(arguments: [
        (PushInstruction.vecIntAddInt, "[ [13, 7, 10] ]"), (.vecIntSubtractInt, "[ [7, 1, 4] ]"),
        (.vecIntMultiplyInt, "[ [30, 12, 21] ]"), (.vecIntQuotInt, "[ [3, 1, 2] ]"), (.vecIntModInt, "[ [1, 1, 1] ]")
    ])
    func `int arithmetic applies the int to every element`(_ instruction: PushInstruction, _ expected: String) {
        let inty = Elementwise.run([VecIntItem([10, 4, 7]), IntItem(3), Self.op(instruction)])
        #expect(stackString(inty, .vecInt) == expected)
        #expect(inty.stacks[.int]!.isEmpty, "the int is taken")
        #expect(Elementwise.replays(inty, .vecInt))
    }

    @Test(arguments: [
        (PushInstruction.vecDoubleAddDouble, "[ [3.0, 1.0] ]"), (.vecDoubleSubtractDouble, "[ [-1.0, -3.0] ]"),
        (.vecDoubleMultiplyDouble, "[ [2.0, -2.0] ]"), (.vecDoubleDivideDouble, "[ [0.5, -0.5] ]")
    ])
    func `double arithmetic applies the double to every element`(_ instruction: PushInstruction, _ expected: String) {
        let inty = Elementwise.run([VecDoubleItem([1, -1]), DoubleItem(2), Self.op(instruction)])
        #expect(stackString(inty, .vecDouble) == expected)
        #expect(Elementwise.replays(inty, .vecDouble))
    }

    @Test func `broadcast remainders are the element-wise ones`() {
        let broadcast = Elementwise.run([VecDoubleItem([7.5, -7.5]), DoubleItem(2), Self.op(.vecDoubleModDouble)])
        let pairwise = Elementwise.run([VecDoubleItem([7.5, -7.5]), VecDoubleItem([2, 2]), Self.op(.vecDoubleMod)])
        #expect(stackString(broadcast, .vecDouble) == stackString(pairwise, .vecDouble))
    }

    @Test(arguments: [
        (PushInstruction.vecBoolAndBool, false, "[ [false, false, false] ]"),
        (.vecBoolAndBool, true, "[ [true, false, true] ]"),
        (.vecBoolOrBool, true, "[ [true, true, true] ]"),
        (.vecBoolXorBool, true, "[ [false, true, false] ]"),
        (.vecBoolXorBool, false, "[ [true, false, true] ]")
    ])
    func `logic applies the bool to every element`(_ instruction: PushInstruction, _ k: Bool, _ expected: String) {
        let inty = Elementwise.run([VecBoolItem([true, false, true]), BoolItem(k), Self.op(instruction)])
        #expect(stackString(inty, .vecBool) == expected)
        #expect(Elementwise.replays(inty, .vecBool))
    }

    @Test func `an empty vector stays empty`() {
        let inty = Elementwise.run([VecIntItem([]), IntItem(0), Self.op(.vecIntQuotInt)])
        #expect(stackString(inty, .vecInt) == "[ «vecInt []» ]")
        #expect(inty.stacks[.error]!.isEmpty, "no element is divided, so nothing is refused")
    }

    @Test func `a refusal names the index`() {
        let inty = Elementwise.run([VecIntItem([4, Int.max]), IntItem(2), Self.op(.vecIntMultiplyInt)])
        #expect(Elementwise.errorKinds(inty) == [.overflow])
        let message = (inty.stacks[.error]!.first as? ErrorItem)?.value ?? ""
        #expect(message.contains("at index 1"))
        let zero = Elementwise.run([VecIntItem([4]), IntItem(0), Self.op(.vecIntModInt)])
        #expect(Elementwise.errorKinds(zero) == [.divideByZero])
    }

    @Test func `a missing scalar starves`() {
        let inty = Elementwise.run([VecIntItem([1, 2]), Self.op(.vecIntAddInt)])
        #expect(stackString(inty, .vecInt) == "[ [1, 2] ]")
        #expect(Elementwise.errorKinds(inty).count == 1)
    }

    @Test func `xor combines adjacent vectors of bools`() {
        let inty = Elementwise.run([VecBoolItem([true, true, false]), VecBoolItem([true, false, false]),
                                    Self.op(.vecBoolXor)])
        #expect(stackString(inty, .vecBool) == "[ [false, true, false] ]")
        #expect(Elementwise.replays(inty, .vecBool))
    }
}
