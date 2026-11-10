//
//  Constant Behavior Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 5/31/26.
//

@testable import Plunge
import Testing
import DequeModule

@Suite @MainActor
struct ConstantBehaviorTests {

    let inty = Interpreter.recordingProvenance()

    @Test func constantRecordsItsHistory() {
        inty.constants[.int2] = IntItem(17)
        Interpreter.language[.int2]!.act(on: inty)
        let result = probeItemOnStack(inty, .exec, index: 0) as! IntItem
        #expect(result.call.contains(where: {($0 as! InstructionItem).value == .int2}))
        #expect(result.value == 17)
    }

    @Test func constantWorksWhenDefined() {
        inty.constants[.int2] = IntItem(17)
        inty.constants[.vecBool8] = VecBoolItem([false, false, true])
        let constantInstruction = Interpreter.language[.int2]

        #expect(stackString(inty, .exec) == "[ ]")
        constantInstruction!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ 17 ]")
        Interpreter.language[.vecBool8]!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ [false, false, true] 17 ]")
    }

    @Test func constantWorksWhenUndefined() {
        #expect(stackString(inty, .exec) == "[ ]")
        Interpreter.language[.vecBool8]!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .error).contains("No constant assigned") )
        // As with an unbound input: the error records the instruction that
        // would reproduce it against the same environment.
        #expect(callString(topItem(inty, .error)) == "( .vecBool8 )")
    }

}
