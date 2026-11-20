//
//  RecorderSpec.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

/// What a recorder looks at after each step of a run.
///
/// A target is a plain value with no closure in it, so it can be encoded and
/// sent to wherever the run happens. The cases name the observations that have
/// proven useful so far.
///
/// Targets that observe items (`top`, `second`, `nth`, `stack`) collect the
/// items themselves, so a reading keeps each item's history for as long as it
/// stays in memory. Encoded, a reading keeps values only; see ``ItemArchive`` for
/// keeping histories. The other targets collect a plain int or bool.
///
/// What a program prints is the `.print` stack: `.top(.print)` is the last item
/// printed, `.count(.print)` how many were printed, and `.stack(.print)` all of
/// them. See <doc:ObservingARun>.
public nonisolated enum RecorderTarget: Sendable, Hashable, Codable {
    /// The top item of a stack, or `nil` when the stack is empty.
    case top(PushStack)
    /// The second item of a stack, or `nil` when it holds fewer than two items.
    case second(PushStack)
    /// The item `depth` places below the top of a stack (0 is the top), or `nil`
    /// when the stack is not that deep: for several results on one stack, such
    /// as a problem's four int outputs.
    case nth(PushStack, depth: Int)
    /// The number of items currently on a stack (`Int`).
    case count(PushStack)
    /// Whether a stack is currently empty (`Bool`).
    case isEmpty(PushStack)
    /// Every item on a stack, top first (`[AnyItem]`): for `.print`, everything
    /// printed, the latest first. Copying a whole stack at every step is costly,
    /// so pair this with ``RecordingPolicy/finalOnly`` unless the history is
    /// wanted.
    case stack(PushStack)
    /// How many steps the run has taken (`Int`).
    case counter
    /// Every distinct item pushed onto a stack during the run, in the order each
    /// was first pushed (`[AnyItem]`): the intermediate results as well as the
    /// final ones, such as each partial sum of a loop. An item is counted once
    /// per history node (copies made by dup or yank share one), and a literal
    /// once per value. It is read once, at the end of the run, whatever the
    /// policy.
    ///
    /// What it can't see: the passes inside a map, a function application or an
    /// iterator run in sandboxes with provenance off, so only their collected
    /// results are pushed here; and a move within a stack is not a push. Without
    /// provenance, items have no history nodes, so each distinct value is kept
    /// once.
    case pushes(PushStack)
    /// Every choice a conditional or a selection made during the run, in order
    /// (`[Decision]`): each `.execIf`, `.execWhen` and `.codeDoIf` reached with its
    /// arguments, with the Boolean that decided (its history the condition) and
    /// the code each way would run; and each selection (a stack instruction
    /// picking by a computed depth, a binding lookup by key, a code point run by
    /// index) that could have done more than one thing, with the deciding int and
    /// its options. A crux follows data, not control, so no result's history
    /// shows these. It is read once, at the end of the run, whatever
    /// the policy. Decisions inside a map, function application or iterator
    /// sandbox aren't seen.
    case decisions
}


nonisolated extension RecorderTarget {
    /// The natural value type a target collects, used to repackage a recorder's
    /// type-erased data into a typed `RecordedTrace`.
    enum ValueKind: Sendable {
        case item, itemList, int, bool, decisions
    }

    var valueKind: ValueKind {
        switch self {
        case .top, .second, .nth: .item
        case .stack, .pushes: .itemList
        case .count, .counter: .int
        case .isEmpty: .bool
        case .decisions: .decisions
        }
    }
}


/// How many of a recorder's readings to keep.
///
/// `.everyStep`, the default, keeps one reading for each step: the whole
/// history of the target, for tracing. `.finalOnly` keeps only the latest, so
/// the recorder holds a single reading however long the run. When only the
/// state at the end is wanted, as it is for scoring, `.finalOnly` avoids
/// keeping a full trace of items and their histories for every run, which is
/// the dominant cost of evaluating a whole population.
public nonisolated enum RecordingPolicy: Sendable, Hashable, Codable {
    /// Keep one reading for every step (the full longitudinal trace).
    case everyStep
    /// Keep only the most recent reading (a single value, overwritten each step).
    case finalOnly
}


/// A named request to observe one thing during a run.
///
/// The name is the key under which the readings come back, in
/// ``CaseResult/traces``. See <doc:ObservingARun>.
public nonisolated struct RecorderSpec: Sendable, Hashable, Codable {
    /// The key for this recorder's trace in ``CaseResult/traces``. Give each recorder in a configuration its own name.
    public let name: String
    /// What to observe.
    public let target: RecorderTarget
    /// How many readings to keep.
    public let policy: RecordingPolicy

    /// Creates a recorder that keeps a reading for every step unless told otherwise.
    public init(_ name: String, observing target: RecorderTarget, keeping policy: RecordingPolicy = .everyStep) {
        self.name = name
        self.target = target
        self.policy = policy
    }
}


nonisolated extension AnyRecorder {
    /// Resolves a declarative `RecorderSpec` into a concrete, type-erased
    /// recorder whose closure reads the requested interpreter state each step.
    init(_ spec: RecorderSpec) {
        let name = spec.name
        let policy = spec.policy
        switch spec.target {
        case .top(let stack):
            self.init(Recorder<any Item>(name, keeping: policy) { interpreter in
                interpreter.stacks[stack]?.first
            })
        case .second(let stack):
            self.init(Recorder<any Item>(name, keeping: policy) { interpreter in
                guard let items = interpreter.stacks[stack], items.count > 1
                else { return nil }
                return items[1]
            })
        case .nth(let stack, let depth):
            self.init(Recorder<any Item>(name, keeping: policy) { interpreter in
                guard depth >= 0, let items = interpreter.stacks[stack], items.count > depth
                else { return nil }
                return items[depth]
            })
        case .count(let stack):
            self.init(Recorder<Int>(name, keeping: policy) { interpreter in
                interpreter.stacks[stack]?.count ?? 0
            })
        case .isEmpty(let stack):
            self.init(Recorder<Bool>(name, keeping: policy) { interpreter in
                interpreter.stacks[stack]?.isEmpty ?? true
            })
        case .stack(let stack):
            self.init(Recorder<[any Item]>(name, keeping: policy) { interpreter in
                Array(interpreter.stacks[stack] ?? [])
            })
        case .counter:
            self.init(Recorder<Int>(name, keeping: policy) { interpreter in
                interpreter.counter
            })
        case .pushes, .decisions:
            self.init(collecting: spec)
        }
    }

    /// A recorder of what the interpreter gathers during the run (the pushes to a
    /// stack, the decision log): one reading, at the end, is all there is to take.
    private init(collecting spec: RecorderSpec) {
        if case .pushes(let stack) = spec.target {
            self.init(Recorder<[any Item]>(spec.name, keeping: .finalOnly) { interpreter in
                interpreter.pushCollectors[stack]?.items ?? []
            }, watching: stack)
        } else {
            self.init(Recorder<[Decision]>(spec.name, keeping: .finalOnly) { interpreter in
                interpreter.decisionLog ?? []
            }, watchingDecisions: true)
        }
    }
}


nonisolated extension Interpreter {
    /// Builds a recorder from a `RecorderSpec` and installs it, keyed by name.
    func addRecorder(_ spec: RecorderSpec) {
        recorders[spec.name] = AnyRecorder(spec)
    }

    /// Installs several recorders from their specifications.
    func addRecorders(_ specs: [RecorderSpec]) {
        for spec in specs { addRecorder(spec) }
    }

    /// The data a named recorder has collected, type-erased. `nil` when no
    /// recorder is installed under `.name`.
    func recordedData(_ name: String) -> [Any?]? {
        recorders[name]?.dataAsAnyArray
    }
}
