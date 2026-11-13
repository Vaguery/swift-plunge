//
//  Error Message Helpers.swift
//  PlungeTests
//
//  An error prints as its kind and its instruction (`«err overflow: .intAdd»`);
//  the sentence that describes it is kept in `value`. These read the sentences,
//  for tests that pin what a refusal says.
//

@testable import Plunge

extension Item {
    /// An error's message, or the empty string for any other item.
    var errorMessage: String { (self as? ErrorItem)?.value ?? "" }
}

/// The messages of every error on `.error`, top first, one per line.
func errorText(_ interpreter: Interpreter) -> String {
    interpreter.stacks[.error]!.map(\.errorMessage).joined(separator: "\n")
}
