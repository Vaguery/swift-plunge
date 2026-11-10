//
//  Item Layout Tests.swift
//  PushInterpreterTests
//
//  An `any Item` holds a value of up to three words inline and puts anything larger
//  in a heap box, allocated each time such a value becomes an `any Item`. Every item
//  below fits, so a step that makes one allocates nothing for it. A new stored
//  property can silently undo that, and the cost would show only in a profile, so
//  the sizes are pinned here. (Blocks and iterators are larger and are boxed.)
//

@testable import PushInterpreter
import Testing

struct ItemLayoutTests {

    static let inlineCapacity = 3 * MemoryLayout<Int>.size

    @Test(arguments: [
        ("IntItem", MemoryLayout<IntItem>.size),
        ("DoubleItem", MemoryLayout<DoubleItem>.size),
        ("BoolItem", MemoryLayout<BoolItem>.size),
        ("InstructionItem", MemoryLayout<InstructionItem>.size),
        ("CharItem", MemoryLayout<CharItem>.size),
        ("StringItem", MemoryLayout<StringItem>.size),
        ("ErrorItem", MemoryLayout<ErrorItem>.size),
        ("VecIntItem", MemoryLayout<VecIntItem>.size),
        ("VecDoubleItem", MemoryLayout<VecDoubleItem>.size),
        ("VecBoolItem", MemoryLayout<VecBoolItem>.size),
        ("VecStringItem", MemoryLayout<VecStringItem>.size)
    ])
    func `fits an existential's inline buffer`(type: String, size: Int) {
        #expect(size <= Self.inlineCapacity, "\(type) is \(size) bytes; over \(Self.inlineCapacity) it is heap-boxed")
    }

    /// Provenance moved behind one reference keeps its meaning: assigning `call`
    /// stores it and its measure; an empty `call` is a literal.
    @Test func `call storage round-trips and measures`() {
        var item = IntItem(5)
        #expect(item.call.isEmpty && item.callMeasure == .literal)
        item.call = [IntItem(2), IntItem(3), InstructionItem(.intAdd)]
        #expect(item.call.count == 3)
        #expect(item.callWeight == 4 && item.callDepth == 1)
        let copy = item
        item.call = []
        #expect(copy.call.count == 3, "items keep value semantics")
        #expect(item.callMeasure == .literal)
    }

    /// The packed error message keeps value and kind independent of each other.
    @Test func `error value and kind survive repacking`() {
        var starved = ErrorItem(missingArgumentsFor: .intAdd, on: .int)
        #expect(starved.value == "intAdd missing args: .int" && starved.kind == .missingArgument)
        starved.kind = .other
        #expect(starved.value == "intAdd missing args: .int" && starved.kind == .other)
        var text = ErrorItem("boom", kind: .sizeRefusal)
        text.value = "bang"
        #expect(text.value == "bang" && text.kind == .sizeRefusal)
    }
}
