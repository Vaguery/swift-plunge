//
//  BehaviorBody.swift
//  PushInterpreter
//
//  What a Behavior's code is allowed to see and return (Roadmap #43).
//

/// **A Behavior's body, by what it may touch.** No body mutates the interpreter:
/// each returns what it wants done, and `Behavior.act` is the one place that does
/// it. So the class a Behavior declares is enforced by the type of its body, not
/// just checked by a test.
///
/// | Body | Sees | Returns | Class |
/// |---|---|---|---|
/// | `values` | its arguments | results | operation, or control writing `.exec` by `Router` |
/// | `structural` | one stack, read-only | a position effect, or a loop | structural |
/// | `contextRead` | the interpreter, read-only | results | context read |
/// | `control` | its arguments | continuation writes and results | control |
/// | `channel` | its arguments | a printout write | channel |
nonisolated enum BehaviorBody: Sendable {
    case values(@Sendable ([any Item], ProvenanceRecording) -> [Router])
    case structural(PushStack, @Sendable ([any Item], StackView) -> StructuralStep)
    case contextRead(@Sendable ([any Item], ReadContext) -> [Router])
    case control(@Sendable ([any Item], ProvenanceRecording) -> [ControlEffect])
    case channel(@Sendable ([any Item]) -> ChannelWrite)
}
