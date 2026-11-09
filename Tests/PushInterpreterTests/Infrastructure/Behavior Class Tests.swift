//
//  Behavior Class Tests.swift
//  PushInterpreterTests
//
//  Every Behavior declares one `BehaviorClass` (Roadmap #43). The class is
//  judgment, like a tag, so these tests do not re-derive it. They check each
//  declaration against what the Behavior can reach and what it does when run on
//  a well-stocked interpreter.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct BehaviorClassTests {

    /// A well-typed item for each stack, so every Behavior finds its arguments.
    /// Samples carry no `call`, which is what lets the structural test tell a
    /// rearranged item from a computed one.
    func sample(for stack: PushStack, flag: Bool) -> any Item {
        switch stack {
        case .bool:      BoolItem(flag)
        case .int:       IntItem(1)
        case .double:    DoubleItem(1.0)
        case .char:      CharItem("a")
        case .string:    StringItem("x y")
        case .code:      CodeItem([IntItem(7)])
        case .vecBool:   VecBoolItem([false, true])
        case .vecInt:    VecIntItem([1, 2, 3])
        case .vecDouble: VecDoubleItem([1.0, 2.0])
        case .vecString: VecStringItem(["a", "b"])
        case .iterator:  IteratorItem(kind: .counting(stride: 1), origin: IntItem(0),
                                      destination: IntItem(3), body: CodeItem([IntItem(7)]), emits: true)
        case .exec:      BoolItem(flag)
        case .error:     ErrorItem("x")
        }
    }

    /// An interpreter with five samples on every stack but `.error`.
    func seeded(flag: Bool = false) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        for stack in PushStack.allCases where stack != .error {
            for _ in 0..<5 { inty.stacks[stack]!.prepend(sample(for: stack, flag: flag)) }
        }
        return inty
    }

    func members(_ behaviorClass: BehaviorClass) -> [PushInstruction] {
        Interpreter.instructions(in: behaviorClass).sorted { $0.rawValue < $1.rawValue }
    }


    // MARK: - The partition

    @Test func `every instruction declares exactly one class`() {
        var seen = Set<PushInstruction>()
        for behaviorClass in BehaviorClass.allCases {
            let these = Interpreter.instructions(in: behaviorClass)
            #expect(seen.isDisjoint(with: these), "\(behaviorClass) overlaps another class")
            seen.formUnion(these)
        }
        #expect(seen == Set(Interpreter.language.keys))
    }

    /// Pinned so that a new instruction is classed on purpose. Most land in
    /// `.operation` by default; if one should not, this is where it shows.
    @Test func `the partition, pinned`() {
        let counts = Dictionary(uniqueKeysWithValues: BehaviorClass.allCases.map {
            ($0, Interpreter.instructions(in: $0).count)
        })
        #expect(counts == [
            .operation: 324,
            .structural: 144,   // 12 families × 12 stacks
            .contextRead: 127,  // 80 constants, 10 inputs, 24 depth/emptiness, 5 counts, 8 readItems/readStack
            .control: 29,
            .channel: 13,
        ], "\(counts)")
    }


    // MARK: - What each class can reach

    /// The body's type is what a Behavior can reach, so each class must have its
    /// own: only a context read sees the interpreter, only a channel prints, only
    /// a structural rule changes positions in place. Operations and control share
    /// `values`, and control alone may also write the continuation directly.
    @Test func `every class has the body that lets it do what it says`() {
        for (name, behavior) in Interpreter.language {
            let fits = switch (behavior.behaviorClass, behavior.body) {
            case (.operation, .values), (.control, .values), (.control, .control),
                 (.structural, .structural), (.contextRead, .contextRead), (.channel, .channel): true
            default: false
            }
            #expect(fits, "\(name) is \(behavior.behaviorClass) with a mismatched body")
        }
    }

    /// A source has no data arguments. `readItems` takes a count, and nothing in
    /// the class takes more.
    @Test func `a context read takes no data, at most a count`() {
        for name in members(.contextRead) {
            for requirement in Interpreter.language[name]!.requirements {
                guard case .takes(.int) = requirement else {
                    Issue.record("\(name) requires \(requirement)")
                    continue
                }
            }
        }
    }


    // MARK: - What each class does

    /// A sink adds nothing to any stack but `.error`.
    @Test func `a channel adds to no stack`() {
        for name in members(.channel) {
            let inty = seeded()
            let before = PushStack.allCases.map { inty.stacks[$0]!.count }
            Interpreter.language[name]!.act(on: inty)
            for (stack, count) in zip(PushStack.allCases, before) where stack != .error {
                #expect(inty.stacks[stack]!.count <= count, "\(name) added to .\(stack)")
            }
        }
    }

    /// Rearranging records nothing (provenance law 1): after a structural rule,
    /// and any loop it started has run, every item is one of the samples, none
    /// carrying a `call` of its own. An operation's result would carry one.
    @Test func `a structural rule makes no new value`() {
        for name in members(.structural) {
            let inty = seeded()
            Interpreter.language[name]!.act(on: inty)
            inty.run()
            for stack in PushStack.allCases where stack != .error {
                for item in inty.stacks[stack]! where !item.call.isEmpty {
                    Issue.record("\(name) left \(item.pretty()) on .\(stack) with a call")
                }
            }
        }
    }

    /// Control writes the continuation: on one or other seeding (so both
    /// branches of a conditional are tried), `.exec` ends up holding something
    /// that is not one of the seeded samples.
    @Test func `control writes the continuation`() {
        for name in members(.control) {
            let wrote = [false, true].contains { flag in
                let inty = seeded(flag: flag)
                Interpreter.language[name]!.act(on: inty)
                return inty.stacks[.exec]!.contains { !$0.isEqual(to: BoolItem(flag)) }
            }
            #expect(wrote, "\(name) never wrote .exec")
        }
    }

    /// The converse for operations: one that writes `.exec` is control,
    /// or an operation that delivers its values through an iterator loop (the
    /// explode family and the iterator constructors that start running), or a
    /// structural rule on `.exec` itself.
    @Test func `a plain operation writes the continuation only to deliver values`() {
        for name in members(.operation) {
            let inty = seeded()
            Interpreter.language[name]!.act(on: inty)
            for item in inty.stacks[.exec]! where !item.isEqual(to: BoolItem(false)) {
                let delivers = item is IteratorItem
                    || (item as? InstructionItem)?.value == .iteratorPlay
                #expect(delivers, "\(name) put \(item.pretty()) on .exec")
            }
        }
    }
}
