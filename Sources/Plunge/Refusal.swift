//
//  Refusal.swift
//  Plunge
//
//  What a typed operation's body throws when it cannot produce its result.
//

/// **Why a typed operation could not produce its intended output** (every
/// Behavior returns its output or an error). A body throws one; the
/// constructor turns it into an `ErrorItem` on `.error`, recording the same
/// `call` the result would have had, so re-running it reproduces the refusal.
nonisolated struct Refusal: Error, Sendable {
    let message: String
    let kind: ErrorKind

    init(_ message: String, kind: ErrorKind = .other) {
        self.message = message
        self.kind = kind
    }
}
