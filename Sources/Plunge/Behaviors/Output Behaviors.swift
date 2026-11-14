//
//  Output Behaviors.swift
//  Plunge
//
//  Created by Bill Tozier on 6/14/26.
//
//  The print instructions. Printing moves an item onto `.print`, a channel: the
//  program writes to it and no instruction reads it back (`PushStack.isChannel`).
//  What lands there is the item itself, not text, so anything can be printed and a
//  caller reads printed values with a recorder.
//

import DequeModule

nonisolated extension Interpreter {

    static let boolPrint_Behavior =
        Behavior.channel(.boolPrint, takes: .bool)
        .described("Moves the top bool to `.print`.")

    /// Puts a copy of the loop on `.print` and leaves it running: an iterator's
    /// body is never lost to a print (since 2026-11-09; until then it consumed the
    /// iterator and its body with it). The one print that reads its argument.
    static let iteratorPrint_Behavior =
        Behavior(.iteratorPrint, requires: [.reads(.iterator)], tags: [], behaviorClass: .channel,
                 body: .channel { args, recording in
                     var printed = args[0]
                     printed.call = recording(Behavior.reading(
                         [.iterator: 1], producing: .print, from: [args[0], InstructionItem(.iteratorPrint)]))
                     return [printed]
                 },
                 produces: .printed)
        .described("Puts a copy of the top iterator on `.print`, leaving the loop on `.iterator`.")

    static let doublePrint_Behavior =
        Behavior.channel(.doublePrint, takes: .double)
        .described("Moves the top double to `.print`.")

    static let charPrint_Behavior =
        Behavior.channel(.charPrint, takes: .char)
        .described("Moves the top char to `.print`.")

    static let intPrint_Behavior =
        Behavior.channel(.intPrint, takes: .int)
        .described("Moves the top int to `.print`.")

    static let stringPrint_Behavior =
        Behavior.channel(.stringPrint, takes: .string)
        .described("Moves the top string to `.print`.")

    static let vecBoolPrint_Behavior =
        Behavior.channel(.vecBoolPrint, takes: .vecBool)
        .described("Moves the top vector of bools to `.print`.")

    static let vecDoublePrint_Behavior =
        Behavior.channel(.vecDoublePrint, takes: .vecDouble)
        .described("Moves the top vector of doubles to `.print`.")

    static let vecIntPrint_Behavior =
        Behavior.channel(.vecIntPrint, takes: .vecInt)
        .described("Moves the top vector of ints to `.print`.")

    static let vecStringPrint_Behavior =
        Behavior.channel(.vecStringPrint, takes: .vecString)
        .described("Moves the top vector of strings to `.print`.")

    static let codePrint_Behavior =
        Behavior.channel(.codePrint, takes: .code)
        .described("Moves the top code block to `.print`.")

    static let bindingPrint_Behavior =
        Behavior.channel(.bindingPrint, takes: .binding)
        .described("Moves the top binding to `.print`.")

    static let functionPrint_Behavior =
        Behavior.channel(.functionPrint, takes: .function)
        .described("Moves the top function to `.print`.")


    static var outputBehaviors: [PushInstruction: Behavior] {
        let result: [PushInstruction: Behavior] =
        [
            .bindingPrint: bindingPrint_Behavior,
            .boolPrint: boolPrint_Behavior,
            .charPrint: charPrint_Behavior,
            .codePrint: codePrint_Behavior,
            .doublePrint: doublePrint_Behavior,
            .functionPrint: functionPrint_Behavior,
            .intPrint: intPrint_Behavior,
            .iteratorPrint: iteratorPrint_Behavior,
            .stringPrint: stringPrint_Behavior,
            .vecBoolPrint: vecBoolPrint_Behavior,
            .vecDoublePrint: vecDoublePrint_Behavior,
            .vecIntPrint: vecIntPrint_Behavior,
            .vecStringPrint: vecStringPrint_Behavior
        ]
        return result
    }
}
