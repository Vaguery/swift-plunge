//
//  Conversion Behaviors.swift
//  PushInterpreter
//
//  Between code and vectors, between chars and strings, and between a string
//  and its pieces (*Behavior coverage audit (2026-11-09)*, P4).
//
//  - **`vecXQuote`** wraps a vector into a block as every other `Quote` does,
//    so vectors are no longer the one data type that cannot become code.
//  - **`vecFromCode`** reads a block back into a vector. Its type is read off
//    the contents, uniform or refuse, as `vecFromIterator` does; a block holding
//    exactly one vector gives that vector, so `vecXQuote` then `vecFromCode` is
//    the identity.
//  - **`stringFromChars`** and **`stringReadStack`** collect chars into a
//    string, reading them and leaving them, as `vecXReadItems` and
//    `vecXReadStack` do for scalars. Chars could be taken out of a string but
//    never put back.
//  - **`stringSplitOn`** and **`vecStringJoin`** split on, and join with, an
//    explicit separator; `join(split(s, sep), sep)` is `s`.
//

nonisolated extension Interpreter {

    // MARK: - Vectors and code

    static let vecBoolQuote_Behavior =
        Behavior.composing(.vecBoolQuote, takes: VecBoolItem.self, gives: CodeItem.self) { x in [x] }
    static let vecIntQuote_Behavior =
        Behavior.composing(.vecIntQuote, takes: VecIntItem.self, gives: CodeItem.self) { x in [x] }
    static let vecDoubleQuote_Behavior =
        Behavior.composing(.vecDoubleQuote, takes: VecDoubleItem.self, gives: CodeItem.self) { x in [x] }
    static let vecStringQuote_Behavior =
        Behavior.composing(.vecStringQuote, takes: VecStringItem.self, gives: CodeItem.self) { x in [x] }

    static let vecFromCode_Behavior =
        Behavior(
            .vecFromCode,
            takes: [.code],
            tags: [.fallible],
            produces: .alternatives([[.vecBool], [.vecDouble], [.vecInt], [.vecString]]),
            fxn: { a, recording in
                let block = a[0] as! CodeItem
                let items = block.value

                func refuse(_ why: String) -> [Router] {
                    [Router(.error, ErrorItem("vecFromCode: \(why)").observed(by: .vecFromCode, recording))]
                }

                // `( [1, 2, 3] )` denotes its one vector: the inverse of `vecXQuote`.
                // The vector is the item that went in, with its own history.
                if items.count == 1, let vector = items[0] as? any VectorItem {
                    return [Router(type(of: vector).pushStack, vector)]
                }
                guard !items.isEmpty else { return refuse("an empty block has no element type") }

                let call: [any Item] = [block, InstructionItem(.vecFromCode)]
                let members = recording.pieces(items.map { Origin.item($0) })
                let vector: (any Item)? =
                    if let values = items as? [BoolItem] {
                        VecBoolItem(values.map(\.value), call: recording(call), members: members)
                    } else if let values = items as? [IntItem] {
                        VecIntItem(values.map(\.value), call: recording(call), members: members)
                    } else if let values = items as? [DoubleItem] {
                        VecDoubleItem(values.map(\.value), call: recording(call), members: members)
                    } else if let values = items as? [StringItem] {
                        VecStringItem(values.map(\.value), call: recording(call), members: members)
                    } else {
                        nil
                    }
                guard let vector, let stack = PushStack.defaultStack(for: vector) else {
                    return refuse("\(block.pretty()) is not a block of one scalar type")
                }
                return [Router(stack, vector)]
            }
        )


    // MARK: - Chars into strings

    /// The `call` of a string read from `chars` (in string order): re-push them,
    /// read them with `stringFromChars`, and pop what was read.
    static func charsCrux(_ chars: [CharItem]) -> [any Item] {
        Behavior.reading(
            [.char: chars.count],
            producing: .string,
            from: chars.map { $0 as any Item } + [IntItem(chars.count), InstructionItem(.stringFromChars)]
        )
    }

    /// A string of the top `k` chars, leaving them in place; `k` is clamped to
    /// what there is. Top-first, reversed, so the inverse of
    /// `stringPushAllChars`, as `vecXReadItems` is of `vecXPushAll`.
    static let stringFromChars_Behavior =
        Behavior.contextRead(.stringFromChars, takes: [.int], produces: .results([.string])) { collected, context in
            let n = (collected[0] as! IntItem).value
            let items = context.items(of: .char)
            let k = Position.gap(n, count: items.count)
            let chars = Array(items.prefix(k)).map { $0 as! CharItem }.reversed().map { $0 }
            return [Router(.string, StringItem(String(chars.map(\.value)),
                                               call: context.recording(charsCrux(chars)),
                                               members: context.recording.pieces(chars.map { Origin.item($0) })))]
        }

    /// A string of every char on `.char`, leaving them; empty if there are none.
    /// Its crux reads them back with `stringFromChars`, so it composes.
    static let stringReadStack_Behavior =
        Behavior.contextRead(.stringReadStack, produces: .results([.string])) { _, context in
            let chars = Array(context.items(of: .char)).map { $0 as! CharItem }.reversed().map { $0 }
            return [Router(.string, StringItem(String(chars.map(\.value)),
                                               call: context.recording(charsCrux(chars)),
                                               members: context.recording.pieces(chars.map { Origin.item($0) })))]
        }


    // MARK: - A string and its pieces

    /// `s sep .stringSplitOn`: the pieces of `s` between occurrences of `sep`,
    /// empty pieces included, so joining them with `sep` gives `s` back. An
    /// empty separator splits into letters.
    static let stringSplitOn_Behavior =
        Behavior.operation(.stringSplitOn, takes: StringItem.self, StringItem.self,
                           gives: VecStringItem.self) { s, separator in
            guard !separator.isEmpty else { return s.map { String($0) } }
            return s.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
        }

    /// `v sep .vecStringJoin`: the strings of `v` with `sep` between each two.
    static let vecStringJoin_Behavior =
        Behavior.operation(.vecStringJoin, takes: VecStringItem.self, StringItem.self,
                           gives: StringItem.self) { v, separator in
            v.joined(separator: separator)
        }


    // MARK: - The family

    static let conversionBehaviors: [PushInstruction: Behavior] = [
        .vecBoolQuote: vecBoolQuote_Behavior,
        .vecIntQuote: vecIntQuote_Behavior,
        .vecDoubleQuote: vecDoubleQuote_Behavior,
        .vecStringQuote: vecStringQuote_Behavior,
        .vecFromCode: vecFromCode_Behavior,
        .stringFromChars: stringFromChars_Behavior,
        .stringReadStack: stringReadStack_Behavior,
        .stringSplitOn: stringSplitOn_Behavior,
        .vecStringJoin: vecStringJoin_Behavior
    ]
}
