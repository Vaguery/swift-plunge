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
    /// Any other refusal (a division by zero, an overflow, a negative count), and
    /// an instruction that is disabled.
    case other
}

/// A record of something that went wrong: an item of the `.error` stack.
///
/// An error has a message for people (``value``) and a ``kind`` for counting.
/// It is a record, not an exception: the program that caused it carries on.
/// See <doc:ErrorsAndRefusals>.
public nonisolated struct ErrorItem: Item, Equatable {
    /// The message. Read as text everywhere, but stored as data for the one error
    /// that is raised constantly — an instruction starved of arguments, the most
    /// common event in a random program — whose text is only built when someone
    /// reads it. Profiling found that formatting it eagerly cost ~4% of all
    /// interpreter time, nearly always for a message nobody reads.
    public var value: String {
        get {
            switch message {
            case .text(let text): text.text
            case .missingArguments(let instruction, let stack): "\(instruction) missing args: .\(stack)"
            }
        }
        set { message = .text(Text(text: newValue, kind: kind)) }
    }

    /// The message, and with it the kind, in one word plus a tag. A free-text
    /// message and its kind sit behind a reference (`Text`) so that an `ErrorItem`
    /// fits the three words an `any Item` holds inline (see `CallStorage`): the
    /// common error, a starved instruction's, then costs no allocation at all. A
    /// free-text one costs one, as its `String` usually did anyway.
    enum Message: Sendable {
        case text(Text)
        case missingArguments(PushInstruction, PushStack)
    }

    final class Text: Sendable {
        let text: String
        let kind: ErrorKind
        init(text: String, kind: ErrorKind) { self.text = text; self.kind = kind }
    }
    private var message: Message

    /// Why this error was raised. See `ErrorKind`.
    ///
    /// Deliberately **not** part of `==`, which compares `value` alone like every
    /// other Item: two errors with the same message are the same error, and the
    /// kind is a classification of it rather than part of its identity.
    public var kind: ErrorKind {
        get {
            switch message {
            case .text(let text): text.kind
            case .missingArguments: .missingArgument
            }
        }
        set { message = .text(Text(text: value, kind: newValue)) }
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


    /// Creates an item holding `value`. Leave `call` empty: the interpreter fills
    /// in histories as it runs.
    public init(_ value: String, kind: ErrorKind = .other, call: [any Item] = []) {
        self.message = .text(Text(text: value, kind: kind))
        self.callStorage = CallStorage(call)
    }

    /// A starved instruction's refusal: `intAdd missing args: .int`, built on read.
    init(missingArgumentsFor instruction: PushInstruction, on stack: PushStack) {
        self.message = .missingArguments(instruction, stack)
        self.callStorage = .literal
    }

    public static func == (lhs: ErrorItem, rhs: ErrorItem) -> Bool {
        lhs.value == rhs.value
    }

    public func pretty() -> String {
        "« ‼️ \(value) »"
    }
}
