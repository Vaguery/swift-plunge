//
//  ErrorItem.swift
//  Plunge
//
//  Errors as items, and the kinds that classify them.
//  Split out of Items.swift, which keeps the `Item` protocol and the provenance law.
//

import Foundation


// Why an error was raised, as a value rather than as prose.
//
// The message already says this in English, and for a long time that was the only
// record. Counting them needed better: `.errorMissingArgCount` and its siblings
// have to partition the `.error` stack exactly, and a filter on
// `value.contains("missing args")` would silently under-report the first time
// anybody reworded a message. A count that quietly drifts is worse than no count.
//
// The cases split by **who noticed**, which is also what a program can act on:
// starvation it could fix by supplying arguments, an unbound name it could fix by
// binding one, and the interpreter's own refusals, which it cannot fix at all.
//
/// Why an error was raised, as a value that can be counted.
///
/// An error's message says the same thing in words, but messages may be
/// reworded from one version to the next, and kinds are stable. The kinds
/// separate what a program might act on: starvation, which more arguments
/// would cure; an input or a constant that was never supplied; and refusals of
/// several sorts. See <doc:ErrorsAndRefusals>.
public nonisolated enum ErrorKind: String, Sendable, Codable, CaseIterable {
    /// An instruction starved: a stack it needed held too few items.
    case missingArgument
    /// An input instruction, such as `.input2`, ran with no input bound to it.
    case missingInput
    /// A constant instruction, such as `.int3`, ran with no constant bound to it.
    case missingConstant
    /// A push the interpreter would not accept: an item over a size limit, a full
    /// stack, or a sandbox nested too deep.
    case sizeRefusal
    /// A bug in the interpreter itself, not in the program. Its message begins `INVARIANT:`.
    case invariant
    /// A guard stopped the run early. The message begins `RUNAWAY:` or `MEMORY:`.
    case guardStop
    /// An element was asked of a collection that has none: the first of an empty
    /// vector, a root item of `( )`, a word of a string with no words. An index
    /// into a collection that has elements is clamped and never causes an error;
    /// this is the one case where no position exists.
    case emptyCollection
    // A search that found nothing: `.vecIntIndexOf`, `.stringIndexOf`,
    // `.codeIndexOf`, `.codeContainer`. These used to answer `-1` (which
    // every index-taking instruction would then quietly accept) or nothing at all.
    //
    /// A miss: an instruction looked for an item and found none that fits. A
    /// lookup or a find with no match, a key with no binding, and a missing
    /// function of the right shape all give this kind.
    case notFound
    /// A value with no counterpart in the type asked for: a string that is not a
    /// number, an int that is not a Unicode scalar.
    case conversion
    /// A result that can't be held: an integer past `Int`'s range or a double
    /// that isn't finite, in a scalar or in one element of a vector.
    case overflow
    /// A division or a remainder by zero.
    case divideByZero
    /// An operation with no answer for these values: the root or logarithm of a
    /// negative number, a negative power of an int, a setting this kind of
    /// iterator doesn't have.
    case undefined
    /// A count, a step or a stride the instruction can't use: negative, zero, or
    /// pointing the wrong way.
    case badCount
    /// Items that can't be collected into one vector: of several types, or of a
    /// type no vector holds.
    case mixedTypes
    /// An instruction the run doesn't have: one that is disabled.
    case unknownInstruction
    /// An instruction that reads a crux, in a run that isn't recording provenance.
    case needsProvenance
    /// A function or a derivation run inside an instruction used up the steps
    /// it was allowed.
    case outOfSteps
    /// Any other refusal.
    case other
}

/// A record of something that went wrong: an item of the `.error` stack.
///
/// An error has a message for people (``value``) and a ``kind`` for counting.
/// It is a record, not an exception: the program that caused it carries on.
/// See <doc:ErrorsAndRefusals>.
public nonisolated struct ErrorItem: Item, Equatable {
    /// The message, a sentence for people. Read as text everywhere, but stored as
    /// data for the one error that is raised constantly — an instruction starved of
    /// arguments, the most common event in a random program — whose text is only
    /// built when someone reads it. Profiling found that formatting it eagerly cost
    /// ~4% of all interpreter time, nearly always for a message nobody reads.
    ///
    /// The message is kept for logs and debugging. It is not printed by `pretty()`
    /// and not compared by `==`, which use ``kind`` and ``source``.
    public var value: String {
        get {
            switch message {
            case .text(let text): text.text
            case .missingArguments(let instruction, let stack): "\(instruction) missing args: .\(stack)"
            }
        }
        set { message = .text(Text(text: newValue, kind: kind, source: source)) }
    }

    /// The message, and with it the kind and the source, in one word plus a tag. A
    /// free-text message, its kind and its source sit behind a reference (`Text`) so
    /// that an `ErrorItem` fits the three words an `any Item` holds inline (see
    /// `CallStorage`): the common error, a starved instruction's, then costs no
    /// allocation at all. A free-text one costs one, as its `String` usually did
    /// anyway.
    enum Message: Sendable {
        case text(Text)
        case missingArguments(PushInstruction, PushStack)
    }

    final class Text: Sendable {
        let text: String
        let kind: ErrorKind
        let source: PushInstruction?
        init(text: String, kind: ErrorKind, source: PushInstruction?) {
            self.text = text; self.kind = kind; self.source = source
        }
    }
    private var message: Message

    /// Why this error was raised: its class, as one word. See `ErrorKind`.
    public var kind: ErrorKind {
        get {
            switch message {
            case .text(let text): text.kind
            case .missingArguments: .missingArgument
            }
        }
        set { message = .text(Text(text: value, kind: newValue, source: source)) }
    }

    /// The instruction that raised this error, or `nil` when the interpreter
    /// itself did (a size refusal at a push, a guard stopping the run).
    public var source: PushInstruction? {
        switch message {
        case .text(let text): text.source
        case .missingArguments(let instruction, _): instruction
        }
    }

    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    /// The size and depth of this item's history.
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }


    /// Creates an error with a message, its kind and the instruction that raised
    /// it. Leave `call` empty: the interpreter fills in histories as it runs.
    public init(_ value: String, kind: ErrorKind = .other, source: PushInstruction? = nil, call: [any Item] = []) {
        self.message = .text(Text(text: value, kind: kind, source: source))
        self.callStorage = CallStorage(call)
    }

    /// A starved instruction's refusal: `intAdd missing args: .int`, built on read.
    init(missingArgumentsFor instruction: PushInstruction, on stack: PushStack) {
        self.message = .missingArguments(instruction, stack)
        self.callStorage = .literal
    }

    /// Two errors are equal when they have the same kind and the same source:
    /// what `pretty()` prints. The message is a description for people, not part
    /// of the error's identity, so two overflows in `.intAdd` are the same error
    /// whatever numbers were involved.
    public static func == (lhs: ErrorItem, rhs: ErrorItem) -> Bool {
        lhs.kind == rhs.kind && lhs.source == rhs.source
    }

    /// `«err overflow: .intAdd»`: the kind, then the instruction that raised it.
    /// An error the interpreter raised itself has no instruction:
    /// `«err sizeRefusal»`. Everything after the colon is ordinary code, so the
    /// form reads back without any free text; the sentence is in ``value``.
    public func pretty() -> String {
        let tag = PushStack.error.tag
        return source.map { "«\(tag) \(kind.rawValue): .\($0.rawValue)»" } ?? "«\(tag) \(kind.rawValue)»"
    }
}
