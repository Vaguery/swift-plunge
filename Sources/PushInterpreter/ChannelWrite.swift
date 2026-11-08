//
//  ChannelWrite.swift
//  PushInterpreter
//
//  What a channel Behavior sends to the printout (Roadmap #43).
//

/// **A write to the printout.** A channel Behavior returns one of these and never
/// touches the interpreter; `Behavior.act` performs it.
nonisolated enum ChannelWrite: Sendable {
    /// An item, printed as its `pretty()` text and a newline.
    case item(any Item)
    /// Raw text (`printNewline`).
    case text(String)
}
