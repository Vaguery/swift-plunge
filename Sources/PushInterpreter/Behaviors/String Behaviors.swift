////
////  String Behaviors.swift
////  Propeller in Swift
////
////  Created by William Tozier on 5/9/26.
////

import DequeModule

nonisolated extension Interpreter {

    static let stringButLast_Behavior =
        Behavior(
            .stringButLast,
            takes: [.string],
            fxn: { a, recording in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.dropLast(1)),
                            call: recording([x, InstructionItem(.stringButLast)]),
                            members: recording.pieces(x.origins().dropLast(1)))
                    )
                ]
            }
        )

    static let stringConcat_Behavior =
        Behavior(
            .stringConcat,
            takes: [.string, .string],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            y.value + x.value,
                            call: recording([y, x, InstructionItem(.stringConcat)]),
                            members: recording.pieces(y.origins(0) + x.origins(1)))
                    )
                ]
            }
        )

    static let stringConjChar_Behavior =
        Behavior(
            .stringConjChar,
            takes: [.string, .char],
            fxn: { a, recording in
                let (y, x) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            y.value + String(x.value),
                            call: recording([y, x, InstructionItem(.stringConjChar)]),
                            members: recording.pieces(y.origins() + [Origin.item(x)]))
                    )
                ]
            }
        )

    static let stringContains_Behavior =
        Behavior(
            .stringContains,
            reads: [.string, .string],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            // `firstRange(of:)` is stdlib and deterministic
                            // (empty substring ⇒ contained); plain `.contains`
                            // resolved to different overloads across Foundation
                            // / module contexts once this code left the app target.
                            y.value.firstRange(of: x.value) != nil,
                            call: recording(Behavior.reading([.string: 2], producing: .bool, from: [y, x, InstructionItem(.stringContains)])))
                    )
                ]
            }
        )

    static let stringContainsChar_Behavior =
        Behavior(
            .stringContainsChar,
            reads: [.string, .char],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.contains(y.value),
                            call: recording(Behavior.reading([.string: 1, .char: 1], producing: .bool, from: [y, x, InstructionItem(.stringContainsChar)])))
                    )
                ]
            }
        )

    /// The position of the first occurrence of the char; an error if there is none.
    static let stringIndexOfChar_Behavior =
        Behavior(
            .stringIndexOfChar,
            reads: [.string, .char],
            tags: [.fallible],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                if let idx = x.value.firstIndex(of: y.value) {
                    let intIdx = x.value.distance(
                        from: x.value.startIndex,
                        to: idx
                    )
                    return [
                        Router(
                            .int,
                            IntItem(
                                intIdx,
                                call: recording(Behavior.reading(
                                [.string: 1, .char: 1],
                                producing: .int,
                                from: [y, x, InstructionItem(.stringIndexOfChar)]
                            )))
                        )
                    ]
                } else {
                    return [Behavior.refusal(
                        "Not found in .stringIndexOfChar: \(y.value)",
                        kind: .notFound,
                        call: recording(Behavior.reading(
                            [.string: 1, .char: 1],
                            producing: .error,
                            from: [y, x, InstructionItem(.stringIndexOfChar)])))]
                }
            }
        )

    // the IntItem value is truncated at 0 before use as an index
    //
    static let stringDrop_Behavior =
        Behavior(
            .stringDrop,
            takes: [.string, .int],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                let toDrop = max(0, y.value)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.dropLast(toDrop)),
                            call: recording([y, x, InstructionItem(.stringDrop)]),
                            members: recording.pieces(x.origins().dropLast(toDrop)))
                    )
                ]
            }
        )

    // the IntItem value is truncated at 0 before use as an index
    //
    static let stringTake_Behavior =
        Behavior(
            .stringTake,
            takes: [.string, .int],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                let toTake = max(0, y.value)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.prefix(toTake)),
                            call: recording([y, x, InstructionItem(.stringTake)]),
                            members: recording.pieces(Array(x.origins().prefix(toTake))))
                    )
                ]
            }
        )

    static let stringItemIsEmpty_Behavior =
        Behavior(
            .stringItemIsEmpty,
            reads: [.string],
            fxn: { a, recording in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.isEmpty,
                            call: recording(Behavior.reading([.string: 1], producing: .bool, from: [x, InstructionItem(.stringItemIsEmpty)])))
                    )
                ]
            }
        )

    static let stringFirst_Behavior =
        Behavior(
            .stringFirst,
            takes: [.string],
            tags: [.fallible],
            fxn: { a, recording in
                let (x) = (a[0] as! StringItem)
                if let c = x.value.first {
                    // The char that went in, if it kept a history (`Containment`).
                    return [
                        Router(
                            .char,
                            x.traced(at: 0, c, recording) ?? CharItem(
                                c,
                                call: recording([x, InstructionItem(.stringFirst)]))
                        )
                    ]
                } else {
                    return [Behavior.refusal(
                        "Empty string in .stringFirst",
                        kind: .emptyCollection,
                        call: recording([x, InstructionItem(.stringFirst)]))]
                }
            }
        )

    static let stringLast_Behavior =
        Behavior(
            .stringLast,
            takes: [.string],
            tags: [.fallible],
            fxn: { a, recording in
                let (x) = (a[0] as! StringItem)
                if let c = x.value.last {
                    return [
                        Router(
                            .char,
                            x.traced(at: x.value.count - 1, c, recording) ?? CharItem(
                                c,
                                call: recording([x, InstructionItem(.stringLast)]))
                        )
                    ]
                } else {
                    return [Behavior.refusal(
                        "Empty string in .stringLast",
                        kind: .emptyCollection,
                        call: recording([x, InstructionItem(.stringLast)]))]
                }
            }
        )

    static let stringLTE_Behavior =
        Behavior(
            .stringLTE,
            reads: [.string, .string],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y <= x,
                            call: recording(Behavior.reading([.string: 2], producing: .bool, from: [y, x, InstructionItem(.stringLTE)])))
                    )
                ]
            }
        )

    static let stringLT_Behavior =
        Behavior(
            .stringLT,
            reads: [.string, .string],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y < x,
                            call: recording(Behavior.reading([.string: 2], producing: .bool, from: [y, x, InstructionItem(.stringLT)])))
                    )
                ]
            }
        )

    static let stringGT_Behavior =
        Behavior(
            .stringGT,
            reads: [.string, .string],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y > x,
                            call: recording(Behavior.reading([.string: 2], producing: .bool, from: [y, x, InstructionItem(.stringGT)])))
                    )
                ]
            }
        )

    static let stringGTE_Behavior =
        Behavior(
            .stringGTE,
            reads: [.string, .string],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y >= x,
                            call: recording(Behavior.reading([.string: 2], producing: .bool, from: [y, x, InstructionItem(.stringGTE)])))
                    )
                ]
            }
        )

    static let stringReverse_Behavior =
        Behavior(
            .stringReverse,
            takes: [.string],
            fxn: { a, recording in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.reversed()),
                            call: recording([x, InstructionItem(.stringReverse)]),
                            members: recording.pieces(x.origins().reversed()))
                    )
                ]
            }
        )

    static let stringLength_Behavior =
        Behavior(
            .stringLength,
            reads: [.string],
            fxn: { a, recording in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            x.value.count,
                            call: recording(Behavior.reading([.string: 1], producing: .int, from: [x, InstructionItem(.stringLength)])))
                    )
                ]
            }
        )

    static let stringFromBool_Behavior =
        Behavior(
            .stringFromBool,
            takes: [.bool],
            fxn: { a, recording in
                let (x) = (a[0] as! BoolItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: recording([x, InstructionItem(.stringFromBool)]))
                    )
                ]
            }
        )

    static let stringFromChar_Behavior =
        Behavior(
            .stringFromChar,
            takes: [.char],
            fxn: { a, recording in
                let (x) = (a[0] as! CharItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: recording([x, InstructionItem(.stringFromChar)]),
                            members: recording.pieces([Origin.item(x)]))
                    )
                ]
            }
        )

    static let stringFromDouble_Behavior =
        Behavior(
            .stringFromDouble,
            takes: [.double],
            fxn: { a, recording in
                let (x) = (a[0] as! DoubleItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: recording([x, InstructionItem(.stringFromDouble)]))
                    )
                ]
            }
        )

    static let stringFromInt_Behavior =
        Behavior(
            .stringFromInt,
            takes: [.int],
            fxn: { a, recording in
                let (x) = (a[0] as! IntItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: recording([x, InstructionItem(.stringFromInt)]))
                    )
                ]
            }
        )

    /// The char at the index, clamped to the string (`Position.item`); an error
    /// for an empty string.
    static let stringNth_Behavior =
        Behavior(
            .stringNth,
            takes: [.string, .int],
            tags: [.fallible],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                if x.value.isEmpty {
                    return [Behavior.refusal(
                        "Empty string in .stringNth",
                        kind: .emptyCollection,
                        call: recording([x, y, InstructionItem(.stringNth)]))]
                } else {
                    let position = Position.item(y.value, count: x.value.count)
                    let idx = x.value.index(
                        x.value.startIndex,
                        offsetBy: position
                    )
                    let c = x.value[idx]
                    return [
                        Router(
                            .char,
                            x.traced(at: position, c, recording) ?? CharItem(
                                c,
                                // `[string, index]`, matching the four `vecXNth`
                                // siblings. This used to be `[index, string]` —
                                // harmless in itself, since the two arguments come
                                // off different stacks and either order re-runs
                                // correctly, but the two families disagreeing meant
                                // an iterator walking a string could not record the
                                // same way one walking a vector did. The crux then
                                // stopped being a fixed point: re-running it
                                // produced a differently-worded crux for the same
                                // value. The fuzzer found it; see "Design
                                // Principles.md" on argument order being free only
                                // *across* stacks.
                                call: recording([x, y, InstructionItem(.stringNth)]))
                        )
                    ]
                }
            }
        )

    /// Pushes every character of a string to `.string` as a one-character
    /// *string* — not a char, which is the whole of the difference from
    /// `stringPushAllChars` — one per pass, front to back.
    ///
    /// One element per Character (grapheme), which the `.letters` projection gets
    /// by indexing rather than by `split(separator: "")`, whose empty-separator
    /// overload resolution is unstable across Foundation / module contexts.
    ///
    /// Each letter records `x 2 .stringNth .stringFromChar` — two instructions to
    /// reproduce, still O(1), and still independent of every other letter.
    static let stringParseToLetters_Behavior =
        Behavior(
            .stringParseToLetters,
            takes: [.string],
            fxn: { a, recording in
                let x = a[0] as! StringItem
                guard !x.value.isEmpty else { return [] }
                return Interpreter.iteratorLoop(
                    kind: .letters,
                    origin: x,
                    body: nil,
                    emits: true, recording: recording
                )
            }
        )

    static let stringOccurrencesOfChar_Behavior =
        Behavior(
            .stringOccurrencesOfChar,
            reads: [.string, .char],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            x.value.filter({ $0 == y.value }).count,
                            call: recording(Behavior.reading(
                                [.string: 1, .char: 1],
                                producing: .int,
                                from: [y, x, InstructionItem(.stringOccurrencesOfChar)]
                            )),
                        )
                    )
                ]
            }
        )

    static let stringRemoveChar_Behavior =
        Behavior(
            .stringRemoveChar,
            takes: [.string, .char],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            x.value.filter({ $0 != y.value }),
                            call: recording([y, x, InstructionItem(.stringRemoveChar)]),
                            members: recording.pieces(
                                zip(x.value, x.origins()).filter { $0.0 != y.value }.map(\.1)),
                        )
                    )
                ]
            }
        )

    // ( "0123" '2' '.' .stringReplaceChar ) -> "01.3"
    //
    static let stringReplaceChar_Behavior =
        Behavior(
            .stringReplaceChar,
            takes: [.string, .char, .char],
            fxn: { a, recording in
                let (x, y, z) = (
                    a[0] as! StringItem,
                    a[1] as! CharItem,
                    a[2] as! CharItem
                )
                return [
                    Router(
                        .string,
                        StringItem(
                            x.value.replacing(
                                String(z.value),
                                with: String(y.value)
                            ),
                            call: recording([
                                z, y, x, InstructionItem(.stringReplaceChar),
                            ]),
                            members: recording.pieces(
                                zip(x.value, x.origins()).map { $0.0 == z.value ? Origin.item(y) : $0.1 }),
                        )
                    )
                ]
            }
        )

    static let stringReplaceFirstChar_Behavior =
        Behavior(
            .stringReplaceFirstChar,
            takes: [.string, .char, .char],
            fxn: { a, recording in
                let (x, y, z) = (
                    a[0] as! StringItem,
                    a[1] as! CharItem,
                    a[2] as! CharItem
                )
                return [
                    Router(
                        .string,
                        StringItem(
                            x.value.replacing(
                                String(z.value),
                                with: String(y.value),
                                maxReplacements: 1
                            ),
                            call: recording([
                                z, y, x,
                                InstructionItem(.stringReplaceFirstChar),
                            ]),
                            members: recording.pieces(replacingFirstSlot(of: z.value, in: x, with: y)),
                        )
                    )
                ]
            }
        )

    // ("foo" "o" "g" .stringReplace) -> "fgg"
    //
    static let stringReplace_Behavior =
        Behavior(
            .stringReplace,
            takes: [.string, .string, .string],
            fxn: { a, recording in
                let (x, y, z) = (
                    a[0] as! StringItem,  // replacement
                    a[1] as! StringItem,  // target
                    a[2] as! StringItem
                )  // in this context
                return [
                    Router(
                        .string,
                        StringItem(
                            z.value.replacing(y.value, with: x.value),
                            call: recording([z, y, x, InstructionItem(.stringReplace)]),
                            members: recording.pieces(replacingSubstringSlots(z, y, x, firstOnly: false)),
                        )
                    )
                ]
            }
        )

    static let stringReplaceFirst_Behavior =
        Behavior(
            .stringReplaceFirst,
            takes: [.string, .string, .string],
            fxn: { a, recording in
                let (x, y, z) = (
                    a[0] as! StringItem,  // replacement
                    a[1] as! StringItem,  // target
                    a[2] as! StringItem
                )  // in this context
                return [
                    Router(
                        .string,
                        StringItem(
                            z.value.replacing(
                                y.value,
                                with: x.value,
                                maxReplacements: 1
                            ),
                            call: recording([z, y, x, InstructionItem(.stringReplaceFirst)]),
                            members: recording.pieces(replacingSubstringSlots(z, y, x, firstOnly: true)),
                        )
                    )
                ]
            }
        )

    static let stringRest_Behavior =
        Behavior(
            .stringRest,
            takes: [.string],
            fxn: { a, recording in
                var (x) = (a[0] as! StringItem)
                let result = String(x.value.dropFirst(1))
                return [
                    Router(
                        .string,
                        StringItem(
                            result,
                            call: recording([x, InstructionItem(.stringRest)]),
                            members: recording.pieces(Array(x.origins().dropFirst(1))),
                        )
                    )
                ]
            }
        )

    /// Replaces the char at the index, clamped to the string (`Position.item`).
    /// An empty string has no char to replace, so it is an error.
    static let stringSetChar_Behavior =
        Behavior(
            .stringSetChar,
            takes: [.string, .int, .char],
            tags: [.fallible],
            fxn: { a, recording in
                let (x, y, z) = (
                    a[0] as! StringItem,
                    a[1] as! IntItem,
                    a[2] as! CharItem
                )
                guard !x.value.isEmpty else {
                    return [Behavior.refusal(
                        "Empty string in .stringSetChar",
                        kind: .emptyCollection,
                        call: recording([z, y, x, InstructionItem(.stringSetChar)]))]
                }
                var result = x.value
                let position = Position.item(y.value, count: result.count)
                let idx = result.index(result.startIndex, offsetBy: position)
                result.replaceSubrange(idx...idx, with: String(z.value))
                func members() -> [Origin] {
                    var slots = x.origins()
                    slots[position] = Origin.item(z)
                    return slots
                }
                return [
                    Router(
                        .string,
                        StringItem(
                            result,
                            call: recording([z, y, x, InstructionItem(.stringSetChar)]),
                            members: recording.pieces(members()))
                    )
                ]
            }
        )

    /// Pushes every whitespace-delimited word of a string to `.string`, one per
    /// pass, front to back. A string with no words produces nothing.
    ///
    /// The odd one of the explode family: a word is not `origin[i]`, so no
    /// existing instruction could name it and `.stringNthWord` had to be added
    /// for these to have a record at all. That is the price of the last law-5
    /// user, and it buys a genuinely useful instruction — "the nth word of a
    /// string" is a thing a program wants regardless.
    static let stringSplit_Behavior =
        Behavior(
            .stringSplit,
            takes: [.string],
            fxn: { a, recording in
                let x = a[0] as! StringItem
                guard !x.value.split(whereSeparator: { $0.isWhitespace }).isEmpty
                else { return [] }
                return Interpreter.iteratorLoop(
                    kind: .words,
                    origin: x,
                    body: nil,
                    emits: true, recording: recording
                )
            }
        )

    /// The `n`th whitespace-delimited word of a string, the index clamped to the
    /// word count like its `stringNth` sibling. A string with no words is an
    /// error: there is no word to return (Roadmap #42).
    ///
    /// Added for `stringSplit`'s iterator to have something honest to record, but
    /// useful in its own right.
    static let stringNthWord_Behavior =
        Behavior(
            .stringNthWord,
            takes: [.string, .int],
            tags: [.fallible],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                let words = x.value.split { $0.isWhitespace }
                guard !words.isEmpty else {
                    return [Behavior.refusal(
                        "No words in .stringNthWord",
                        kind: .emptyCollection,
                        call: recording([x, y, InstructionItem(.stringNthWord)]))]
                }
                let idx = Position.item(y.value, count: words.count)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(words[idx]),
                            // `[string, index]`, matching `stringNth` and the four
                            // `vecXNth` siblings.
                            call: recording([x, y, InstructionItem(.stringNthWord)]),
                            members: recording.pieces(x.origins(of: words[idx])))
                    )
                ]
            }
        )

    /// Snips a string into two pieces at the indexed position, pushing **both** to
    /// `.string`: the prefix deeper, the suffix on top — so `stringCut` then
    /// `stringConcat` is the identity (concat consumes the deeper piece first).
    ///
    /// The index names a **gap** and is clamped to `0…count` (`Position.gap`): a
    /// cut at 0 gives an empty prefix, a cut at the count an empty suffix, and
    /// cutting an empty string gives two empty strings. (It used to wrap modulo
    /// the character count, which left the last gap unreachable.) Character
    /// counting is by grapheme, like every other string instruction here.
    ///
    /// Provenance is law 5 (`Behavior.selecting`): the deeper piece records
    /// `x y .stringCut 1 .stringPopItems`, the top piece just the cut.
    static let stringCut_Behavior =
        Behavior(
            .stringCut,
            takes: [.string, .int],
            fxn: { a, recording in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                let idx = Position.gap(y.value, count: x.value.count)
                let cut = x.value.index(x.value.startIndex, offsetBy: idx)

                let source: [any Item] = [x, y, InstructionItem(.stringCut)]
                return [
                    Router(.string, StringItem(
                        String(x.value[..<cut]),
                        call: recording(Behavior.selecting(0, of: 2, on: .string, from: source)),
                        members: recording.pieces(Array(x.origins().prefix(idx))))),
                    Router(.string, StringItem(
                        String(x.value[cut...]),
                        call: recording(Behavior.selecting(1, of: 2, on: .string, from: source)),
                        members: recording.pieces(Array(x.origins().dropFirst(idx))))),
                ]
            }
        )

    static let stringSubstring_Behavior =
        Behavior(
            .stringSubstring,
            takes: [.string, .int, .int],
            fxn: { a, recording in
                let (x, y, z) = (
                    a[0] as! StringItem,
                    a[1] as! IntItem,
                    a[2] as! IntItem
                )

                var result = x.value
                var slice = Substring(result)
                if result.count > 0 {
                    let range = result.count - 1
                    let lhs = min(range, max(0, z.value))
                    let rhs = min(range, max(0, z.value, y.value))
                    let start = result.index(result.startIndex, offsetBy: lhs)
                    let end = result.index(result.startIndex, offsetBy: rhs)
                    slice = result[start...end]
                }
                return [
                    Router(
                        .string,
                        StringItem(
                            String(slice),
                            call: recording([x, z, y, InstructionItem(.stringSubstring)]),
                            members: recording.pieces(x.origins(of: slice)))
                    )
                ]
            }
        )

    // ( "abcd" .stringIterate MOUSE )
    //
    // index:        4          3          2                   1          0
    // reults: ( exec:MOUSE exec:"bcd" exec:.stringIterate exec:MOUSE char:'a' )
    /// Runs the mouse once per character of the string, leaving each character on
    /// `.char` for it to read.
    ///
    /// **The mouse** is the loop body — the block re-supplied to `.code` on every
    /// pass, which is why it survives being consumed. The name is inherited; the
    /// iterator holds it now, and the re-supply is gone with everything else the
    /// loop used to rebuild.
    ///
    /// It used to carry its own state in Push: each pass re-pushed the *remaining*
    /// string and a fresh `.stringIterate` token, so the shrinking remainder was a
    /// derived value with `[previous, .stringRest]` for a record — one level
    /// deeper per character, O(n) and bounded only by the `maxCallWeight`
    /// backstop, which means a long string lost its story. The iterator keeps the
    /// whole string and a cursor instead, so each character records
    /// `s 2 .stringNth`: O(1), independent of the others, and independent of how
    /// many passes have run.
    static let stringIterate_Behavior =
        Behavior(
            .stringIterate,
            takes: [.string, .code],
            tags: [.reEntrant],
            as: .control,
            fxn: { a, recording in
                let (x, mouse) = (a[0] as! StringItem, a[1] as! CodeItem)
                // No passes: the body goes back to `.code`, as a finished loop's does.
                guard !x.value.isEmpty else { return [Router(.code, mouse)] }
                return Interpreter.iteratorLoop(
                    kind: .elements(into: nil),
                    origin: x,
                    body: mouse,
                    emits: true, recording: recording
                )
            }
        )

    /// Pushes every character of a string to `.char`, **one per pass**, front to
    /// back — so the last character ends up on top.
    ///
    /// It used to do this in a single step, which is the thing this whole family
    /// was reworked to stop doing: a loop refusing to be one. Exploding all at
    /// once put the work outside `stepLimit` and the runaway guard's reach, and it
    /// forced every character to record *which of the pile it was* —
    /// `s .stringPushAllChars 3 .charPopItems`, a law-5 selection. Now each
    /// character just says what it is, `s 2 .stringNth`: independent, O(1), and
    /// true regardless of how many passes have run.
    ///
    /// A sequence, not a loop: the iterator has no body, so a pass costs one step
    /// rather than three.
    static let stringPushAllChars_Behavior =
        Behavior(
            .stringPushAllChars,
            takes: [.string],
            fxn: { a, recording in
                let s = a[0] as! StringItem
                guard !s.value.isEmpty else { return [] }
                return Interpreter.iteratorLoop(
                    kind: .elements(into: nil),
                    origin: s,
                    body: nil,
                    emits: true, recording: recording
                )
            }
        )

    // MARK: - Members (`Pieces`)

    /// `x`'s origins with the first `target` character's replaced by `char`,
    /// as `.stringReplaceFirstChar` replaces the character. Called only when
    /// recording.
    static func replacingFirstSlot(of target: Character, in x: StringItem, with char: CharItem) -> [Origin] {
        var origins = x.origins()
        if let position = Array(x.value).firstIndex(of: target) { origins[position] = .item(char) }
        return origins
    }

    /// The origins of `.stringReplace`/`.stringReplaceFirst`'s result: each
    /// character's origin travels with it, from the subject or the replacement. The
    /// same left-to-right scan as the vectors' sub-vector replace; where it would
    /// not line up with Swift's own `replacing` (an empty target), the result's
    /// alignment check drops the members. Called only when recording.
    static func replacingSubstringSlots(
        _ subject: StringItem, _ target: StringItem, _ replacement: StringItem, firstOnly: Bool
    ) -> [Origin] {
        typealias Slotted = (value: Character, slot: Origin)
        func slotted(_ string: StringItem, _ tag: Int) -> [Slotted] {
            zip(string.value, string.origins(tag)).map { ($0, $1) }
        }
        return replacingSub(slotted(subject, 0), slotted(target, 2), slotted(replacement, 1), firstOnly: firstOnly) {
            $0.value == $1.value
        }.map(\.slot)
    }

    static let stringBehaviors:[PushInstruction : Behavior] =
        [
        .stringButLast : stringButLast_Behavior,
        .stringConcat : stringConcat_Behavior,
        .stringConjChar : stringConjChar_Behavior,
        .stringContains : stringContains_Behavior,
        .stringContainsChar : stringContainsChar_Behavior,
        .stringDrop : stringDrop_Behavior,
        .stringFirst : stringFirst_Behavior,
        .stringFromBool : stringFromBool_Behavior,
        .stringFromChar : stringFromChar_Behavior,
        .stringFromDouble : stringFromDouble_Behavior,
        .stringFromInt : stringFromInt_Behavior,
        .stringIndexOfChar : stringIndexOfChar_Behavior,
        .stringItemIsEmpty : stringItemIsEmpty_Behavior,
        .stringIterate : stringIterate_Behavior,
        .stringLast : stringLast_Behavior,
        .stringLength : stringLength_Behavior,
        .stringNth : stringNth_Behavior,
        .stringNthWord : stringNthWord_Behavior,
        .stringOccurrencesOfChar : stringOccurrencesOfChar_Behavior,
        .stringParseToLetters : stringParseToLetters_Behavior,
        .stringPushAllChars : stringPushAllChars_Behavior,
        .stringRemoveChar : stringRemoveChar_Behavior,
        .stringReplace : stringReplace_Behavior,
        .stringReplaceChar : stringReplaceChar_Behavior,
        .stringReplaceFirst : stringReplaceFirst_Behavior,
        .stringReplaceFirstChar : stringReplaceFirstChar_Behavior,
        .stringRest : stringRest_Behavior,
        .stringReverse : stringReverse_Behavior,
        .stringSetChar : stringSetChar_Behavior,
        .stringSplit : stringSplit_Behavior,
        .stringCut : stringCut_Behavior,
        .stringSubstring : stringSubstring_Behavior,
        .stringTake : stringTake_Behavior,
        ]
}
