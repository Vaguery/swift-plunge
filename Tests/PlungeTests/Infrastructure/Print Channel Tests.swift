//
//  Print Channel Tests.swift
//  PlungeTests
//
//  `.print` is a channel, like `.error`: a program writes to it and nothing in the
//  language reads it back. What a program has printed is its answer, so a program
//  that could pop, reorder, count or reuse its printed items could edit that answer
//  out of sight of whatever scores it. These pin that rule from every side an
//  instruction could reach a stack.
//

@testable import Plunge
import Testing

@Suite
struct PrintChannelTests {

    @Test func `print is a channel`() {
        #expect(PushStack.print.isChannel)
        #expect(PushStack.error.isChannel)
        #expect(PushStack.allCases.filter(\.isChannel) == [.error, .print])
    }

    /// No instruction is named for `.print`, so none can be its stack family.
    @Test func `no instruction belongs to .print`() {
        let named = PushInstruction.allCases.filter { $0.rawValue.hasPrefix("print") }
        #expect(named.isEmpty, "\(named)")
        #expect(!Interpreter.generatedFamilyStacks.contains(.print))
    }

    /// No Behavior may take, read, need or observe `.print`.
    @Test func `no behavior declares .print as an argument or observed stack`() {
        for (name, behavior) in Interpreter.language {
            #expect(behavior.staticNeeds[.print] == nil, "\(name) declares .print in staticNeeds")
            #expect(behavior.consumedStacks[.print] == nil, "\(name) consumes .print")
            #expect(behavior.readStacks[.print] == nil, "\(name) declares .print as a read")
            #expect(!behavior.observes.contains(.print), "\(name) observes .print")
            guard let signature = Interpreter.signatures[name] else { continue }
            #expect(signature.consumes[.print] == nil && signature.reads[.print] == nil
                    && signature.needs[.print] == nil && !signature.variadic.contains(.print),
                    "\(name)'s signature reaches into .print")
        }
    }

    /// Only the print instructions put anything on `.print`, and it is never a
    /// value edge: no declaration lists it among the stacks a value can land on.
    @Test func `only the prints write to .print`() {
        for (name, behavior) in Interpreter.language {
            #expect(!behavior.produces.valueStacks.contains(.print), "\(name) gives a value on .print")
            if behavior.produces == .printed {
                #expect(behavior.behaviorClass == .channel, "\(name) prints but isn't a channel")
            }
        }
        #expect(Interpreter.instructions(in: .channel).allSatisfy {
            Interpreter.language[$0]!.produces == .printed
        })
    }

    /// The function machinery reads fillers, makes holes and returns values from
    /// a list of stacks; `.print` must be on none of them, or a function could
    /// read a printed item or leave its result there.
    @Test func `the function machinery never touches .print`() {
        #expect(!Interpreter.fillerStacks.contains(.print))
        #expect(!Interpreter.holeSourceStacks.contains(.print))
        #expect(!FunctionDerivation.holeStacks.contains(.print))
        #expect(!Produces.anyItem.contains(.print))
        #expect(!Interpreter.anyValue.valueStacks.contains(.print))
    }

    /// A sandbox's result is the last thing pushed; a print must not count, or a
    /// mapped function ending in a print would make the printed item its result.
    @Test func `a print is never a sandbox's last push`() {
        let inty = Interpreter()
        inty.load(stacks: [.int: [IntItem(5)]], program: [InstructionItem(.intPrint)])
        inty.run()
        #expect(inty.stacks[.print]!.count == 1)
        #expect(inty.lastPush != .print)
    }

    /// No size limit, as for `.error`: a print is never refused. The memory guard
    /// still counts what is there.
    @Test func `print has no size limit but counts toward live weight`() {
        var settings = InterpreterSettings()
        settings.maxStackDepth = 3
        let inty = Interpreter()
        inty.config = settings
        inty.load(stacks: [.int: (0..<6).map { IntItem($0) }],
                  program: Array(repeating: InstructionItem(.intPrint), count: 6))
        inty.run()
        #expect(inty.stacks[.print]!.count == 6, "printing past maxStackDepth is not refused")
        #expect(inty.stacks[.error]!.isEmpty)
        let printedWeight = inty.stacks[.print]!.reduce(0) { $0 + $1.weight }
        #expect(inty.liveWeight >= printedWeight)
    }

    /// A sandbox's prints stay in the sandbox, as its errors do.
    @Test func `prints inside a mapped function are discarded`() {
        let inty = Interpreter()
        inty.load(program: [
            CodeItem([InstructionItem(.intDup), InstructionItem(.intPrint)]),
            InstructionItem(.codePushAllFunctions),
            VecIntItem([1, 2, 3]),
            InstructionItem(.vecIntMap)
        ])
        inty.run()
        #expect(inty.stacks[.print]!.isEmpty, "the sandbox's .print is thrown away")
    }
}
