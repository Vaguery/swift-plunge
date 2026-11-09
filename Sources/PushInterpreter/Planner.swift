//
//  Planner.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/16/26.
//
//  Deciding whether a Behavior can run, and finding its arguments, without
//  touching anything until every one of them is found.
//

import DequeModule


/// One thing a Behavior must find before it can run.
///
/// Three kinds today, and they exist because the same shape kept recurring and kept
/// being solved separately — twice by hand and once wrongly. `takes:` alone
/// conflated *what I consume* with *what I need*; `alsoNeeds:` split those apart;
/// and `vecXConstruct` still could not say "N of these, where N is the length of
/// that one" and had to check by hand. All three are the same question — **resolve
/// a requirement against the interpreter, given what is resolved so far** — so they
/// are now one mechanism.
///
/// A fourth kind is designed for and deliberately absent: a **sieve**, resolving to
/// the first item matching a predicate rather than to a position. Admitting it is
/// most of why this shape exists.
nonisolated enum Requirement: Sendable {
    /// Consume one item from the top of `stack` — the topmost not already claimed
    /// by an earlier requirement.
    case takes(PushStack)

    /// `count` further items must be present on `stack`, beyond everything already
    /// claimed — but they are **not** consumed. For a Behavior that reaches in and
    /// reads, reorders or copies without popping. The transformer never sees these
    /// (contrast `.reads`); they are a presence check for side-effect behaviors
    /// that reach into `interpreter.stacks` directly.
    case needs(PushStack, count: Int)

    /// Claim the topmost unclaimed item of `stack`, **give it to the transformer,
    /// but do not remove it.** The non-destructive query's requirement: it reads
    /// the argument's value to report a fact and leaves the argument alive for
    /// reuse. Where `.takes` consumes and `.needs` only checks presence, this does
    /// what both cannot — hand the value over without spending it.
    ///
    /// The *crux* of a query result still reproduces only its fact: it records the
    /// pops that clean up what was read (`Behavior.reading`), because a fragment
    /// that left its argument behind would corrupt a same-stack sibling. Live
    /// keeps the argument; the crux cleans it up.
    case reads(PushStack)

    /// Consume as many items from `stack` as `count` says, where `count` is
    /// computed from the arguments resolved **so far**.
    ///
    /// This is the reason a planner is a planner rather than a tally: the question
    /// "can this run?" cannot be answered before gathering has begun.
    case takesMany(PushStack, count: @Sendable ([any Item]) -> Int)

    var stack: PushStack {
        switch self {
        case .takes(let s):        s
        case .needs(let s, _):     s
        case .takesMany(let s, _): s
        case .reads(let s):        s
        }
    }
}


/// Where one claimed item sits, and whether it is being taken or merely required.
nonisolated struct Claim: Sendable {
    let stack: PushStack
    let index: Int
    let consumed: Bool
}


/// The outcome of planning: either every requirement found a home, or one stack
/// could not supply — and it says **which**, which is a question the
/// argument-starvation probe could never answer for itself.
nonisolated enum GatherPlan {
    case ready(arguments: [any Item], claims: [Claim])
    case short(PushStack)
}


/// Resolves a Behavior's requirements against an interpreter's stacks, reading but
/// never writing, and commits only once every requirement has been satisfied.
///
/// **Why it is a type of its own.** A Behavior says *what* it needs; the Planner
/// works out *where* it is. That keeps a Behavior from reaching through an
/// Interpreter into a Deque and indexing it — the Planner is the only thing here
/// that knows stacks are ordered and indexable at all, and everything else asks in
/// terms of requirements.
///
/// **Why it plans before it takes.** Satisfaction cannot honestly be decided by
/// counting stack depths, because a requirement's size can depend on an argument
/// nobody has read yet (`.takesMany`), and one day on a predicate over candidates
/// (a sieve). So resolution has to read the stacks — and if it read *and* removed
/// as it went, a Behavior that turned out to be unsatisfiable would already have
/// eaten its earlier arguments.
///
/// That is not hypothetical: it is exactly how sixty combinators came to pop an
/// index, find an empty stack, and error having consumed it. Planning first is what
/// keeps the all-or-nothing bargain for every Behavior at
/// once, rather than leaving each to keep it by hand and mostly fail.
nonisolated struct Planner {
    private let interpreter: Interpreter

    init(for interpreter: Interpreter) {
        self.interpreter = interpreter
    }

    /// Resolve every requirement, in order, **without touching the interpreter**.
    ///
    /// Order matters, and is the caller's to choose: each requirement claims the
    /// topmost item its predecessors have not, so `[.takes(.int), .takes(.int)]`
    /// claims index 0 then index 1 — the same two items a pair of pops would take.
    func plan(_ requirements: [Requirement]) -> GatherPlan {
        var arguments: [any Item] = []
        var claims: [Claim] = []
        /// How many items each stack has had claimed so far. Every requirement kind
        /// claims the topmost unclaimed index, so a stack's claims are always the
        /// contiguous run 0..<n — and the next free index is simply n. (This used to
        /// re-scan every claim for each candidate index, which made an N-element
        /// `.takesMany` cost O(N³) inside a single step.)
        var claimedCount: [PushStack: Int] = [:]

        func claim(_ stack: PushStack, consuming: Bool) -> (any Item)? {
            let index = claimedCount[stack, default: 0]
            guard let item = item(at: index, on: stack) else { return nil }
            claims.append(Claim(stack: stack, index: index, consumed: consuming))
            claimedCount[stack] = index + 1
            return item
        }

        for requirement in requirements {
            switch requirement {
            case .takes(let stack):
                guard let item = claim(stack, consuming: true) else { return .short(stack) }
                arguments.append(item)

            case .reads(let stack):
                // Given to the transformer like `.takes`, but claimed
                // non-consuming so `commit` leaves it on the stack.
                guard let item = claim(stack, consuming: false) else { return .short(stack) }
                arguments.append(item)

            case .needs(let stack, let count):
                for _ in 0..<count {
                    guard claim(stack, consuming: false) != nil else { return .short(stack) }
                }

            case .takesMany(let stack, let count):
                // The count is asked of the arguments already resolved — which is
                // why this cannot happen before planning starts.
                for _ in 0..<max(0, count(arguments)) {
                    guard let item = claim(stack, consuming: true) else { return .short(stack) }
                    arguments.append(item)
                }
            }
        }
        return .ready(arguments: arguments, claims: claims)
    }

    /// Remove everything a finished plan means to take. Call only with the claims
    /// from a `.ready` plan; anything else would take items for a run that is not
    /// going to happen.
    func commit(_ claims: [Claim]) {
        // Descending index, or removing a shallow claim shifts a deeper one out
        // from under itself. Stacks do not interfere, so one sort covers them all.
        for claim in claims.filter(\.consumed).sorted(by: { $0.index > $1.index }) {
            interpreter.take(at: claim.index, from: claim.stack)
        }
    }

    /// The one place that knows a stack is something you can index into.
    private func item(at index: Int, on stack: PushStack) -> (any Item)? {
        interpreter.stacks.item(at: index, on: stack)
    }
}
