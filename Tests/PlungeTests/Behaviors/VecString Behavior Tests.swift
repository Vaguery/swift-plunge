//
//  VecString Behavior Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 6/16/26.
//

@testable import Plunge
import Testing
import DequeModule

@Suite
struct VecStringBehaviorTests {

    var inty = Interpreter.recordingProvenance()

    @Test func vecStringButLast() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a", "b", "c"]),
                         VecStringItem(["z"])
                        ])

        doThis(.vecStringButLast, to: inty)
        #expect(stackString(inty, .vecString) == "[ «vecStr []» [\"a\", \"b\", \"c\"] [\"z\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( «vecStr []» .vecStringButLast )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringButLast, to: inty)
        #expect(stackString(inty, .vecString) ==  "[ [\"a\", \"b\"] [\"z\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"a\", \"b\", \"c\"] .vecStringButLast )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringButLast, to: inty)
        #expect(stackString(inty, .vecString) == "[ «vecStr []» ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"z\"] .vecStringButLast )")
    }

    @Test func vecStringConcat() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a", "b"]),
                         VecStringItem(["x", "y"])
                        ])

        doThis(.vecStringConcat, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\"] [\"x\", \"y\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"a\", \"b\"] «vecStr []» .vecStringConcat )")

        doThis(.vecStringConcat, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"x\", \"y\", \"a\", \"b\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"x\", \"y\"] [\"a\", \"b\"] .vecStringConcat )")
    }

    @Test func vecStringConj() {
        loadStrings(inty, strings: ["x", "y", "z"])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a", "b"])
                        ])

        doThis(.vecStringConj, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"x\"] [\"a\", \"b\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( «vecStr []» \"x\" .vecStringConj )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringConj, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\", \"y\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"a\", \"b\"] \"y\" .vecStringConj )")

        doThis(.vecStringConj, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\", \"y\", \"z\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"a\", \"b\", \"y\"] \"z\" .vecStringConj )")
    }

    @Test func vecStringContains() {
        // Non-destructive: reads the vector and the needle and leaves both, so the
        // crux pops both to reproduce just the bool.
        loadStrings(inty, strings: ["a"])
        inty.stacks[.vecString]!.prepend(VecStringItem(["a", "b", "c"]))
        doThis(.vecStringContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\", \"c\"] ]", "the vector survives the read")
        #expect(stackString(inty, .string) == "[ \"a\" ]", "the needle survives the read")
        #expect(callString(topItem(inty, .bool)) == "( [\"a\", \"b\", \"c\"] \"a\" .vecStringContains 1 .stringPopItems 1 .vecStringPopItems )")

        let miss = Interpreter.recordingProvenance()
        miss.stacks[.vecString]!.prepend(VecStringItem([]))
        miss.stacks[.string]!.prepend(StringItem("-"))
        doThis(.vecStringContains, to: miss)
        #expect(stackString(miss, .bool) == "[ false ]")
    }

    @Test func vecStringDrop() {
        loadInts(inty, ints: [-3, 0, 1])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["x", "y", "z"])
                        ])

        doThis(.vecStringDrop, to: inty)
        #expect(stackString(inty, .vecString) == "[ «vecStr []» [\"x\", \"y\", \"z\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( «vecStr []» -3 .vecStringDrop )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringDrop, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"x\", \"y\", \"z\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"x\", \"y\", \"z\"] 0 .vecStringDrop )")

        doThis(.vecStringDrop, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"y\", \"z\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"x\", \"y\", \"z\"] 1 .vecStringDrop )")
    }

    @Test func vecStringFirst() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a", "b"])
                        ])

        doThis(.vecStringFirst, to: inty)
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.vecStringFirst, to: inty)
        #expect(stackString(inty, .string) == "[ \"a\" ]")
        #expect(callString(topItem(inty, .string)) == "( [\"a\", \"b\"] .vecStringFirst )")
    }

    @Test func vecStringIndexOf() {
        loadStrings(inty, strings: ["b"])
        inty.stacks[.vecString]!.prepend(VecStringItem(["a", "b", "c"]))
        doThis(.vecStringIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 ]")
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\", \"c\"] ]", "the vector survives")
        #expect(stackString(inty, .string) == "[ \"b\" ]", "the needle survives")
        #expect(callString(topItem(inty, .int)) == "( [\"a\", \"b\", \"c\"] \"b\" .vecStringIndexOf 1 .stringPopItems 1 .vecStringPopItems )")

        let absent = Interpreter.recordingProvenance()
        absent.stacks[.vecString]!.prepend(VecStringItem(["x", "y", "z"]))
        absent.stacks[.string]!.prepend(StringItem("7"))
        doThis(.vecStringIndexOf, to: absent)
        #expect(stackString(absent, .int) == "[ ]", "absent: an error, not -1")
        #expect((topItem(absent, .error) as? ErrorItem)?.kind == .notFound)
    }

    @Test func vecStringIsEmpty() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a", "b"])
                        ])

        doThis(.vecStringItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .vecString) == "[ «vecStr []» [\"a\", \"b\"] ]", "the vector survives")
        #expect(callString(topItem(inty, .bool)) == "( «vecStr []» .vecStringItemIsEmpty 1 .vecStringPopItems )")

        doThis(.vecStringPop, to: inty)   // discard the empty to reach the next vector

        doThis(.vecStringItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( [\"a\", \"b\"] .vecStringItemIsEmpty 1 .vecStringPopItems )")
    }

    @Test func `vecStringIterate records provenance only for its derived results`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem(["1", "2"])
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ [\"1\", \"2\"] ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        // The instruction only builds the iterator; `.iteratorPlay` does the work.
        doThis(.vecStringIterate, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")

        // The whole vector goes INTO the iterator and stays there. It used to
        // re-push a *shrunken* copy every pass, which was the one derived value
        // here and recorded `[previous, .vecStringRest]` — a level deeper per
        // element, O(n) in the vector's length. There is no shrinking now, so
        // there is nothing to record: `.vecStringRest` is named by nothing.
        inty.step()
        #expect(stackString(inty, .string) == "[ \"1\" ]")
        #expect(inty.stacks[.exec]!.count == 3)
        #expect(inty.stacks[.exec]![0].call.isEmpty)   // mouse, to run
        #expect(inty.stacks[.exec]![1].call.isEmpty)   // .codeDo
        #expect(inty.stacks[.exec]![2].call.isEmpty)   // .iteratorPlay

        // The element is honestly the vector's 1st, and says so without depending
        // on how many passes have run.
        #expect(CodeItem(topItem(inty, .string).crux()).pretty()
            == "( [\"1\", \"2\"] 0 .vecStringNth )")
    }

    @Test func `vecStringIterate works for >1 item`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem(["skunk", "badger"])
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ [\"skunk\", \"badger\"] ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecStringIterate, to: inty)
        #expect(stackString(inty, .vecString) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()   // first pass: "skunk", then the mouse
        #expect(stackString(inty, .string) == "[ \"skunk\" ]")
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .codeDo .iteratorPlay ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .boolNot .iteratorPlay ]")

        inty.step()   // the mouse runs
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()   // second and last pass: "badger", and the loop is done
        #expect(stackString(inty, .string) == "[ \"badger\" \"skunk\" ]")
        // The body waits under the last pass, and returns to .code after it.
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo ( .boolNot ) ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    @Test func `vecStringIterate works for empty`() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([])
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ «vecStr []» ]")
        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.vecStringIterate, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
    }

    @Test func `vecStringIterate works for one item`() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem(["joe"])
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ [\"joe\"] ]")
        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.vecStringIterate, to: inty)
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")

        // One element, so one pass and no continuation: the iterator is spent as
        // soon as it is played, and never comes to rest.
        inty.step()
        #expect(stackString(inty, .string) == "[ \"joe\" ]")
        #expect(stackString(inty, .vecString) == "[ ]")
        // The body waits under the last pass, and returns to .code after it.
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo ( .boolNot ) ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    @Test func vecStringLast() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a", "b"])
                        ])

        doThis(.vecStringLast, to: inty)
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.vecStringLast, to: inty)
        #expect(stackString(inty, .string) == "[ \"b\" ]")
        #expect(callString(topItem(inty, .string)) == "( [\"a\", \"b\"] .vecStringLast )")
    }

    @Test func vecStringLength() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a", "b", "c"])
                        ])

        // Non-destructive: the vector is read, not consumed. It stays on
        // .vecString, and the crux pops what it read so it reproduces only the count.
        doThis(.vecStringLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .vecString) == "[ «vecStr []» [\"a\", \"b\", \"c\"] ]")   // both survive
        #expect(callString(topItem(inty, .int)) == "( «vecStr []» .vecStringLength 1 .vecStringPopItems )")

        doThis(.vecStringPop, to: inty)   // discard the empty to reach the next vector

        doThis(.vecStringLength, to: inty)
        #expect(stackString(inty, .int) == "[ 3 0 ]")
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\", \"c\"] ]")   // still there
        #expect(callString(topItem(inty, .int)) == "( [\"a\", \"b\", \"c\"] .vecStringLength 1 .vecStringPopItems )")
    }

    @Test func vecStringNth() {
        loadInts(inty, ints: [-3, 1, 7776])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["x", "y", "z"]),
                         VecStringItem(["aa", "bb", "cc"])
                        ])

        #expect(stackString(inty, .vecString) == "[ «vecStr []» [\"x\", \"y\", \"z\"] [\"aa\", \"bb\", \"cc\"] ]")
        #expect(stackString(inty, .int) == "[ -3 1 7776 ]")

        doThis(.vecStringNth, to: inty)
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.vecStringNth, to: inty)
        #expect(stackString(inty, .string) == "[ \"y\" ]")
        #expect(callString(topItem(inty, .string)) == "( [\"x\", \"y\", \"z\"] 1 .vecStringNth )")

        doThis(.vecStringNth, to: inty)
        #expect(stackString(inty, .string) == "[ \"cc\" \"y\" ]", "past the end is the last element")
        #expect(callString(topItem(inty, .string)) == "( [\"aa\", \"bb\", \"cc\"] 7776 .vecStringNth )")
    }

    @Test func vecStringOccurrencesOf() {
        loadStrings(inty, strings: ["o"])
        inty.stacks[.vecString]!.prepend(VecStringItem(["o", "o", "o", "o", "o"]))
        doThis(.vecStringOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 5 ]")
        #expect(stackString(inty, .vecString) == "[ [\"o\", \"o\", \"o\", \"o\", \"o\"] ]", "the vector survives")
        #expect(stackString(inty, .string) == "[ \"o\" ]", "the needle survives")
        #expect(callString(topItem(inty, .int)) == "( [\"o\", \"o\", \"o\", \"o\", \"o\"] \"o\" .vecStringOccurrencesOf 1 .stringPopItems 1 .vecStringPopItems )")

        let none = Interpreter.recordingProvenance()
        none.stacks[.vecString]!.prepend(VecStringItem(["o", "o", "o", "o", "o"]))
        none.stacks[.string]!.prepend(StringItem("x"))
        doThis(.vecStringOccurrencesOf, to: none)
        #expect(stackString(none, .int) == "[ 0 ]")
    }

    @Test func vecStringPushAll() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["1", "22", "333"])
                        ])

        // An empty vector yields nothing at all — not even an iterator.
        doThis(.vecStringPushAll, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .iterator) == "[ ]")

        // It emits one element per pass now, so nothing appears until it runs.
        doThis(.vecStringPushAll, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
        inty.run(stepLimit: 10_000)

        // Front to back, so "333" was pushed last and is on top — the reverse of
        // what it used to be, deliberately: collections are walked
        // front-to-back.
        #expect(stackString(inty, .string) == "[ \"333\" \"22\" \"1\" ]")

        // Each element names its own index rather than how far down a pile it
        // landed, so this record says nothing about the other two.
        #expect(callString(topItem(inty, .string)) == "( [\"1\", \"22\", \"333\"] 2 .vecStringNth )")
        doThis(.stringPop, to: inty)
        #expect(CodeItem(topItem(inty, .string).crux()).pretty()
            == "( [\"1\", \"22\", \"333\"] 1 .vecStringNth )")
    }

    @Test func vecStringRemove() {
        loadStrings(inty, strings: ["f", "f", "u"])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["f", "l", "u", "f", "f"]),
                         VecStringItem(["f", "l", "o", "o", "f"])
                        ])

        doThis(.vecStringRemove, to: inty)
        #expect(stackString(inty, .vecString)
                == "[ «vecStr []» [\"f\", \"l\", \"u\", \"f\", \"f\"] [\"f\", \"l\", \"o\", \"o\", \"f\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( «vecStr []» \"f\" .vecStringRemove )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringRemove, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"l\", \"u\"] [\"f\", \"l\", \"o\", \"o\", \"f\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"f\", \"l\", \"u\", \"f\", \"f\"] \"f\" .vecStringRemove )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringRemove, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"f\", \"l\", \"o\", \"o\", \"f\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"f\", \"l\", \"o\", \"o\", \"f\"] \"u\" .vecStringRemove )")
    }

    @Test func vecStringReplace() {
        loadStrings(inty, strings: ["f", "g", "-", "f", "x", "u"])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["f", "a", "f"]),
                         VecStringItem(["f", "l", "o"])
                        ])


        doThis(.vecStringReplace, to: inty)
        #expect(stackString(inty, .vecString) == "[ «vecStr []» [\"f\", \"a\", \"f\"] [\"f\", \"l\", \"o\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( «vecStr []» \"g\" \"f\" .vecStringReplace )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringReplace, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"-\", \"a\", \"-\"] [\"f\", \"l\", \"o\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"f\", \"a\", \"f\"] \"f\" \"-\" .vecStringReplace )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringReplace, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"f\", \"l\", \"o\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"f\", \"l\", \"o\"] \"u\" \"x\" .vecStringReplace )")
    }

    @Test func vecStringReplaceFirst() {
       loadStrings(inty, strings: ["f", "g", "-", "f", "x", "u"])
       inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["f", "a", "f"]),
                         VecStringItem(["f", "l", "o"])
                        ])


        doThis(.vecStringReplaceFirst, to: inty)
        #expect(stackString(inty, .vecString) == "[ «vecStr []» [\"f\", \"a\", \"f\"] [\"f\", \"l\", \"o\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( «vecStr []» \"g\" \"f\" .vecStringReplaceFirst )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringReplaceFirst, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"-\", \"a\", \"f\"] [\"f\", \"l\", \"o\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"f\", \"a\", \"f\"] \"f\" \"-\" .vecStringReplaceFirst )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringReplaceFirst, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"f\", \"l\", \"o\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"f\", \"l\", \"o\"] \"u\" \"x\" .vecStringReplaceFirst )")
    }

    @Test func vecStringRest() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a", "b", "c"])
                        ])

        doThis(.vecStringRest, to: inty)
        #expect(stackString(inty, .vecString) == "[ «vecStr []» [\"a\", \"b\", \"c\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( «vecStr []» .vecStringRest )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringRest, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"b\", \"c\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"a\", \"b\", \"c\"] .vecStringRest )")
    }

    @Test func vecStringReverse() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a", "bc"])
                        ])

        doThis(.vecStringReverse, to: inty)
        #expect(stackString(inty, .vecString) == "[ «vecStr []» [\"a\", \"bc\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( «vecStr []» .vecStringReverse )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringReverse, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"bc\", \"a\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"a\", \"bc\"] .vecStringReverse )")
    }

    @Test func vecStringSet() {
        loadInts(inty, ints: [1, 2222, 2])
        loadStrings(inty, strings: ["-", "-", "-"])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a", "b", "c", "d", "e"]),
                         VecStringItem(["a", "b"])
                        ])

        // An empty vector has no element to replace: an error, arguments consumed.
        doThis(.vecStringSet, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\", \"c\", \"d\", \"e\"] [\"a\", \"b\"] ]")
        #expect((topItem(inty, .error) as? ErrorItem)?.kind == .emptyCollection)
        #expect(callString(topItem(inty, .error)) == "( «vecStr []» \"-\" 1 .vecStringSet )")

        doThis(.vecStringSet, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\", \"c\", \"d\", \"-\"] [\"a\", \"b\"] ]", "2222 clamps to the last")
        #expect(callString(topItem(inty, .vecString)) == "( [\"a\", \"b\", \"c\", \"d\", \"e\"] \"-\" 2222 .vecStringSet )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringSet, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"-\"] ]", "2 clamps to the last")
        #expect(callString(topItem(inty, .vecString)) == "( [\"a\", \"b\"] \"-\" 2 .vecStringSet )")
    }

    @Test func vecStringSlice() {
        loadInts(inty, ints: [1, 9, 3, 2, 2, -1, 1, 1])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a", "b", "c", "d", "e"]),
                         VecStringItem(["z", "y", "x", "w"]),
                         VecStringItem(["1", "11", "111", "1111"])
                        ])

        doThis(.vecStringSlice, to: inty)
        #expect(stackString(inty, .vecString)
                == "[ «vecStr []» [\"a\", \"b\", \"c\", \"d\", \"e\"] [\"z\", \"y\", \"x\", \"w\"] "
                + "[\"1\", \"11\", \"111\", \"1111\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( «vecStr []» 9 1 .vecStringSlice )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringSlice, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"c\", \"d\"] [\"z\", \"y\", \"x\", \"w\"] [\"1\", \"11\", \"111\", \"1111\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"a\", \"b\", \"c\", \"d\", \"e\"] 2 3 .vecStringSlice )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringSlice, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"z\", \"y\", \"x\"] [\"1\", \"11\", \"111\", \"1111\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"z\", \"y\", \"x\", \"w\"] -1 2 .vecStringSlice )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringSlice, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"11\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"1\", \"11\", \"111\", \"1111\"] 1 1 .vecStringSlice )")
    }

    @Test func vecStringTake() {
        loadInts(inty, ints: [-3, 99, 1])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["x", "y", "z"])
                        ])

        doThis(.vecStringTake, to: inty)
        #expect(stackString(inty, .vecString) == "[ «vecStr []» [\"x\", \"y\", \"z\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( «vecStr []» -3 .vecStringTake )")

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringTake, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"x\", \"y\", \"z\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"x\", \"y\", \"z\"] 99 .vecStringTake )")

        doThis(.vecStringTake, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"x\"] ]")
        #expect(callString(topItem(inty, .vecString)) == "( [\"x\", \"y\", \"z\"] 1 .vecStringTake )")
    }
}
