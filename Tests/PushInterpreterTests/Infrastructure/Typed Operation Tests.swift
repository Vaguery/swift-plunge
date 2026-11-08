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


    // MARK: - The item-level forms

    /// `assembling`: the body sees the items, so the result's elements record where
    /// they came from — here, each from its position in one of the two inputs.
    @Test func `assembling records the origins the body names`() {
        let join = Behavior.assembling(.vecIntConcat, takes: VecIntItem.self, VecIntItem.self,
                                       gives: VecIntItem.self) { y, x in
            Built(y.value + x.value, members: y.origins(0) + x.origins(1))
        }
        #expect(join.gives == .vecInt)
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem([3]), VecIntItem([1, 2])] as [any Item])
        join.act(on: inty)
        let result = topItem(inty, .vecInt) as! VecIntItem
        #expect(result.value == [1, 2, 3])
        #expect(callString(result) == "( [1, 2] [3] .vecIntConcat )")
        #expect(result.members?.count == 3, "one origin per element")
    }

    /// `extracting`: an element with no history of its own is built with the
    /// instruction's `call`; an empty container refuses with that same `call`.
    @Test func `extracting builds an untraced element and refuses an empty container`() {
        let first = Behavior.extracting(.vecIntFirst, takes: VecIntItem.self) { v throws(Refusal) in
            guard !v.value.isEmpty else { throw Refusal("Empty vector in .vecIntFirst", kind: .emptyCollection) }
            return Extraction(v, at: 0)
        }
        #expect(first.gives == .int)
        #expect(first.tags.contains(.fallible))

        let inty = Interpreter.recordingProvenance()
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem([7, 8]), VecIntItem([])] as [any Item])
        first.act(on: inty)
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(callString(topItem(inty, .int)) == "( [7, 8] .vecIntFirst )")

        first.act(on: inty)
        #expect((topItem(inty, .error) as? ErrorItem)?.kind == .emptyCollection)
        #expect(callString(topItem(inty, .error)) == "( [] .vecIntFirst )")
    }

    /// `splitting`: two results, the first deepest, each recording the selecting
    /// crux that surfaces it alone (provenance law 5); declared as two results.
    @Test func `splitting gives each piece its selecting crux`() {
        let halve = Behavior.splitting(.vecIntCut, takes: VecIntItem.self, IntItem.self,
                                       gives: VecIntItem.self) { v, n in
            let at = Position.gap(n.value, count: v.value.count)
            return (Built(Array(v.value[..<at]), members: Array(v.origins()[..<at])),
                    Built(Array(v.value[at...]), members: Array(v.origins()[at...])))
        }
        #expect(halve.produces == .results([.vecInt, .vecInt]))
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.vecInt]!.prepend(VecIntItem([1, 2, 3]))
        inty.stacks[.int]!.prepend(IntItem(1))
        halve.act(on: inty)
        #expect(stackString(inty, .vecInt) == "[ [2, 3] [1] ]")
        #expect(callString(inty.stacks[.vecInt]![1]) == "( [1, 2, 3] 1 .vecIntCut 1 .vecIntPopItems )")
        #expect(callString(inty.stacks[.vecInt]![0]) == "( [1, 2, 3] 1 .vecIntCut .vecIntSwap .vecIntPop )")
    }

    /// `composing`: the body gets the argument itself, so a quoted value keeps its
    /// own history inside the block — a values body would have rebuilt it bare.
    @Test func `composing keeps an argument's history inside the result`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [IntItem(3), IntItem(4), InstructionItem(.intAdd), InstructionItem(.intQuote)])
        inty.run()
        let block = topItem(inty, .code) as! CodeItem
        #expect(block.pretty() == "( 7 )")
        #expect(callString(block) == "( 7 .intQuote )")
        #expect(callString(block.value[0]) == "( 3 4 .intAdd )", "the quoted 7 still knows where it came from")
    }
}
