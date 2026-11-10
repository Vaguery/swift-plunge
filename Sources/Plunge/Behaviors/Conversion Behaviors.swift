//
//  Conversion Behaviors.swift
//  PushInterpreter
//
//  Values into code and back, and a string to and from its pieces.
//
//  - **`xQuote`** wraps a value in a one-item block, for every value type: the
//    scalars and the vectors. (`execQuote`, `iteratorQuote` and `bindingQuote`
//    stay beside their own stacks, because each does more than wrap: one is a
//    prefix that reads `.exec`, and the other two rebuild a structure.)
//  - **`vecFromCode`** reads a block back into a vector. Its type is read off
//    the contents, uniform or refuse, as `vecFromIterator` does; a block holding
//    exactly one vector gives that vector, so `vecXQuote` then `vecFromCode` is
//    the identity.
//  - **`stringSplitOn`** and **`vecStringJoin`** split on, and join with, an
//    explicit separator; `join(split(s, sep), sep)` is `s`.
//

nonisolated extension Interpreter {

    // MARK: - Values into code

    static let intQuote_Behavior =
        Behavior.composing(.intQuote, takes: IntItem.self, gives: CodeItem.self) { x in [x] }
        .described("Quotes an int as a one-item block: `5` becomes `( 5 )`.")

    static let boolQuote_Behavior =
        Behavior.composing(.boolQuote, takes: BoolItem.self, gives: CodeItem.self) { x in [x] }
        .described("Quotes a bool as a one-item block: `true` becomes `( true )`.")

    static let stringQuote_Behavior =
        Behavior.composing(.stringQuote, takes: StringItem.self, gives: CodeItem.self) { x in [x] }
        .described("Quotes a string as a one-item block on `.code`.")

    static let charQuote_Behavior =
        Behavior.composing(.charQuote, takes: CharItem.self, gives: CodeItem.self) { x in [x] }
        .described("Quotes a char as a one-item block on `.code`.")

    static let doubleQuote_Behavior =
        Behavior.composing(.doubleQuote, takes: DoubleItem.self, gives: CodeItem.self) { x in [x] }
        .described("Quotes a double as a one-item block: `2.5` becomes `( 2.5 )`.")

    static let vecBoolQuote_Behavior =
        Behavior.composing(.vecBoolQuote, takes: VecBoolItem.self, gives: CodeItem.self) { x in [x] }
        .described("Wraps the vector in a one-item block.")
    static let vecIntQuote_Behavior =
        Behavior.composing(.vecIntQuote, takes: VecIntItem.self, gives: CodeItem.self) { x in [x] }
        .described("Wraps the vector in a one-item block.")
    static let vecDoubleQuote_Behavior =
        Behavior.composing(.vecDoubleQuote, takes: VecDoubleItem.self, gives: CodeItem.self) { x in [x] }
        .described("Wraps the vector in a one-item block.")
    static let vecStringQuote_Behavior =
        Behavior.composing(.vecStringQuote, takes: VecStringItem.self, gives: CodeItem.self) { x in [x] }
        .described("Wraps the vector in a one-item block.")

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
        .described(
            "Turns a block of bools, ints, doubles or strings, all one type, into a vector; a block holding one "
            + "vector gives it back; refuses anything else.")


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
        .described(
            "Splits: `s p .stringSplitOn` gives the pieces of s between occurrences of p, empty pieces kept; an "
            + "empty p splits s into chars.")

    /// `v sep .vecStringJoin`: the strings of `v` with `sep` between each two.
    static let vecStringJoin_Behavior =
        Behavior.operation(.vecStringJoin, takes: VecStringItem.self, StringItem.self,
                           gives: StringItem.self) { v, separator in
            v.joined(separator: separator)
        }
        .described("Joins: `v p .vecStringJoin` gives the strings of v with p between each two.")


    // MARK: - The family

    static let conversionBehaviors: [PushInstruction: Behavior] = [
        .intQuote: intQuote_Behavior,
        .boolQuote: boolQuote_Behavior,
        .stringQuote: stringQuote_Behavior,
        .charQuote: charQuote_Behavior,
        .doubleQuote: doubleQuote_Behavior,
        .vecBoolQuote: vecBoolQuote_Behavior,
        .vecIntQuote: vecIntQuote_Behavior,
        .vecDoubleQuote: vecDoubleQuote_Behavior,
        .vecStringQuote: vecStringQuote_Behavior,
        .vecFromCode: vecFromCode_Behavior,
        .stringSplitOn: stringSplitOn_Behavior,
        .vecStringJoin: vecStringJoin_Behavior
    ]
}
