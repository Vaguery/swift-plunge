////
////  String Behaviors.swift
////  Propeller in Swift
////
////  Created by William Tozier on 5/9/26.
////

import DequeModule

nonisolated extension Interpreter {

    static let stringButLast_Behavior =
        Behavior.assembling(.stringButLast, takes: StringItem.self, gives: StringItem.self) { x in
            Built(String(x.value.dropLast(1)), members: x.origins().dropLast(1))
        }

    static let stringConcat_Behavior =
        Behavior.assembling(.stringConcat, takes: StringItem.self, StringItem.self, gives: StringItem.self) { y, x in
            Built(y.value + x.value, members: y.origins(0) + x.origins(1))
        }

    static let stringConjChar_Behavior =
        Behavior.assembling(.stringConjChar, takes: StringItem.self, CharItem.self, gives: StringItem.self) { y, x in
            Built(y.value + String(x.value), members: y.origins() + [Origin.item(x)])
        }

    static let stringContains_Behavior =
        Behavior.operation(.stringContains, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { y, x in
            // `firstRange(of:)` is stdlib and deterministic
            // (empty substring ⇒ contained); plain `.contains`
            // resolved to different overloads across Foundation
            // / module contexts once this code left the app target.
            y.firstRange(of: x) != nil
        }

    // Written order: the char (recorded first), then the string.
    static let stringContainsChar_Behavior =
        Behavior.operation(.stringContainsChar, reads: CharItem.self, StringItem.self, gives: BoolItem.self) { y, x in
            x.contains(y)
        }

    /// The position of the first occurrence of the char; an error if there is none.
    static let stringIndexOfChar_Behavior =
        Behavior.operation(.stringIndexOfChar, reads: CharItem.self, StringItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            guard let idx = x.firstIndex(of: y) else {
                throw Refusal("Not found in .stringIndexOfChar: \(y)", kind: .notFound)
            }
            return x.distance(from: x.startIndex, to: idx)
        }

    // the IntItem value is truncated at 0 before use as an index.
    // Written order: the int (recorded first), then the string.
    //
    // Drops from the **front**, as `vecXDrop` does, so `stringTake n` and
    // `stringDrop n` split a string the way they split a vector (ruling I15,
    // 2026-11-09; it used to drop from the end, which is now `stringDropLast`).
    static let stringDrop_Behavior =
        Behavior.assembling(.stringDrop, takes: IntItem.self, StringItem.self, gives: StringItem.self) { y, x in
            let toDrop = max(0, y.value)
            return Built(String(x.value.dropFirst(toDrop)), members: Array(x.origins().dropFirst(toDrop)))
        }

    // the string with its last n characters removed (n clamped at 0).
    // Written order: the int (recorded first), then the string.
    static let stringDropLast_Behavior =
        Behavior.assembling(.stringDropLast, takes: IntItem.self, StringItem.self, gives: StringItem.self) { y, x in
            let toDrop = max(0, y.value)
            return Built(String(x.value.dropLast(toDrop)), members: Array(x.origins().dropLast(toDrop)))
        }

    // the last n characters of the string (n clamped at 0).
    // Written order: the int (recorded first), then the string.
    static let stringTakeLast_Behavior =
        Behavior.assembling(.stringTakeLast, takes: IntItem.self, StringItem.self, gives: StringItem.self) { y, x in
            let toTake = max(0, y.value)
            return Built(String(x.value.suffix(toTake)), members: Array(x.origins().suffix(toTake)))
        }

    // the IntItem value is truncated at 0 before use as an index.
    // Written order: the int (recorded first), then the string.
    static let stringTake_Behavior =
        Behavior.assembling(.stringTake, takes: IntItem.self, StringItem.self, gives: StringItem.self) { y, x in
            let toTake = max(0, y.value)
            return Built(String(x.value.prefix(toTake)), members: Array(x.origins().prefix(toTake)))
        }

    static let stringItemIsEmpty_Behavior =
        Behavior.operation(.stringItemIsEmpty, reads: StringItem.self, gives: BoolItem.self) { x in x.isEmpty }

    static let stringFirst_Behavior =
        Behavior.extracting(.stringFirst, takes: StringItem.self) { x throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty string in .stringFirst", kind: .emptyCollection)
            }
            // The char that went in, if it kept a history (`Containment`).
            return Extraction(x, at: 0)
        }

    static let stringLast_Behavior =
        Behavior.extracting(.stringLast, takes: StringItem.self) { x throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty string in .stringLast", kind: .emptyCollection)
            }
            return Extraction(x, at: x.value.count - 1)
        }

    // Comparisons are non-destructive queries: both operands survive, and the
    // result's crux clears them away (`Behavior.reading`).
    static let stringLTE_Behavior =
        Behavior.operation(.stringLTE, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { y, x in y <= x }

    static let stringLT_Behavior =
        Behavior.operation(.stringLT, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { y, x in y < x }

    static let stringGT_Behavior =
        Behavior.operation(.stringGT, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { y, x in y > x }

    static let stringGTE_Behavior =
        Behavior.operation(.stringGTE, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { y, x in y >= x }

    static let stringReverse_Behavior =
        Behavior.assembling(.stringReverse, takes: StringItem.self, gives: StringItem.self) { x in
            Built(String(x.value.reversed()), members: x.origins().reversed())
        }

    static let stringLength_Behavior =
        Behavior.operation(.stringLength, reads: StringItem.self, gives: IntItem.self) { x in x.count }

    static let stringFromBool_Behavior =
        Behavior.operation(.stringFromBool, takes: BoolItem.self, gives: StringItem.self) { x in "\(x)" }

    static let stringFromChar_Behavior =
        Behavior.assembling(.stringFromChar, takes: CharItem.self, gives: StringItem.self) { x in
            Built("\(x.value)", members: [Origin.item(x)])
        }

    static let stringFromDouble_Behavior =
        Behavior.operation(.stringFromDouble, takes: DoubleItem.self, gives: StringItem.self) { x in "\(x)" }

    static let stringFromInt_Behavior =
        Behavior.operation(.stringFromInt, takes: IntItem.self, gives: StringItem.self) { x in "\(x)" }

    /// The char at the index, clamped to the string (`Position.item`); an error
    /// for an empty string.
    static let stringNth_Behavior =
        // Written order `[string, index]`, matching the four `vecXNth` siblings.
        // This used to be `[index, string]` — harmless in itself, since the two
        // arguments come off different stacks and either order re-runs correctly,
        // but the two families disagreeing meant an iterator walking a string
        // could not record the same way one walking a vector did. The crux then
        // stopped being a fixed point: re-running it produced a differently-worded
        // crux for the same value. The fuzzer found it; see "Design Principles.md"
        // on argument order being free only *across* stacks.
        Behavior.extracting(.stringNth, takes: StringItem.self, IntItem.self) { x, y throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty string in .stringNth", kind: .emptyCollection)
            }
            return Extraction(x, at: Position.item(y.value, count: x.value.count))
        }

    /// `stringNth` without consuming: the string and the index stay where they
    /// were (ruling I7). `stringNth` itself still consumes, so an element's
    /// address crux stays `s 2 .stringNth`.
    static let stringPeekNth_Behavior =
        Behavior.extracting(.stringPeekNth, reads: StringItem.self, IntItem.self) { x, y throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty string in .stringPeekNth", kind: .emptyCollection)
            }
            return Extraction(x, at: Position.item(y.value, count: x.value.count))
        }

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
            produces: .delivery(.string),
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

    // Written order: the char (recorded first), then the string.
    static let stringOccurrencesOfChar_Behavior =
        Behavior.operation(.stringOccurrencesOfChar, reads: CharItem.self, StringItem.self, gives: IntItem.self) { y, x in
            x.filter({ $0 == y }).count
        }

    // Written order: the char (recorded first), then the string.
    static let stringRemoveChar_Behavior =
        Behavior.assembling(.stringRemoveChar, takes: CharItem.self, StringItem.self, gives: StringItem.self) { y, x in
            Built(x.value.filter({ $0 != y.value }),
                  members: zip(x.value, x.origins()).filter { $0.0 != y.value }.map(\.1))
        }

    // ( "0123" '2' '.' .stringReplaceChar ) -> "01.3"
    //
    // Written order: the target char (deeper), the replacement char, then the string.
    static let stringReplaceChar_Behavior =
        Behavior.assembling(.stringReplaceChar, takes: CharItem.self, CharItem.self, StringItem.self,
                            gives: StringItem.self) { z, y, x in
            Built(x.value.replacing(String(z.value), with: String(y.value)),
                  members: zip(x.value, x.origins()).map { $0.0 == z.value ? Origin.item(y) : $0.1 })
        }

    static let stringReplaceFirstChar_Behavior =
        Behavior.assembling(.stringReplaceFirstChar, takes: CharItem.self, CharItem.self, StringItem.self,
                            gives: StringItem.self) { z, y, x in
            Built(x.value.replacing(String(z.value), with: String(y.value), maxReplacements: 1),
                  members: replacingFirstSlot(of: z.value, in: x, with: y))
        }

    // ("foo" "o" "g" .stringReplace) -> "fgg"
    //
    static let stringReplace_Behavior =
        // z: in this context (deepest), y: target, x: replacement (top).
        Behavior.assembling(.stringReplace, takes: StringItem.self, StringItem.self, StringItem.self,
                            gives: StringItem.self) { z, y, x in
            Built(z.value.replacing(y.value, with: x.value),
                  members: replacingSubstringSlots(z, y, x, firstOnly: false))
        }

    static let stringReplaceFirst_Behavior =
        // z: in this context (deepest), y: target, x: replacement (top).
        Behavior.assembling(.stringReplaceFirst, takes: StringItem.self, StringItem.self, StringItem.self,
                            gives: StringItem.self) { z, y, x in
            Built(z.value.replacing(y.value, with: x.value, maxReplacements: 1),
                  members: replacingSubstringSlots(z, y, x, firstOnly: true))
        }

    static let stringRest_Behavior =
        Behavior.assembling(.stringRest, takes: StringItem.self, gives: StringItem.self) { x in
            Built(String(x.value.dropFirst(1)), members: Array(x.origins().dropFirst(1)))
        }

    /// Replaces the char at the index, clamped to the string (`Position.item`).
    /// An empty string has no char to replace, so it is an error.
    static let stringSetChar_Behavior =
        // Written order: the char (recorded first), the index, then the string.
        Behavior.assembling(.stringSetChar, takes: CharItem.self, IntItem.self, StringItem.self,
                            gives: StringItem.self) { z, y, x throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty string in .stringSetChar", kind: .emptyCollection)
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
            return Built(result, members: members())
        }

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
            produces: .delivery(.string),
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
        // Written order `[string, index]`, matching `stringNth` and the four
        // `vecXNth` siblings.
        Behavior.assembling(.stringNthWord, takes: StringItem.self, IntItem.self,
                            gives: StringItem.self) { x, y throws(Refusal) in
            let words = x.value.split { $0.isWhitespace }
            guard !words.isEmpty else {
                throw Refusal("No words in .stringNthWord", kind: .emptyCollection)
            }
            let idx = Position.item(y.value, count: words.count)
            return Built(String(words[idx]), members: x.origins(of: words[idx]))
        }

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
        Behavior.splitting(.stringCut, takes: StringItem.self, IntItem.self, gives: StringItem.self) { x, y in
            let idx = Position.gap(y.value, count: x.value.count)
            let cut = x.value.index(x.value.startIndex, offsetBy: idx)
            return (
                Built(String(x.value[..<cut]), members: Array(x.origins().prefix(idx))),
                Built(String(x.value[cut...]), members: Array(x.origins().dropFirst(idx)))
            )
        }

    // Written order: the string, then the two ints deepest first (z, then y).
    static let stringSubstring_Behavior =
        Behavior.assembling(.stringSubstring, takes: StringItem.self, IntItem.self, IntItem.self,
                            gives: StringItem.self) { x, z, y in
            let result = x.value
            var slice = Substring(result)
            if result.count > 0 {
                let range = result.count - 1
                let lhs = min(range, max(0, z.value))
                let rhs = min(range, max(0, z.value, y.value))
                let start = result.index(result.startIndex, offsetBy: lhs)
                let end = result.index(result.startIndex, offsetBy: rhs)
                slice = result[start...end]
            }
            return Built(String(slice), members: x.origins(of: slice))
        }

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
        Behavior.control(
            .stringIterate,
            takes: [.string, .code],
            tags: [.reEntrant],
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
            produces: .delivery(.char),
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
        .stringPeekNth : stringPeekNth_Behavior,
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
        .stringTakeLast : stringTakeLast_Behavior,
        .stringDropLast : stringDropLast_Behavior,
        ]
}
