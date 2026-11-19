//
//  InputSlot.swift
//  Plunge
//
//  A problem's inputs, declared: what each is called and what type its values
//  have (2026-11-19, swift-plunge #55).
//

/// One of a problem's inputs, as a configuration declares it: a name to show,
/// and the type every value bound to it must have.
///
/// A configuration's ``RunnerConfiguration/inputSlots`` are in slot order: the
/// first declares `.input0`, the second `.input1`, and so on. See
/// <doc:InputsAndConstants>.
public nonisolated struct InputSlot: Sendable, Codable, Hashable {
    /// What the input is called, such as `x1`. A program rendered with
    /// `labeled(_:)` shows `.input-x1` in place
    /// of `.input0`. The name is only for people: a program, its crux and its
    /// encoding always say `.input0`, so they mean the same thing whatever
    /// problem they run on. Nil shows the slot number.
    public var name: String?
    /// The stack every value bound to the input must rest on, or nil to accept any
    /// item.
    ///
    /// For an input whose values have different types from case to case, declare
    /// `.binding` and bind each value inside a ``BindingItem``: the slot then has
    /// one type, whatever the pair holds.
    public var stack: PushStack?

    /// Creates a declaration. Both parts are optional.
    public init(_ name: String? = nil, stack: PushStack? = nil) {
        self.name = name
        self.stack = stack
    }
}


/// A training case's input that its configuration's declarations don't allow.
public nonisolated struct InputMismatch: Sendable, Hashable, CustomStringConvertible {
    /// Why the input isn't allowed.
    public enum Reason: Sendable, Hashable {
        /// The configuration declares inputs, and not this one.
        case undeclared
        /// The value doesn't rest on the declared stack. `found` is where it does
        /// rest, if anywhere.
        case wrongType(declared: PushStack, found: PushStack?)
    }

    /// The training case's identifier.
    public let trainingCase: String
    /// The input instruction the value is bound to.
    public let input: PushInstruction
    /// Why it isn't allowed.
    public let reason: Reason

    public var description: String {
        switch reason {
        case .undeclared:
            "case \(trainingCase) binds .\(input), which is not declared"
        case .wrongType(let declared, let found):
            "case \(trainingCase) binds .\(input) to \(found.map { "a \($0) item" } ?? "an item that rests nowhere")"
                + ", but it is declared \(declared)"
        }
    }
}


public nonisolated extension RunnerConfiguration {

    /// The declaration for `input`, if the configuration has one.
    func inputSlot(for input: PushInstruction) -> InputSlot? {
        guard case .input(let slot) = input, slot >= 0, slot < inputSlots.count else { return nil }
        return inputSlots[slot]
    }

    /// The name of each input that has one, keyed by its instruction.
    var inputNames: [PushInstruction: String] {
        var names: [PushInstruction: String] = [:]
        for (slot, declaration) in inputSlots.enumerated() {
            if let name = declaration.name { names[.input(slot)] = name }
        }
        return names
    }

    /// What is wrong with the declarations, in words: names that are empty,
    /// contain white space, or repeat. Empty when they are fine. (Any number of
    /// inputs can be declared: the inputs are a family with no last member.)
    var inputSlotIssues: [String] {
        var issues: [String] = []
        var seen = Set<String>()
        for (slot, declaration) in inputSlots.enumerated() {
            guard let name = declaration.name else { continue }
            if name.isEmpty {
                issues.append("input \(slot)'s name is empty")
            } else if name.contains(where: \.isWhitespace) {
                issues.append("input \(slot)'s name, \"\(name)\", contains white space")
            } else if !seen.insert(name).inserted {
                issues.append("the name \"\(name)\" is declared more than once")
            }
        }
        return issues
    }

    /// The inputs of `trainingCase` that the declarations don't allow. Empty when
    /// the configuration declares no inputs, since then any input of any type is
    /// allowed.
    func mismatches(in trainingCase: TrainingCase) -> [InputMismatch] {
        guard !inputSlots.isEmpty else { return [] }
        var found: [InputMismatch] = []
        for (input, value) in trainingCase.inputs {
            guard let declaration = inputSlot(for: input) else {
                found.append(InputMismatch(trainingCase: trainingCase.id, input: input, reason: .undeclared))
                continue
            }
            if let stack = declaration.stack, !stack.accepts(value) {
                let rests = PushStack.defaultStack(for: value)
                found.append(InputMismatch(trainingCase: trainingCase.id, input: input,
                                           reason: .wrongType(declared: stack, found: rests)))
            }
        }
        return found.sorted { $0.input.rawValue < $1.input.rawValue }
    }

    /// `item` written as `pretty()` writes it, with each named input shown
    /// by its name: `.input-x1` for `.input0` declared `x1`.
    ///
    /// Only for people. A program's meaning, its crux and its encoding keep the
    /// slot instruction, and so does `pretty()`.
    func labeled(_ item: any Item) -> String {
        NestedRendering.render(item, labels: renderedLabels)
    }

    /// `items` labeled one by one and joined with spaces: a program, or a crux.
    func labeled(_ items: [any Item]) -> String {
        let labels = renderedLabels
        return items.map { NestedRendering.render($0, labels: labels) }.joined(separator: " ")
    }

    /// What `instruction` takes and gives under this configuration: its
    /// ``Runner/signature(of:)``, except that an input declared with a type gives a
    /// value on that type's stack, deferred like a constant.
    ///
    /// An input declared `.code` or `.exec` keeps the language's signature, since a
    /// code block popped off `.exec` runs instead of coming to rest.
    func signature(of instruction: PushInstruction) -> InstructionSignature? {
        guard instruction.slot.map({ $0 >= 0 }) ?? true,
              let base = Interpreter.signatures[instruction.representative] else { return nil }
        guard let stack = inputSlot(for: instruction)?.stack, stack != .code, stack != .exec else { return base }
        return InstructionSignature(consumes: base.consumes, reads: base.reads, needs: base.needs,
                                    variadic: base.variadic, observes: base.observes,
                                    produces: .deferred(stack), isPartial: base.isPartial)
    }
}


nonisolated extension RunnerConfiguration {

    /// The text each named input is shown as: `.input-x1`.
    var renderedLabels: [PushInstruction: String] {
        inputNames.mapValues { ".input-\($0)" }
    }

    /// `trainingCase`'s inputs, less those the declarations don't allow.
    func allowedInputs(of trainingCase: TrainingCase) -> [PushInstruction: any Item] {
        guard !inputSlots.isEmpty else { return trainingCase.inputs }
        let refused = Set(mismatches(in: trainingCase).map(\.input))
        return refused.isEmpty ? trainingCase.inputs : trainingCase.inputs.filter { !refused.contains($0.key) }
    }
}
