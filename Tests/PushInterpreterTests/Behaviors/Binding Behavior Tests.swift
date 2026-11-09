//
//  Binding Behavior Tests.swift
//  PushInterpreterTests
//
//  The `.binding` stack: keyed
//  bindings, keys 0…N−1 holding the inputs, fresh keys from N, binders that read
//  and leave, scoped `with` blocks, and lookups that read their key; plus
//  `xDeleteAtDepth`, the generated deletion at a depth.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct BindingBehaviorTests {

    static func run(_ program: [any Item], inputs: [PushInstruction: any Item] = [:]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    /// The first fresh key: the number of input slots.
    static let fresh = Interpreter.inputSlots.count

    /// `item` re-run from its crux against the same inputs comes back on top of
    /// `stack`, the same value.
    static func replays(_ item: any Item, on stack: PushStack,
                        inputs: [PushInstruction: any Item] = [:]) -> Bool {
        let redo = Interpreter()
        redo.load(inputs: inputs, program: item.crux())
        redo.run(stepLimit: 10_000)
        return redo.stacks[stack]!.first?.pretty() == item.pretty()
    }

    @Test func `the inputs are bound to keys 0 to N-1 at load`() {
        let inputs: [PushInstruction: any Item] = [.input0: IntItem(5), .input2: StringItem("x")]
        let inty = Self.run([], inputs: inputs)
        #expect(inty.stacks[.binding]!.map { $0.pretty() } == ["⟨2 ↦ \"x\"⟩", "⟨0 ↦ 5⟩"], "slot order, the last on top")
        #expect(Self.replays(inty.stacks[.binding]![0], on: .binding, inputs: inputs))
        #expect(Self.replays(inty.stacks[.binding]![1], on: .binding, inputs: inputs))

        let read = Self.run([IntItem(2), Self.op(.bindingDeref)], inputs: inputs)
        #expect(stackString(read, .string) == "[ \"x\" ]")
        #expect(stackString(read, .int) == "[ 2 ]", "the key is read and left")
    }

    @Test func `a binder reads its item, binds a copy to a fresh key, and pushes the key`() {
        let inty = Self.run([IntItem(7), Self.op(.intRef)])
        #expect(stackString(inty, .int) == "[ \(Self.fresh) 7 ]")
        #expect(inty.stacks[.binding]!.first!.pretty() == "⟨\(Self.fresh) ↦ 7⟩")
        #expect(Self.replays(inty.stacks[.binding]!.first!, on: .binding))

        let two = Self.run([StringItem("a"), Self.op(.stringRef), Self.op(.stringRef)])
        #expect(stackString(two, .int) == "[ \(Self.fresh + 1) \(Self.fresh) ]", "each key is new")
    }

    @Test func `rekeying assigns, shadowing the older binding without touching the input`() {
        let inputs: [PushInstruction: any Item] = [.input3: IntItem(99)]
        let inty = Self.run([IntItem(7), Self.op(.intRef), Self.op(.intPop), Self.op(.intPop),
                             IntItem(3), Self.op(.bindingRekey),
                             IntItem(3), Self.op(.bindingDeref), Self.op(.input3)], inputs: inputs)
        #expect(stackString(inty, .int) == "[ 99 7 3 ]", "the variable says 7; .input3 still says 99")
        #expect(inty.stacks[.binding]!.first!.pretty() == "⟨3 ↦ 7⟩")
        #expect(Self.replays(inty.stacks[.binding]!.first!, on: .binding, inputs: inputs))
    }

    @Test func `older bindings are reached below, and come back after an unbind`() {
        let inputs: [PushInstruction: any Item] = [.input3: IntItem(99)]
        let shadow: [any Item] = [IntItem(7), Self.op(.intRef), Self.op(.intPop), Self.op(.intPop),
                                  IntItem(3), Self.op(.bindingRekey)]
        let depth = Self.run(shadow + [IntItem(3), Self.op(.bindingKeyDepth)], inputs: inputs)
        #expect(stackString(depth, .int) == "[ 0 3 ]")

        let below = Self.run(shadow + [IntItem(3), IntItem(1), Self.op(.bindingDerefBelow)], inputs: inputs)
        #expect(stackString(below, .int) == "[ 99 3 ]", "the shadowed binding, from depth 1")

        let unbound = Self.run(shadow + [IntItem(3), Self.op(.bindingUnbind), Self.op(.bindingDeref)], inputs: inputs)
        #expect(stackString(unbound, .int) == "[ 99 3 ]")
        #expect(unbound.stacks[.binding]!.count == 1)
    }

    @Test func `a bound block runs when dereferenced, and is data when delivered`() {
        let add = CodeItem([IntItem(2), IntItem(3), Self.op(.intAdd)])
        let run = Self.run([add, Self.op(.codeRef), Self.op(.bindingDeref)])
        #expect(stackString(run, .int) == "[ 5 \(Self.fresh) ]")

        let data = Self.run([add, Self.op(.codeRef), Self.op(.codePop), Self.op(.bindingDerefToCode)])
        #expect(data.stacks[.code]!.first!.pretty() == "( 2 3 .intAdd )")

        let quoted = Self.run([DoubleItem(1.5), Self.op(.doubleRef), Self.op(.bindingDerefToCode)])
        #expect(quoted.stacks[.code]!.first!.pretty() == "( 1.5 )")
        #expect(Self.replays(quoted.stacks[.code]!.first!, on: .code))
    }

    @Test func `with binds for the length of a body, then unbinds`() {
        let body = CodeItem([Self.op(.bindingDerefToCode)])
        let inty = Self.run([IntItem(5), body, Self.op(.intWith)])
        #expect(inty.stacks[.code]!.first!.pretty() == "( 5 )", "the body saw the binding")
        #expect(inty.stacks[.binding]!.isEmpty, "and it is gone after")
        #expect(stackString(inty, .int) == "[ \(Self.fresh) 5 ]", "the item read, and its key")
        #expect(inty.stacks[.error]!.isEmpty)
    }

    @Test func `a miss refuses and consumes nothing`() {
        let inty = Self.run([IntItem(42), Self.op(.bindingDeref)])
        #expect(stackString(inty, .int) == "[ 42 ]")
        #expect(inty.stacks[.error]!.first!.pretty().contains("missing args: .binding"))

        let below = Self.run([IntItem(7), Self.op(.intRef), Self.op(.intPop), IntItem(Self.fresh), IntItem(1),
                              Self.op(.bindingDerefBelow)])
        #expect(stackString(below, .int) == "[ 1 \(Self.fresh) 7 ]", "the depth is handed back")

        let unbind = Self.run([IntItem(3), Self.op(.bindingUnbind)])
        #expect(stackString(unbind, .int) == "[ 3 ]")
        #expect(unbind.stacks[.error]!.count == 1)
    }

    @Test func `pairs to and from code`() {
        let inty = Self.run([StringItem("v"), Self.op(.stringRef), Self.op(.bindingQuote)])
        #expect(inty.stacks[.code]!.first!.pretty() == "( \(Self.fresh) \"v\" )")
        #expect(Self.replays(inty.stacks[.code]!.first!, on: .code))

        let back = Self.run([CodeItem([IntItem(4), StringItem("w")]), Self.op(.bindingFromCode)])
        #expect(back.stacks[.binding]!.first!.pretty() == "⟨4 ↦ \"w\"⟩")

        let wrong = Self.run([CodeItem([StringItem("w"), IntItem(4)]), Self.op(.bindingFromCode)])
        #expect(wrong.stacks[.binding]!.isEmpty && wrong.stacks[.error]!.count == 1)

        let literal = Self.run([BindingItem(key: 8, bound: CharItem("c"))])
        #expect(literal.stacks[.binding]!.first!.pretty() == "⟨8 ↦ 'c'⟩", "a literal pair lands on .binding")
    }

    @Test func `keys found by distance, from below, and by value`() {
        let inputs: [PushInstruction: any Item] = [.input2: IntItem(20), .input6: StringItem("s")]
        let nearest = Self.run([IntItem(5), Self.op(.bindingNearestKey)], inputs: inputs)
        #expect(stackString(nearest, .int) == "[ 6 5 ]")
        let floor = Self.run([IntItem(5), Self.op(.bindingFloorKey)], inputs: inputs)
        #expect(stackString(floor, .int) == "[ 2 5 ]")
        let none = Self.run([IntItem(1), Self.op(.bindingFloorKey)], inputs: inputs)
        #expect(stackString(none, .int) == "[ 1 ]")
        #expect(none.stacks[.error]!.count == 1)

        let byValue = Self.run([StringItem("s"), Self.op(.stringQuote), Self.op(.bindingKeyOf)], inputs: inputs)
        #expect(stackString(byValue, .int) == "[ 6 ]")
    }

    @Test func `fresh keys are a deterministic gensym, reset at every load`() {
        let inty = Self.run([Self.op(.bindingFreshKey), Self.op(.bindingFreshKey)])
        #expect(stackString(inty, .int) == "[ \(Self.fresh + 1) \(Self.fresh) ]")
        inty.load(program: [Self.op(.bindingFreshKey)])
        inty.run(stepLimit: 10)
        #expect(stackString(inty, .int) == "[ \(Self.fresh) ]")
    }

    @Test func `deletion at a depth, the depth clamped`() {
        let middle = Self.run([IntItem(1), IntItem(2), IntItem(3), IntItem(1), Self.op(.intDeleteAtDepth)])
        #expect(stackString(middle, .int) == "[ 3 1 ]")
        let deep = Self.run([StringItem("a"), StringItem("b"), IntItem(99), Self.op(.stringDeleteAtDepth)])
        #expect(stackString(deep, .string) == "[ \"b\" ]", "past the bottom deletes the bottom")
        let negative = Self.run([CharItem("a"), CharItem("b"), IntItem(-4), Self.op(.charDeleteAtDepth)])
        #expect(stackString(negative, .char) == "[ 'a' ]", "below zero deletes the top")
    }
}
