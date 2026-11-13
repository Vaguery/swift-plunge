//
//  Output Behaviors.swift
//  Plunge
//
//  Created by Bill Tozier on 6/14/26.
//

import DequeModule

nonisolated extension Interpreter {

    static let printNewline_Behavior =
        Behavior.channel(.printNewline, takes: []) { _ in .text("\n") }
        .described("Prints a newline to the output.")

    static let boolPrint_Behavior =
        Behavior.channel(.boolPrint, takes: [.bool]) { args in .item(args[0]) }
        .described("Prints the top bool and a newline to the output.")

    /// Prints the loop's state and leaves the loop running: an iterator's body
    /// is never lost to a print (since 2026-11-09;
    /// until then it consumed the iterator and its body with it).
    static let iteratorPrint_Behavior =
        Behavior(.iteratorPrint, requires: [.reads(.iterator)], tags: [], behaviorClass: .channel,
                 body: .channel { args in .item(args[0]) }, produces: .printout)
        .described("Prints the top iterator and a newline to the output, leaving the loop on `.iterator`.")

    static let execPrint_Behavior =
        Behavior.channel(.execPrint, takes: [.exec]) { args in .item(args[0]) }
        .described("Prints the next item on `.exec` and a newline to the output, so that item never runs.")

    static let doublePrint_Behavior =
        Behavior.channel(.doublePrint, takes: [.double]) { args in .item(args[0]) }
        .described("Prints the top double and a newline to the output.")

    static let charPrint_Behavior =
        Behavior.channel(.charPrint, takes: [.char]) { args in .item(args[0]) }
        .described("Prints the top char and a newline to the output.")

    static let intPrint_Behavior =
        Behavior.channel(.intPrint, takes: [.int]) { args in .item(args[0]) }
        .described("Prints the top int and a newline to the output.")

    static let stringPrint_Behavior =
        Behavior.channel(.stringPrint, takes: [.string]) { args in .item(args[0]) }
        .described("Prints the top string and a newline to the output.")

    static let vecBoolPrint_Behavior =
        Behavior.channel(.vecBoolPrint, takes: [.vecBool]) { args in .item(args[0]) }
        .described("Prints the top vector of bools and a newline to the output.")

    static let vecDoublePrint_Behavior =
        Behavior.channel(.vecDoublePrint, takes: [.vecDouble]) { args in .item(args[0]) }
        .described("Prints the top vector of doubles and a newline to the output.")

    static let vecIntPrint_Behavior =
        Behavior.channel(.vecIntPrint, takes: [.vecInt]) { args in .item(args[0]) }
        .described("Prints the top vector of ints and a newline to the output.")

    static let vecStringPrint_Behavior =
        Behavior.channel(.vecStringPrint, takes: [.vecString]) { args in .item(args[0]) }
        .described("Prints the top vector of strings and a newline to the output.")

    static let codePrint_Behavior =
        Behavior.channel(.codePrint, takes: [.code]) { args in .item(args[0]) }
        .described("Prints the top code block and a newline to the output.")


    static var outputBehaviors: [PushInstruction: Behavior] {
        let result: [PushInstruction: Behavior] =
        [
            .boolPrint: boolPrint_Behavior,
            .charPrint: charPrint_Behavior,
            .codePrint: codePrint_Behavior,
            .doublePrint: doublePrint_Behavior,
            .execPrint: execPrint_Behavior,
            .intPrint: intPrint_Behavior,
            .iteratorPrint: iteratorPrint_Behavior,
            .printNewline: printNewline_Behavior,
            .stringPrint: stringPrint_Behavior,
            .vecBoolPrint: vecBoolPrint_Behavior,
            .vecDoublePrint: vecDoublePrint_Behavior,
            .vecIntPrint: vecIntPrint_Behavior,
            .vecStringPrint: vecStringPrint_Behavior

        ]
        return result
    }
}
