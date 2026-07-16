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
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.dropLast(1)),
                            call: [x, InstructionItem(.stringButLast)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringConcat_Behavior =
        Behavior(
            .stringConcat,
            takes: [.string, .string],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            y.value + x.value,
                            call: [y, x, InstructionItem(.stringConcat)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringConjChar_Behavior =
        Behavior(
            .stringConjChar,
            takes: [.string, .char],
            fxn: { a in
                let (y, x) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            y.value + String(x.value),
                            call: [y, x, InstructionItem(.stringConjChar)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringContains_Behavior =
        Behavior(
            .stringContains,
            takes: [.string, .string],
            fxn: { a in
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
                            call: [y, x, InstructionItem(.stringContains)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringContainsChar_Behavior =
        Behavior(
            .stringContainsChar,
            takes: [.string, .char],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.contains(y.value),
                            call: [y, x, InstructionItem(.stringContainsChar)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringIndexOfChar_Behavior =
        Behavior(
            .stringIndexOfChar,
            takes: [.string, .char],
            fxn: { a in
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
                                call: [
                                    y, x, InstructionItem(.stringIndexOfChar),
                                ],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                } else {
                    return []  // not found
                }
            }
        )

    // the IntItem value is truncated at 0 before use as an index
    //
    static let stringDrop_Behavior =
        Behavior(
            .stringDrop,
            takes: [.string, .int],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                let toDrop = max(0, y.value)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.dropLast(toDrop)),
                            call: [y, x, InstructionItem(.stringDrop)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
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
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                let toTake = max(0, y.value)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.prefix(toTake)),
                            call: [y, x, InstructionItem(.stringTake)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringItemIsEmpty_Behavior =
        Behavior(
            .stringItemIsEmpty,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            x.value.isEmpty,
                            call: [x, InstructionItem(.stringItemIsEmpty)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringFirst_Behavior =
        Behavior(
            .stringFirst,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                if let c = x.value.first {
                    return [
                        Router(
                            .char,
                            CharItem(
                                c,
                                call: [x, InstructionItem(.stringFirst)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                } else {
                    return []  // empty string
                }
            }
        )

    static let stringLast_Behavior =
        Behavior(
            .stringLast,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                if let c = x.value.last {
                    return [
                        Router(
                            .char,
                            CharItem(
                                c,
                                call: [x, InstructionItem(.stringLast)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                } else {
                    return []  // empty string
                }
            }
        )

    static let stringLTE_Behavior =
        Behavior(
            .stringLTE,
            takes: [.string, .string],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y <= x,
                            call: [y, x, InstructionItem(.stringLTE)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringLT_Behavior =
        Behavior(
            .stringLT,
            takes: [.string, .string],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y < x,
                            call: [y, x, InstructionItem(.stringLT)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringGT_Behavior =
        Behavior(
            .stringGT,
            takes: [.string, .string],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y > x,
                            call: [y, x, InstructionItem(.stringGT)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringGTE_Behavior =
        Behavior(
            .stringGTE,
            takes: [.string, .string],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! StringItem)
                return [
                    Router(
                        .bool,
                        BoolItem(
                            y >= x,
                            call: [y, x, InstructionItem(.stringGTE)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringReverse_Behavior =
        Behavior(
            .stringReverse,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(x.value.reversed()),
                            call: [x, InstructionItem(.stringReverse)],
                            isContingent: Behavior.netContingency(of: x, )
                        )
                    )
                ]
            }
        )

    static let stringLength_Behavior =
        Behavior(
            .stringLength,
            takes: [.string],
            fxn: { a in
                let (x) = (a[0] as! StringItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            x.value.count,
                            call: [x, InstructionItem(.stringLength)],
                            isContingent: Behavior.netContingency(of: x, )
                        )
                    )
                ]
            }
        )

    static let stringFromBool_Behavior =
        Behavior(
            .stringFromBool,
            takes: [.bool],
            fxn: { a in
                let (x) = (a[0] as! BoolItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: [x, InstructionItem(.stringFromBool)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringFromChar_Behavior =
        Behavior(
            .stringFromChar,
            takes: [.char],
            fxn: { a in
                let (x) = (a[0] as! CharItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: [x, InstructionItem(.stringFromChar)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringFromDouble_Behavior =
        Behavior(
            .stringFromDouble,
            takes: [.double],
            fxn: { a in
                let (x) = (a[0] as! DoubleItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: [x, InstructionItem(.stringFromDouble)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringFromInt_Behavior =
        Behavior(
            .stringFromInt,
            takes: [.int],
            fxn: { a in
                let (x) = (a[0] as! IntItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            "\(x.value)",
                            call: [x, InstructionItem(.stringFromInt)],
                            isContingent: Behavior.netContingency(of: x)
                        )
                    )
                ]
            }
        )

    static let stringNth_Behavior =
        Behavior(
            .stringNth,
            takes: [.string, .int],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                if x.value.isEmpty {
                    return []
                } else {
                    let moduloIdx = (max(0, y.value) % x.value.count)
                    let idx = x.value.index(
                        x.value.startIndex,
                        offsetBy: moduloIdx
                    )
                    let c = x.value[idx]
                    return [
                        Router(
                            .char,
                            CharItem(
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
                                call: [x, y, InstructionItem(.stringNth)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
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
            fxn: { a in
                let x = a[0] as! StringItem
                guard !x.value.isEmpty else { return [] }
                return Interpreter.iteratorLoop(
                    kind: .letters,
                    origin: x,
                    body: nil,
                    emits: true
                )
            }
        )

    static let stringOccurrencesOfChar_Behavior =
        Behavior(
            .stringOccurrencesOfChar,
            takes: [.string, .char],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .int,
                        IntItem(
                            x.value.filter({ $0 == y.value }).count,
                            call: [
                                y, x, InstructionItem(.stringOccurrencesOfChar),
                            ],
                            isContingent: Behavior.netContingency(of: x, y),
                        )
                    )
                ]
            }
        )

    static let stringRemoveChar_Behavior =
        Behavior(
            .stringRemoveChar,
            takes: [.string, .char],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                return [
                    Router(
                        .string,
                        StringItem(
                            x.value.filter({ $0 != y.value }),
                            call: [y, x, InstructionItem(.stringRemoveChar)],
                            isContingent: Behavior.netContingency(of: x, y),
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
            fxn: { a in
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
                            call: [
                                z, y, x, InstructionItem(.stringReplaceChar),
                            ],
                            isContingent: Behavior.netContingency(of: x, y, z),
                        )
                    )
                ]
            }
        )

    static let stringReplaceFirstChar_Behavior =
        Behavior(
            .stringReplaceFirstChar,
            takes: [.string, .char, .char],
            fxn: { a in
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
                            call: [
                                z, y, x,
                                InstructionItem(.stringReplaceFirstChar),
                            ],
                            isContingent: Behavior.netContingency(of: x, y, z),
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
            fxn: { a in
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
                            call: [z, y, x, InstructionItem(.stringReplace)],
                            isContingent: Behavior.netContingency(of: x, y, z),
                        )
                    )
                ]
            }
        )

    static let stringReplaceFirst_Behavior =
        Behavior(
            .stringReplaceFirst,
            takes: [.string, .string, .string],
            fxn: { a in
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
                            call: [z, y, x, InstructionItem(.stringReplaceFirst)],
                            isContingent: Behavior.netContingency(of: x, y, z),
                        )
                    )
                ]
            }
        )

    static let stringRest_Behavior =
        Behavior(
            .stringRest,
            takes: [.string],
            fxn: { a in
                var (x) = (a[0] as! StringItem)
                let result = String(x.value.dropFirst(1))
                return [
                    Router(
                        .string,
                        StringItem(
                            result,
                            call: [x, InstructionItem(.stringRest)],
                            isContingent: Behavior.netContingency(of: x),
                        )
                    )
                ]
            }
        )

    static let stringSetChar_Behavior =
        Behavior(
            .stringSetChar,
            takes: [.string, .int, .char],
            fxn: { a in
                var (x, y, z) = (
                    a[0] as! StringItem,
                    a[1] as! IntItem,
                    a[2] as! CharItem
                )
                var result = x.value
                if result.count > 0 {
                    let moduloIdx = (max(0, y.value) % result.count)
                    let idx = result.index(
                        result.startIndex,
                        offsetBy: moduloIdx
                    )
                    result.replaceSubrange(idx...idx, with: String(z.value))
                }
                return [
                    Router(
                        .string,
                        StringItem(
                            result,
                            call: [z, y, x, InstructionItem(.stringSetChar)],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
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
            fxn: { a in
                let x = a[0] as! StringItem
                guard !x.value.split(whereSeparator: { $0.isWhitespace }).isEmpty
                else { return [] }
                return Interpreter.iteratorLoop(
                    kind: .words,
                    origin: x,
                    body: nil,
                    emits: true
                )
            }
        )

    /// The `n`th whitespace-delimited word of a string, indexed modulo the word
    /// count like its `stringNth` sibling. Nothing at all for a string with no
    /// words — there is no sensible word to return, and an ErrorItem would be
    /// noise.
    ///
    /// Added for `stringSplit`'s iterator to have something honest to record, but
    /// useful in its own right.
    static let stringNthWord_Behavior =
        Behavior(
            .stringNthWord,
            takes: [.string, .int],
            fxn: { a in
                let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                let words = x.value.split { $0.isWhitespace }
                guard !words.isEmpty else { return [] }
                let idx = (max(0, y.value) % words.count)
                return [
                    Router(
                        .string,
                        StringItem(
                            String(words[idx]),
                            // `[string, index]`, matching `stringNth` and the four
                            // `vecXNth` siblings.
                            call: [x, y, InstructionItem(.stringNthWord)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    static let stringSubstring_Behavior =
        Behavior(
            .stringSubstring,
            takes: [.string, .int, .int],
            fxn: { a in
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
                            call: [x, z, y, InstructionItem(.stringSubstring)],
                            isContingent: Behavior.netContingency(of: x, y, z)
                        )
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
            fxn: { a in
                let (x, mouse) = (a[0] as! StringItem, a[1] as! CodeItem)
                guard !x.value.isEmpty else { return [] }
                return Interpreter.iteratorLoop(
                    kind: .elements(into: nil),
                    origin: x,
                    body: mouse,
                    emits: true
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
            fxn: { a in
                let s = a[0] as! StringItem
                guard !s.value.isEmpty else { return [] }
                return Interpreter.iteratorLoop(
                    kind: .elements(into: nil),
                    origin: s,
                    body: nil,
                    emits: true
                )
            }
        )

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
        .stringGT : stringGT_Behavior,
        .stringGTE : stringGTE_Behavior,
        .stringIndexOfChar : stringIndexOfChar_Behavior,
        .stringItemIsEmpty : stringItemIsEmpty_Behavior,
        .stringIterate : stringIterate_Behavior,
        .stringLast : stringLast_Behavior,
        .stringLength : stringLength_Behavior,
        .stringLT : stringLT_Behavior,
        .stringLTE : stringLTE_Behavior,
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
        .stringSubstring : stringSubstring_Behavior,
        .stringTake : stringTake_Behavior,
        ]
}
