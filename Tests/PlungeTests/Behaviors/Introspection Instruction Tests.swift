//
//  Introspection Instruction Tests.swift
//  PlungeTests
//
//  The five instructions that let a program ask about its own run, and the rule
//  that keeps `.error` read-only.
//

import DequeModule
import Testing
@testable import Plunge


@Suite
struct IntrospectionInstructionTests {

    // MARK: - The `.error` rule
    //
    // The rule these guard is stated in `Introspection Behaviors.swift`: `.error`
    // is the interpreter's account of what a program did wrong, and an account a
    // program can edit is worth nothing.

    /// **The load-bearing test in this file.** The combinator family is generated
    /// for every stack, so nothing stops a future sweep from generating it for
    /// `.error` too — and that sweep would look like a completeness fix rather
    /// than a hole. This is what says otherwise.
    @Test func `the error stack has no combinators except stackDepth`() {
        let forbidden = ["Pop", "PopItems", "Dup", "DupItems", "DupTimes", "DeepDup",
                         "Swap", "Rot", "Flush", "Yank", "YankDup", "Shove",
                         "StackIsEmpty", "Print", "Quote", "Eq"]
        for suffix in forbidden {
            let name = PushInstruction(rawValue: "error\(suffix)")
            #expect(name == nil,
                    "error\(suffix) must not exist: a program that can edit .error can hide its own failures")
            if let name { #expect(Interpreter.language[name] == nil) }
        }
        // And the one that is allowed.
        #expect(Interpreter.language[.errorStackDepth] != nil)
    }

    /// No instruction may consume, reorder or push to `.error`. The introspection
    /// four *read* it, which they do through the interpreter rather than by
    /// declaring a requirement, so even they should not appear here.
    @Test func `no behavior declares .error as an argument stack`() {
        for (name, behavior) in Interpreter.language {
            #expect(behavior.staticNeeds[.error] == nil, "\(name) declares .error in staticNeeds")
            #expect(behavior.consumedStacks[.error] == nil, "\(name) consumes .error")
            #expect(behavior.readStacks[.error] == nil, "\(name) declares .error as a read")
        }
    }

    /// Counting is not manipulating: every introspection instruction must leave
    /// `.error` exactly as it found it, contents and order.
    @Test func `introspection never alters the error stack`() {
        let introspection: [PushInstruction] = [
            .pushStepCount, .errorStackDepth,
            .errorMissingArgCount, .errorMissingInputCount, .errorMissingConstantCount
        ]
        for name in introspection {
            let inty = Interpreter.recordingProvenance()
            inty.stacks[.error]!.prepend(contentsOf: [
                ErrorItem("first", kind: .missingArgument),
                ErrorItem("second", kind: .missingInput)
            ] as [any Item])
            let before = stackString(inty, .error)

            Interpreter.language[name]!.act(on: inty)

            #expect(stackString(inty, .error) == before,
                    "\(name) changed .error from \(before) to \(stackString(inty, .error))")
        }
    }


    // MARK: - What they report

    @Test func `errorStackDepth counts what is on the error stack`() {
        let inty = Interpreter.recordingProvenance()
        Interpreter.language[.errorStackDepth]!.act(on: inty)
        #expect((topItem(inty, .int) as! IntItem).value == 0, "a fresh interpreter has made no mistakes")

        let dirty = Interpreter.recordingProvenance()
        dirty.stacks[.error]!.prepend(contentsOf: [
            ErrorItem("a"), ErrorItem("b"), ErrorItem("c")
        ] as [any Item])
        Interpreter.language[.errorStackDepth]!.act(on: dirty)
        #expect((topItem(dirty, .int) as! IntItem).value == 3)
    }

    @Test func `the missing-count instructions partition by kind`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.error]!.prepend(contentsOf: [
            ErrorItem("intAdd missing args: .int", kind: .missingArgument),
            ErrorItem("intSubtract missing args: .int", kind: .missingArgument),
            ErrorItem("No input for input3", kind: .missingInput),
            ErrorItem("No constant assigned for int2", kind: .missingConstant),
            ErrorItem("something else entirely", kind: .other)
        ] as [any Item])

        for (name, expected) in [(PushInstruction.errorMissingArgCount, 2),
                                 (.errorMissingInputCount, 1),
                                 (.errorMissingConstantCount, 1)] {
            let probe = Interpreter.recordingProvenance()
            probe.stacks[.error] = inty.stacks[.error]
            Interpreter.language[name]!.act(on: probe)
            #expect((topItem(probe, .int) as! IntItem).value == expected,
                    "\(name) counted wrong")
        }
    }

    /// The counts have to track errors the interpreter *actually* raised, not just
    /// hand-built ones — which is what pins the `kind:` tags at each raising site.
    @Test func `a starved instruction is counted as a missing argument`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [InstructionItem(.intAdd)])   // nothing on .int to add
        inty.run()

        #expect(stackString(inty, .error) != "[ ]", "intAdd should have starved")
        Interpreter.language[.errorMissingArgCount]!.act(on: inty)
        #expect((topItem(inty, .int) as! IntItem).value == 1)
    }

    @Test func `an unbound input is counted as a missing input`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [InstructionItem(.input3)])   // never bound
        inty.run()

        Interpreter.language[.errorMissingInputCount]!.act(on: inty)
        #expect((topItem(inty, .int) as! IntItem).value == 1)
    }

    @Test func `an unbound constant is counted as a missing constant`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [InstructionItem(.int2)])     // never bound
        inty.run()

        Interpreter.language[.errorMissingConstantCount]!.act(on: inty)
        #expect((topItem(inty, .int) as! IntItem).value == 1)
    }

    @Test func `pushStepCount reports the steps taken so far`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [IntItem(1), IntItem(2), IntItem(3),
                            InstructionItem(.pushStepCount)])
        inty.run()
        // Three literals land, then the instruction runs — and reports 3, because
        // `counter` is incremented after dispatch, so a Behavior sees the steps
        // completed *before* it. Pinned deliberately: this is the documented
        // semantics, not an off-by-one.
        #expect((topItem(inty, .int) as! IntItem).value == 3,
                "got \(stackString(inty, .int))")
    }


    // MARK: - Provenance

    /// Law 4b: a reading of transient execution state records a stand-in, the
    /// literal number marked as observed by the instruction. Recording the
    /// instruction name would reconstruct to whatever a *fresh* interpreter
    /// happened to hold, which for every one of these is zero. (Was
    /// `introspection results record no provenance`, before stand-ins.)
    @Test func `introspection results record a stand-in`() {
        let names: [PushInstruction] = [
            .pushStepCount, .errorStackDepth,
            .errorMissingArgCount, .errorMissingInputCount, .errorMissingConstantCount
        ]
        for name in names {
            let inty = Interpreter.recordingProvenance()
            inty.stacks[.error]!.prepend(ErrorItem("x", kind: .missingArgument))
            Interpreter.language[name]!.act(on: inty)
            let call = topItem(inty, .int).call
            let standIn = call.first.flatMap { $0 as? StandInItem }
            #expect(call.count == 1 && standIn?.source == name && standIn?.reason == .observed,
                    "\(name) should record one stand-in naming itself, got \(call.map { $0.pretty() })")
        }
    }
}
