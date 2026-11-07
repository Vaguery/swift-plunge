//
//  InstructionTag.swift
//  PushInterpreter
//
//  **Judgment about instructions, declared where they are defined.**
//
//  The third and last classification channel, and the only one that can be wrong.
//  Keeping it apart from the other two is the load-bearing constraint:
//
//  | | Shape | Source | Can it lie? |
//  |---|---|---|---|
//  | `InstructionRole` | strict partition | which dictionary defines it | no |
//  | `InstructionTrait` | overlapping, closed | naming families + `requirements` | no |
//  | `InstructionTag` | overlapping, **open** | **declared** at the `Behavior` | **yes** |
//
//  A derived trait cannot lie — `.query` is read off `Behavior.readStacks`, so it
//  is true by construction. A tag can, and that is not a defect: **some things
//  worth knowing are not derivable from anything in this codebase.** That `.execY`
//  is risky is knowledge from other Push implementations. That the `iteratorFrom…`
//  constructors are dead weight in an evolvable genome is a finding about search,
//  not about the interpreter. There is nowhere honest to compute either.
//
//  The danger is merging the two vocabularies: someone eventually hand-declares
//  something `requirements` already knows, and it silently disagrees with the
//  truth. So traits stay closed and derived with no declaration hook, and judgment
//  lives here.
//
//  ## Open, not an enum
//
//  A closed enum would mean a library release to mint a tag, which defeats the
//  purpose for anyone wanting to mark a subset for one experiment. `RawRepresentable`
//  over `String` keeps `.risky` dot-syntax while the vocabulary stays extensible.
//
//  ## Every tag says where its judgment came from
//
//  Design Principles §13 requires a limit to record whether its number is chosen,
//  inherited, or derived, *"because a number with no stated reason is
//  indistinguishable from cargo."* A judgment tag is the same object and gets the
//  same discipline. `.risky` on `.execY` was first **inherited** — from Clojush and
//  Push3 experience — and has since been **measured** here (see `.risky` below);
//  saying which is the difference between a finding and a rumour.
//
//  A tag that *is* checkable must be checked rather than trusted: if one ever
//  duplicates something `requirements` or the traits already know, a test asserts
//  they agree (`Instruction Tag Tests`).
//
//  **And check the ones that look uncheckable, too.** `.risky` was written here as
//  unfalsifiable — a judgment inherited from other implementations, guarded only by
//  its rationale. That was too quick. It is not *provable*, but it is measurable:
//  `InstructionRiskProfile` compares how often a program containing an instruction
//  ends badly against one that does not, and the answer was decisive enough to keep
//  `.execS` out of the set that a downstream app had already put it in. A judgment
//  worth declaring is usually worth trying to measure before declaring it.
//

/// Where a tag's judgment came from — the §13 taxonomy, applied to categories
/// rather than to numbers.
public nonisolated enum TagProvenance: String, Sendable, Codable, Hashable {
    /// Taken from another Push implementation for comparability. Change it freely;
    /// the cost is that runs stop being comparable with theirs.
    case inherited
    /// A policy of ours, arrived at here. Change it at will.
    case chosen
    /// Observed in this codebase — by a sweep, a fuzz run, or a benchmark. The only
    /// kind a test can contradict.
    case measured
    /// Established by **reading** the behaviors rather than by running them. Weaker
    /// than `.measured`, because nothing re-checks it when a body changes; stronger
    /// than `.chosen`, because it is a claim about the code that someone could go
    /// and falsify by hand.
    case inspected
}


/// A declared, overlapping judgment about an instruction. See the file note.
public nonisolated struct InstructionTag: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    /// Re-pushes a continuation of itself onto `.exec`, so while its loop is in
    /// flight the instruction sits somewhere down `.exec` waiting for the next
    /// pass. **The runaway guard's control-side signal**: a fast-filling stack is
    /// only a runaway if something is actively feeding it.
    public static let reEntrant = InstructionTag("reEntrant")

    /// Known to make trouble — deep recursion, runaway self-application.
    ///
    /// **Measured here, not only inherited.** A program containing `.execY` hits
    /// the step limit 76% of the time against a 32% baseline (z = 14 over 2,500
    /// random programs); `.execS`, which looks like it belongs in the same pile,
    /// comes in at 36% — one standard error, i.e. nothing. Re-run
    /// `InstructionRiskProfile` before adding to this set, and before believing
    /// anyone who already did.
    ///
    /// What that measurement can and cannot settle is worth keeping straight: it
    /// shows correlation with a bad ending in *random* programs, which is grounds
    /// for the tag. Whether something destabilises an evolving *population* — what
    /// this tag is finally about — only a long search can answer.
    public static let risky = InstructionTag("risky")

    /// Wants so many arguments that it starves in practice, so it is dead weight
    /// in an evolvable genome even though it works. Useful when reconstructing a
    /// crux by hand; not worth a slot in a random program.
    public static let cruxOnly = InstructionTag("cruxOnly")

    /// **Can raise an error from its own body** — having been satisfied, it ran and
    /// then refused: divide by zero, an overflow, a non-finite result, a setter
    /// handed a field its kind does not have.
    ///
    /// The line is *when*, not *what*. Starvation is refusal **before** the body
    /// runs, and is derived rather than declared — `InstructionTrait.canStarve`,
    /// read off `requirements`. Two names for two questions a search asks
    /// differently: "this often does nothing at all" versus "this can run and still
    /// hand you an error".
    ///
    /// **Not** the five combinator families whose bodies contain an "on empty
    /// stack" guard. Those sit behind `alsoNeeds: [stack: 2]`, so the Planner
    /// refuses first and the guard cannot fire; tagging them would describe a
    /// branch no program can reach. That distinction is exactly why this tag is
    /// `.inspected` and not something a grep for `ErrorItem` could produce.
    public static let fallible = InstructionTag("fallible")

    /// The tags this library ships, in a stable order for display.
    public static let known: [InstructionTag] = [.reEntrant, .risky, .cruxOnly, .fallible]
}


public nonisolated extension InstructionTag {

    /// A one-line description, as `InstructionTrait.summary` does.
    var summary: String {
        switch self {
        case .reEntrant: "Re-pushes itself onto .exec to drive a loop."
        case .risky:     "Known to destabilise an evolving population."
        case .cruxOnly:  "Starves in practice; useful in a crux, not in a genome."
        case .fallible:  "Can refuse the arguments it was given."
        default:         "Declared tag '\(rawValue)'."
        }
    }

    /// Where this tag's judgment came from. Unknown (locally minted) tags report
    /// `.chosen`: someone made them up on purpose, which is exactly what that means.
    var provenance: TagProvenance {
        switch self {
        case .reEntrant: .inspected
        case .risky:     .measured
        case .cruxOnly:  .measured
        case .fallible:  .inspected
        default:         .chosen
        }
    }

    /// **Why**, not just *that* — the half §13 says is the whole point.
    var rationale: String {
        switch self {
        case .reEntrant:
            "Read off each behavior's own continuation: these are the instructions that "
            + "put a copy of themselves back on .exec. Replaces the hand-written "
            + "`PushInstruction.iterators`, which said the same thing far from any definition."
        case .risky:
            "Suggested by Clojush and Push3 experience, then measured here: .execY hits the "
            + "step limit 76% of the time against a 32% baseline, z = 14 over 2,500 random "
            + "programs. The same measurement is what keeps .execS out — it looks like it "
            + "belongs and scores z = 1.0, which is noise. See InstructionRiskProfile."
        case .cruxOnly:
            "Measured: the ~12 iteratorFrom… constructors want ~7 arguments and starve close to "
            + "100% of the time in random programs (Roadmap #17)."
        case .fallible:
            "By inspection of each behavior body: these construct an ErrorItem for a reason "
            + "other than starvation. Not derivable — a Behavior declares what it takes and "
            + "nothing about what it may produce."
        default:
            "No rationale recorded. A tag minted locally should say why it exists."
        }
    }
}


nonisolated extension Interpreter {

    /// The language indexed by declared tag. Built once, beside `language`, by
    /// asking each `Behavior` what it declared — so unlike a hand-written set this
    /// cannot fall out of step with the definitions it describes.
    static let declaredTags: [InstructionTag: Set<PushInstruction>] = {
        var result: [InstructionTag: Set<PushInstruction>] = [:]
        for (name, behavior) in language {
            for tag in behavior.tags { result[tag, default: []].insert(name) }
        }
        return result
    }()

    /// The instructions declaring `tag`, for membership and set algebra.
    static func instructions(declaring tag: InstructionTag) -> Set<PushInstruction> {
        declaredTags[tag] ?? []
    }

    /// Every tag `instruction` declares — possibly none, which is the common case.
    static func declaredTags(of instruction: PushInstruction) -> Set<InstructionTag> {
        language[instruction]?.tags ?? []
    }

    /// The tags declaring `tag`, **sorted** — the reproducible form to draw from.
    /// A `Set`'s iteration order is per-process random; see `Roles.swift`.
    static let sortedDeclaredTags: [InstructionTag: [PushInstruction]] =
        declaredTags.mapValues { $0.sorted { $0.rawValue < $1.rawValue } }
}
