//
//  ControlEffect.swift
//  PushInterpreter
//
//  What a control Behavior writes, beyond its ordinary results (Roadmap #43).
//

/// **A write to the continuation**, for the control Behaviors that need more than
/// a `Router` onto `.exec` can say. `Behavior.act` applies these in order, then
/// pushes the `.result`s, exactly as the old direct-write bodies did.
nonisolated enum ControlEffect: Sendable {
    /// An ordinary result, pushed after the continuation writes.
    case result(Router)
    /// Put `items` on top of `.exec` in reading order, so the first runs first:
    /// how `codeDo` runs a block's contents.
    case place([any Item])
    /// Push `payload`, then insert `token` into `.exec` `depth` items below it
    /// (clamped): how `iteratorPlay` schedules its next pass.
    case bury(any Item, depth: Int, under: [Router])
}
