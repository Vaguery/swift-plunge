//
//  Typed Operation Tests.swift
//  PushInterpreterTests
//
//  The typed operation constructor (Roadmap #44): arguments declared in written
//  order, `call` and requirements derived from them, refusals routed to `.error`.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct TypedOperationTests {

    // MARK: - Written order

    /// Same stack: written deepest first, so `y x` maps to arguments 1 and 0.
    @Test func `a same-stack pair is written deepest first`() {
        let order = WrittenOrder([.int, .int])
        #expect(order.groups.map(\.stack) == [.int])
        #expect(order.positions == [1, 0])
    }

    /// Across stacks, in order of first appearance: `"abc" 2 .stringNth`.
    @Test func `different stacks keep their declared order`() {
        #expect(WrittenOrder([.string, .int]).positions == [0, 1])
    }

    /// The `vecIntSet` shape: `[1, 2] 9 0 .vecIntSet` is vector, replacement,
    /// index, which the hand-written Behavior recorded as `[x, z, y]`.
    @Test func `the vecSet shape reproduces its hand-written order`() {
        #expect(WrittenOrder([.vecInt, .int, .int]).positions == [0, 2, 1])
    }


    // MARK: - Declarations

    @Test func `a typed operation declares the stack it gives`() {
        #expect(Interpreter.language[.intAdd]?.gives == .int)
        #expect(Interpreter.language[.intGT]?.gives == .bool)
        #expect(Interpreter.language[.intFromString]?.gives == .int)
    }

    @Test func `a body that can throw is tagged fallible, and one that cannot is not`() {
        #expect(Interpreter.declaredTags(of: .intAdd).contains(.fallible))
        #expect(Interpreter.declaredTags(of: .intQuot).contains(.fallible))
        #expect(!Interpreter.declaredTags(of: .intMax).contains(.fallible))
        #expect(!Interpreter.declaredTags(of: .intGT).contains(.fallible))
    }

    @Test func `requirements come from the declared types`() {
        #expect(Interpreter.language[.intAdd]?.requirements.count == 2)
        #expect(Interpreter.language[.intGT]?.readStacks == [.int: 2])
        #expect(Interpreter.language[.intFromChar]?.consumedStacks == [.char: 1])
    }


    // MARK: - Running

    /// An interleaved declaration still reaches the right arguments, and records
    /// them as declared, which a re-run reproduces.
    @Test func `an interleaved declaration maps each argument and records it as declared`() {
        let join = Behavior.operation(.stringConcat, takes: IntItem.self, StringItem.self, IntItem.self,
                                      gives: StringItem.self) { a, s, b in "\(a)\(s)\(b)" }
        let inty = Interpreter.recordingProvenance()
        // As `1 "x" 2` would leave them: 2 on top of 1.
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(2), IntItem(1)] as [any Item])
        inty.stacks[.string]!.prepend(StringItem("x"))
        join.act(on: inty)
        #expect(stackString(inty, .string) == "[ \"1x2\" ]")
        #expect(callString(topItem(inty, .string)) == "( 1 \"x\" 2 .stringConcat )")
        #expect(stackString(inty, .int) == "[ ]")
    }

    /// A refusal is an error whose `call` is the result's would-be `call`, so its
    /// crux reproduces the refusal.
    @Test func `a refusal records the call and reproduces`() {
        let inty = Interpreter.recordingProvenance()
        loadInts(inty, ints: [0, 5])   // `5 0 .intQuot`
        doThis(.intQuot, to: inty)
        let error = topItem(inty, .error)
        #expect(error.pretty().contains("Divide by zero .intQuot: 5 / 0"))
        #expect((error as? ErrorItem)?.kind == .other)
        #expect(callString(error) == "( 5 0 .intQuot )")

        let redo = Interpreter.recordingProvenance()
        redo.load(program: error.crux())
        redo.run()
        #expect(topItem(redo, .error).pretty() == error.pretty())
    }

    /// A query leaves its operands, and its result's crux clears them.
    @Test func `a typed query leaves its operands and its crux cleans up`() {
        let inty = Interpreter.recordingProvenance()
        loadInts(inty, ints: [3, 7])   // `7 3 .intGT`
        doThis(.intGT, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .int) == "[ 3 7 ]")

        let redo = Interpreter.recordingProvenance()
        redo.load(program: topItem(inty, .bool).crux())
        redo.run()
        #expect(stackString(redo, .bool) == "[ true ]")
        #expect(stackString(redo, .int) == "[ ]")
    }
}
