//
//  Text Behaviors.swift
//  PushInterpreter
//
//  Case, substring search, prefixes and suffixes, and trimming (*Behavior
//  coverage audit (2026-11-09)*, P6): the text work that had no route at all.
//
//  The queries (`IsUpper`, `IsLower`, `IndexOf`, `StartsWith`, `EndsWith`) read
//  and leave their arguments, as every query does. Written order follows
//  `stringContains`: the string first, then what is looked for, so
//  `"hello" "ll" .stringIndexOf` is 2.
//
//  Case mapping is Unicode's default, not a locale's, so it is the same
//  everywhere. A character whose upper or lower case is more than one character
//  (`ß` → `SS`) has no char answer and is refused; the string forms have no such
//  limit.
//

nonisolated extension Interpreter {

    // MARK: - Characters

    /// `character` mapped by `transform`, if that is still one character.
    static func singleCharacter(_ character: Character, _ transform: (Character) -> String,
                                _ instruction: PushInstruction) throws(Refusal) -> Character {
        let mapped = transform(character)
        guard mapped.count == 1, let result = mapped.first else {
            throw Refusal("No single-character result in .\(instruction): \(character) → \(mapped)")
        }
        return result
    }

    static let charUpper_Behavior =
        Behavior.operation(.charUpper, takes: CharItem.self, gives: CharItem.self) { x throws(Refusal) in
            try singleCharacter(x, { $0.uppercased() }, .charUpper)
        }

    static let charLower_Behavior =
        Behavior.operation(.charLower, takes: CharItem.self, gives: CharItem.self) { x throws(Refusal) in
            try singleCharacter(x, { $0.lowercased() }, .charLower)
        }

    static let charIsUpper_Behavior =
        Behavior.operation(.charIsUpper, reads: CharItem.self, gives: BoolItem.self) { x in x.isUppercase }

    static let charIsLower_Behavior =
        Behavior.operation(.charIsLower, reads: CharItem.self, gives: BoolItem.self) { x in x.isLowercase }


    // MARK: - Strings

    static let stringUpper_Behavior =
        Behavior.operation(.stringUpper, takes: StringItem.self, gives: StringItem.self) { x in x.uppercased() }

    static let stringLower_Behavior =
        Behavior.operation(.stringLower, takes: StringItem.self, gives: StringItem.self) { x in x.lowercased() }

    /// Where the second string first occurs in the first, counted in
    /// characters; an error if it does not. An empty needle is found at 0.
    static let stringIndexOf_Behavior =
        Behavior.operation(.stringIndexOf, reads: StringItem.self, StringItem.self, gives: IntItem.self) { hay, needle throws(Refusal) in
            guard let range = hay.firstRange(of: needle) else {
                throw Refusal("Not found in .stringIndexOf: \(needle)", kind: .notFound)
            }
            return hay.distance(from: hay.startIndex, to: range.lowerBound)
        }

    static let stringStartsWith_Behavior =
        Behavior.operation(.stringStartsWith, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { x, prefix in
            x.hasPrefix(prefix)
        }

    static let stringEndsWith_Behavior =
        Behavior.operation(.stringEndsWith, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { x, suffix in
            x.hasSuffix(suffix)
        }

    /// Without whitespace at either end. The characters kept keep their origins.
    static let stringTrim_Behavior =
        Behavior.assembling(.stringTrim, takes: StringItem.self, gives: StringItem.self) { x in
            let characters = Array(x.value)
            guard let first = characters.firstIndex(where: { !$0.isWhitespace }),
                  let last = characters.lastIndex(where: { !$0.isWhitespace }) else {
                return Built("", members: [])
            }
            let origins = x.origins()
            return Built(String(characters[first...last]), members: Array(origins[first...last]))
        }


    // MARK: - The family

    static let textBehaviors: [PushInstruction: Behavior] = [
        .charUpper: charUpper_Behavior,
        .charLower: charLower_Behavior,
        .charIsUpper: charIsUpper_Behavior,
        .charIsLower: charIsLower_Behavior,
        .stringUpper: stringUpper_Behavior,
        .stringLower: stringLower_Behavior,
        .stringIndexOf: stringIndexOf_Behavior,
        .stringStartsWith: stringStartsWith_Behavior,
        .stringEndsWith: stringEndsWith_Behavior,
        .stringTrim: stringTrim_Behavior,
    ]
}
