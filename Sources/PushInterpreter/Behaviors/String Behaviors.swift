////
////  String Behaviors.swift
////  Propeller in Swift
////
////  Created by Bill Tozier on 5/9/26.
////

import DequeModule

nonisolated extension Interpreter {

    static let stringButLast_Behavior =
        Behavior.assembling(.stringButLast, takes: StringItem.self, gives: StringItem.self) { x in
            Built(String(x.value.dropLast(1)), members: x.origins().dropLast(1))
        }
        .described("Removes a string's last character; the empty string stays empty.")

    static let stringConcat_Behavior =
        Behavior.assembling(.stringConcat, takes: StringItem.self, StringItem.self, gives: StringItem.self) { y, x in
            Built(y.value + x.value, members: y.origins(0) + x.origins(1))
        }
        .described("Joins two strings: `s t .stringConcat` gives s followed by t.")

    static let stringConj_Behavior =
        Behavior.assembling(.stringConj, takes: StringItem.self, CharItem.self, gives: StringItem.self) { y, x in
            Built(y.value + String(x.value), members: y.origins() + [Origin.item(x)])
        }
        .described("Appends a char to the end of a string.")

    static let stringContainsRun_Behavior =
        Behavior.operation(.stringContainsRun, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { y, x in
            // `firstRange(of:)` is stdlib and deterministic
            // (empty substring ⇒ contained); plain `.contains`
            // resolved to different overloads across Foundation
            // / module contexts once this code left the app target.
            y.firstRange(of: x) != nil
        }
        .described("Tests whether t occurs in s, leaving both: `s t .stringContainsRun`; an empty t gives true.")

    // Written order: the string, then the char.
    static let stringContains_Behavior =
        Behavior.operation(.stringContains, reads: StringItem.self, CharItem.self, gives: BoolItem.self) { x, y in
            x.contains(y)
        }
        .described("Tests whether a char occurs: `s c .stringContains`, leaving both.")

    /// The position of the first occurrence of the char; an error if there is none.
    static let stringIndexOf_Behavior =
        Behavior.operation(.stringIndexOf, reads: StringItem.self, CharItem.self, gives: IntItem.self) { x, y throws(Refusal) in
            guard let idx = x.firstIndex(of: y) else {
                throw Refusal("Not found in .stringIndexOf: \(y)", kind: .notFound)
            }
            return x.distance(from: x.startIndex, to: idx)
        }
        .described("Finds a char: `s c .stringIndexOf` gives the index of its first occurrence, leaving both; " +
                   "refuses when absent.")

    // the IntItem value is truncated at 0 before use as an index.
    // Written order: the string, then the int.
    //
    // Drops from the **front**, as `vecXDrop` does, so `stringTake n` and
    // `stringDrop n` split a string the way they split a vector (since
    // 2026-11-09; it used to drop from the end, which is now `stringDropLast`).
    static let stringDrop_Behavior =
        Behavior.assembling(.stringDrop, takes: StringItem.self, IntItem.self, gives: StringItem.self) { x, y in
            let toDrop = max(0, y.value)
            return Built(String(x.value.dropFirst(toDrop)), members: Array(x.origins().dropFirst(toDrop)))
        }
        .described("Drops the front: `s n .stringDrop` removes the first n characters; a negative n removes none.")

    // the string with its last n characters removed (n clamped at 0).
    // Written order: the string, then the int.
    static let stringDropLast_Behavior =
        Behavior.assembling(.stringDropLast, takes: StringItem.self, IntItem.self, gives: StringItem.self) { x, y in
            let toDrop = max(0, y.value)
            return Built(String(x.value.dropLast(toDrop)), members: Array(x.origins().dropLast(toDrop)))
        }
        .described("Drops the back: `s n .stringDropLast` removes the last n characters; a negative n removes none.")

    // the last n characters of the string (n clamped at 0).
    // Written order: the string, then the int.
    static let stringTakeLast_Behavior =
        Behavior.assembling(.stringTakeLast, takes: StringItem.self, IntItem.self, gives: StringItem.self) { x, y in
            let toTake = max(0, y.value)
            return Built(String(x.value.suffix(toTake)), members: Array(x.origins().suffix(toTake)))
        }
        .described("Keeps the back: `s n .stringTakeLast` gives the last n characters; a negative n keeps none.")

    // the IntItem value is truncated at 0 before use as an index.
    // Written order: the string, then the int.
    static let stringTake_Behavior =
        Behavior.assembling(.stringTake, takes: StringItem.self, IntItem.self, gives: StringItem.self) { x, y in
            let toTake = max(0, y.value)
            return Built(String(x.value.prefix(toTake)), members: Array(x.origins().prefix(toTake)))
        }
        .described("Keeps the front: `s n .stringTake` gives the first n characters; a negative n keeps none.")

    static let stringItemIsEmpty_Behavior =
        Behavior.operation(.stringItemIsEmpty, reads: StringItem.self, gives: BoolItem.self) { x in x.isEmpty }
        .described("Tests whether the string is empty, leaving the string.")

    static let stringFirst_Behavior =
        Behavior.extracting(.stringFirst, takes: StringItem.self) { x throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty string in .stringFirst", kind: .emptyCollection)
            }
            // The char that went in, if it kept a history (`Containment`).
            return Extraction(x, at: 0)
        }
        .described("Takes a string's first character; refuses the empty string.")

    static let stringLast_Behavior =
        Behavior.extracting(.stringLast, takes: StringItem.self) { x throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty string in .stringLast", kind: .emptyCollection)
            }
            return Extraction(x, at: x.value.count - 1)
        }
        .described("Takes a string's last character; refuses the empty string.")

    // Comparisons are non-destructive queries: both operands survive, and the
    // result's crux clears them away (`Behavior.reading`).
    static let stringLTE_Behavior =
        Behavior.operation(.stringLTE, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { y, x in y <= x }
        .described("Compares in Unicode order, leaving both strings: `s t .stringLTE` gives s ≤ t.")

    static let stringLT_Behavior =
        Behavior.operation(.stringLT, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { y, x in y < x }
        .described("Compares in Unicode order, leaving both strings: `s t .stringLT` gives s < t.")

    static let stringGT_Behavior =
        Behavior.operation(.stringGT, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { y, x in y > x }
        .described("Compares in Unicode order, leaving both strings: `s t .stringGT` gives s > t.")

    static let stringGTE_Behavior =
        Behavior.operation(.stringGTE, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { y, x in y >= x }
        .described("Compares in Unicode order, leaving both strings: `s t .stringGTE` gives s ≥ t.")

    static let stringReverse_Behavior =
        Behavior.assembling(.stringReverse, takes: StringItem.self, gives: StringItem.self) { x in
            Built(String(x.value.reversed()), members: x.origins().reversed())
        }
        .described("Reverses a string's characters.")

    static let stringLength_Behavior =
        Behavior.operation(.stringLength, reads: StringItem.self, gives: IntItem.self) { x in x.count }
        .described("Counts the string's characters, leaving the string.")

    static let stringFromBool_Behavior =
        Behavior.operation(.stringFromBool, takes: BoolItem.self, gives: StringItem.self) { x in "\(x)" }
        .described("Converts a bool to the string `true` or `false`.")

    static let stringFromChar_Behavior =
        Behavior.assembling(.stringFromChar, takes: CharItem.self, gives: StringItem.self) { x in
            Built("\(x.value)", members: [Origin.item(x)])
        }
        .described("Converts a char to a one-character string.")

    static let stringFromDouble_Behavior =
        Behavior.operation(.stringFromDouble, takes: DoubleItem.self, gives: StringItem.self) { x in "\(x)" }
        .described("Converts a double to text, such as `2.5`, `1e-05`, `inf` or `nan`.")

    static let stringFromInt_Behavior =
        Behavior.operation(.stringFromInt, takes: IntItem.self, gives: StringItem.self) { x in "\(x)" }
        .described("Converts an int to its decimal text.")

    /// The char at the index, clamped to the string (`Position.item`); an error
    /// for an empty string.
    static let stringNth_Behavior =
        // Written order `[string, index]`, matching the four `vecXNth` siblings.
        // This used to be `[index, string]` — harmless in itself, since the two
        // arguments come off different stacks and either order re-runs correctly,
        // but the two families disagreeing meant an iterator walking a string
        // could not record the same way one walking a vector did. The crux then
        // stopped being a fixed point: re-running it produced a differently-worded
        // crux for the same value. The fuzzer found it: argument order is free
        // only *across* stacks.
        Behavior.extracting(.stringNth, takes: StringItem.self, IntItem.self) { x, y throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty string in .stringNth", kind: .emptyCollection)
            }
            return Extraction(x, at: Position.item(y.value, count: x.value.count))
        }
        .described("Takes the character at index i, clamped into range; refuses the empty string.")

    /// `stringNth` without consuming: the string and the index stay where they
    /// were. `stringNth` itself still consumes, so an element's
    /// address crux stays `s 2 .stringNth`.
    static let stringPeekNth_Behavior =
        Behavior.extracting(.stringPeekNth, reads: StringItem.self, IntItem.self) { x, y throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty string in .stringPeekNth", kind: .emptyCollection)
            }
            return Extraction(x, at: Position.item(y.value, count: x.value.count))
        }
        .described("Copies the character at index i, clamped into range, leaving the string and index; refuses the " +
                   "empty string.")

    /// Pushes every character of a string to `.string` as a one-character
    /// *string* — not a char, which is the whole of the difference from
    /// `stringPushAll` — one per pass, front to back.
    ///
    /// One element per Character (grapheme), which the `.letters` projection gets
    /// by indexing rather than by `split(separator: "")`, whose empty-separator
    /// overload resolution is unstable across Foundation / module contexts.
    ///
    /// Each letter records `x 2 .stringNth .stringFromChar` — two instructions to
    /// reproduce, still O(1), and still independent of every other letter.
    static let stringPushAllLetters_Behavior =
        Behavior(
            .stringPushAllLetters,
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
        .described("Pushes each character as a one-character string, one per step, front to back; the empty string " +
                   "gives nothing.")

    // Written order: the string, then the char.
    static let stringOccurrencesOf_Behavior =
        Behavior.operation(.stringOccurrencesOf, reads: StringItem.self, CharItem.self, gives: IntItem.self) { x, y in
            x.filter({ $0 == y }).count
        }
        .described("Counts a char: `s c .stringOccurrencesOf` gives how many times c occurs in s, leaving both.")

    // Written order: the string, then the char.
    static let stringRemove_Behavior =
        Behavior.assembling(.stringRemove, takes: StringItem.self, CharItem.self, gives: StringItem.self) { x, y in
            Built(x.value.filter({ $0 != y.value }),
                  members: zip(x.value, x.origins()).filter { $0.0 != y.value }.map(\.1))
        }
        .described("Removes a char: `s c .stringRemove` gives s without its occurrences of c.")

    // ( "0123" '2' '.' .stringReplace ) -> "01.3"
    //
    // Written order: the string, the target char (deeper), then the replacement char.
    static let stringReplace_Behavior =
        Behavior.assembling(.stringReplace, takes: StringItem.self, CharItem.self, CharItem.self,
                            gives: StringItem.self) { x, z, y in
            Built(x.value.replacing(String(z.value), with: String(y.value)),
                  members: zip(x.value, x.origins()).map { $0.0 == z.value ? Origin.item(y) : $0.1 })
        }
        .described("Replaces chars: `s a b .stringReplace` turns every a in s into b.")

    static let stringReplaceFirst_Behavior =
        Behavior.assembling(.stringReplaceFirst, takes: StringItem.self, CharItem.self, CharItem.self,
                            gives: StringItem.self) { x, z, y in
            Built(x.value.replacing(String(z.value), with: String(y.value), maxReplacements: 1),
                  members: replacingFirstSlot(of: z.value, in: x, with: y))
        }
        .described("Replaces one char: `s a b .stringReplaceFirst` turns the first a in s into b.")

    // ("foo" "o" "g" .stringReplaceRun) -> "fgg"
    //
    static let stringReplaceRun_Behavior =
        // z: in this context (deepest), y: target, x: replacement (top).
        Behavior.assembling(.stringReplaceRun, takes: StringItem.self, StringItem.self, StringItem.self,
                            gives: StringItem.self) { z, y, x in
            Built(z.value.replacing(y.value, with: x.value),
                  members: replacingSubstringSlots(z, y, x, firstOnly: false))
        }
        .described("Replaces substrings: `s t u .stringReplaceRun` puts u for every t in s; an empty t puts u between " +
                   "all characters and at both ends.")

    static let stringReplaceFirstRun_Behavior =
        // z: in this context (deepest), y: target, x: replacement (top).
        Behavior.assembling(.stringReplaceFirstRun, takes: StringItem.self, StringItem.self, StringItem.self,
                            gives: StringItem.self) { z, y, x in
            Built(z.value.replacing(y.value, with: x.value, maxReplacements: 1),
                  members: replacingSubstringSlots(z, y, x, firstOnly: true))
        }
        .described("Replaces a substring: `s t u .stringReplaceFirstRun` puts u for the first t in s; an empty t puts " +
                   "u at the front.")

    static let stringRest_Behavior =
        Behavior.assembling(.stringRest, takes: StringItem.self, gives: StringItem.self) { x in
            Built(String(x.value.dropFirst(1)), members: Array(x.origins().dropFirst(1)))
        }
        .described("Removes a string's first character; the empty string stays empty.")

    /// Replaces the char at the index, clamped to the string (`Position.item`).
    /// An empty string has no char to replace, so it is an error.
    static let stringSet_Behavior =
        // Written order: the string, the char, then the index.
        Behavior.assembling(.stringSet, takes: StringItem.self, CharItem.self, IntItem.self,
                            gives: StringItem.self) { x, z, y throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty string in .stringSet", kind: .emptyCollection)
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
        .described("Overwrites a char: `s c i .stringSet` puts c at index i, i clamped into range; refuses the empty string.")

    /// Pushes every whitespace-delimited word of a string to `.string`, one per
    /// pass, front to back. A string with no words produces nothing.
    ///
    /// The odd one of the explode family: a word is not `origin[i]`, so no
    /// existing instruction could name it and `.stringNthWord` had to be added
    /// for these to have a record at all. That is the price of the last law-5
    /// user, and it buys a genuinely useful instruction — "the nth word of a
    /// string" is a thing a program wants regardless.
    static let stringPushAllWords_Behavior =
        Behavior(
            .stringPushAllWords,
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
        .described("Pushes each whitespace-separated word of a string, one per step, front to back; a string with " +
                   "no words gives nothing.")

    /// The `n`th whitespace-delimited word of a string, the index clamped to the
    /// word count like its `stringNth` sibling. A string with no words is an
    /// error: there is no word to return.
    ///
    /// Added for `stringPushAllWords`'s iterator to have something honest to record, but
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
        .described("Takes the whitespace-separated word at index i, clamped into range; refuses a string with no " +
                   "words.")

    /// `stringNthWord` without consuming: the string and the index stay.
    static let stringPeekNthWord_Behavior =
        Behavior.assembling(.stringPeekNthWord, reads: StringItem.self, IntItem.self,
                            gives: StringItem.self) { x, y throws(Refusal) in
            let words = x.value.split { $0.isWhitespace }
            guard !words.isEmpty else {
                throw Refusal("No words in .stringPeekNthWord", kind: .emptyCollection)
            }
            let idx = Position.item(y.value, count: words.count)
            return Built(String(words[idx]), members: x.origins(of: words[idx]))
        }
        .described("Copies the whitespace-separated word at index i, clamped into range, leaving the string and "
                   + "index; refuses a string with no words.")

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
        .described("Splits a string at gap i, clamped to 0 through its length: the front part beneath, the back " +
                   "part on top.")

    // Written order: the string, then the two ints deepest first (z, then y).
    static let stringSlice_Behavior =
        Behavior.assembling(.stringSlice, takes: StringItem.self, IntItem.self, IntItem.self,
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
        .described("Takes characters i through j inclusive: `s i j .stringSlice`; both clamped into range, a j " +
                   "below i gives character i alone.")

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
        .described("Runs the block once per character, pushing that char before each pass; the empty string makes " +
                   "no passes, and the block ends on `.code`.")

    /// Pushes every character of a string to `.char`, **one per pass**, front to
    /// back — so the last character ends up on top.
    ///
    /// It used to do this in a single step, which is the thing this whole family
    /// was reworked to stop doing: a loop refusing to be one. Exploding all at
    /// once put the work outside `stepLimit` and the runaway guard's reach, and it
    /// forced every character to record *which of the pile it was* —
    /// `s .stringPushAll 3 .charPopItems`, a law-5 selection. Now each
    /// character just says what it is, `s 2 .stringNth`: independent, O(1), and
    /// true regardless of how many passes have run.
    ///
    /// A sequence, not a loop: the iterator has no body, so a pass costs one step
    /// rather than three.
    static let stringPushAll_Behavior =
        Behavior(
            .stringPushAll,
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
        .described("Pushes each character of a string as a char, one per step, front to back, so the last ends on top.")

    // MARK: - Members (`Pieces`)

    /// `x`'s origins with the first `target` character's replaced by `char`,
    /// as `.stringReplaceFirst` replaces the character. Called only when
    /// recording.
    static func replacingFirstSlot(of target: Character, in x: StringItem, with char: CharItem) -> [Origin] {
        var origins = x.origins()
        if let position = Array(x.value).firstIndex(of: target) { origins[position] = .item(char) }
        return origins
    }

    /// The origins of `.stringReplaceRun`/`.stringReplaceFirstRun`'s result: each
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
        .stringConj : stringConj_Behavior,
        .stringContainsRun : stringContainsRun_Behavior,
        .stringContains : stringContains_Behavior,
        .stringDrop : stringDrop_Behavior,
        .stringFirst : stringFirst_Behavior,
        .stringFromBool : stringFromBool_Behavior,
        .stringFromChar : stringFromChar_Behavior,
        .stringFromDouble : stringFromDouble_Behavior,
        .stringFromInt : stringFromInt_Behavior,
        .stringIndexOf : stringIndexOf_Behavior,
        .stringItemIsEmpty : stringItemIsEmpty_Behavior,
        .stringIterate : stringIterate_Behavior,
        .stringLast : stringLast_Behavior,
        .stringLength : stringLength_Behavior,
        .stringNth : stringNth_Behavior,
        .stringPeekNth : stringPeekNth_Behavior,
        .stringNthWord : stringNthWord_Behavior,
        .stringPeekNthWord : stringPeekNthWord_Behavior,
        .stringOccurrencesOf : stringOccurrencesOf_Behavior,
        .stringPushAllLetters : stringPushAllLetters_Behavior,
        .stringPushAll : stringPushAll_Behavior,
        .stringRemove : stringRemove_Behavior,
        .stringReplaceRun : stringReplaceRun_Behavior,
        .stringReplace : stringReplace_Behavior,
        .stringReplaceFirstRun : stringReplaceFirstRun_Behavior,
        .stringReplaceFirst : stringReplaceFirst_Behavior,
        .stringRest : stringRest_Behavior,
        .stringReverse : stringReverse_Behavior,
        .stringSet : stringSet_Behavior,
        .stringPushAllWords : stringPushAllWords_Behavior,
        .stringCut : stringCut_Behavior,
        .stringSlice : stringSlice_Behavior,
        .stringTake : stringTake_Behavior,
        .stringTakeLast : stringTakeLast_Behavior,
        .stringDropLast : stringDropLast_Behavior,
        ]
}
