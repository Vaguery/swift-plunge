//
//  InstructionTag.swift
//  PushInterpreter
//
//  **Tags: overlapping, labelled subsets of the language, in an open vocabulary.**
//
//  A tag explains something about the instructions that carry it: what types they
//  touch, what they do, what they cost, how they might be used. Tags overlap freely,
//  and they are not a fixed ontology. The library seeds the vocabulary, and anyone
//  may add to it: `"planeGeometry"`, a project's name, or `"psb:sortedVectors"` to
//  mark the instructions a benchmark should not be given.
//
//  The seed has two sources, and every built-in tag says which (`provenance`):
//
//  - **Derived** tags are computed from what the Behaviors declare: their
//    requirements, outputs, class and observed stacks (`AutomaticTags.swift`). They
//    cannot disagree with the definitions, and they cannot see what the definitions
//    don't say: an int used as an index and an int used as data look the same.
//  - **Declared** tags are judgments written at a Behavior (`fallible`, `risky`,
//    `cruxOnly`, `reEntrant`): things worth knowing that nothing else here records.
//
//  `InstructionTagging` is the table that joins them, and the place to layer your
//  own tags over the standard ones. The role partition (`InstructionRole`) is a
//  different thing: every instruction in exactly one, by where it is registered.
//
//  ## Every tag says where its judgment came from
//
//  Every limit in `Interpreter` records whether its number is chosen, inherited,
//  or derived, because a number with no stated reason is indistinguishable from
//  cargo. A tag gets the same discipline. `.risky` on `.execY` was first
//  **inherited**, from Clojush and Push3 experience, and has since been **measured**
//  here; saying which is the difference between a finding and a rumour.
//

/// Where a tag's judgment came from: the taxonomy `Interpreter`'s limits use,
/// applied to categories rather than to numbers.
public nonisolated enum TagProvenance: String, Sendable, Codable, Hashable {
    /// Taken from another Push implementation for comparability. Change it freely;
    /// the cost is that runs stop being comparable with theirs.
    case inherited
    /// A policy of ours, arrived at here. Change it at will.
    case chosen
    /// Observed in this codebase: by a sweep, a fuzz run, or a benchmark. The only
    /// kind a test can contradict.
    case measured
    /// Established by **reading** the behaviors rather than by running them. Weaker
    /// than `.measured`, because nothing re-checks it when a body changes; stronger
    /// than `.chosen`, because it is a claim about the code that someone could go
    /// and falsify by hand.
    case inspected
    /// **Computed from the Behaviors' declarations**, so it cannot disagree with
    /// them. It is only as fine as they are.
    case derived
}

/// What a tag describes, for grouping tags in a display.
public nonisolated enum TagFacet: String, Sendable, Codable, Hashable, CaseIterable {
    /// The kinds of value an instruction touches.
    case types
    /// How it acts on the interpreter: its `BehaviorClass`.
    case mechanics
    /// What it does.
    case kind
    /// What running it costs.
    case cost
    /// How a search might use it.
    case use
    /// A judgment declared at its definition.
    case judgment
    /// A tag this library does not ship.
    case custom
}

/// A label for a set of instructions. Open: any string is a tag, and the ones this
/// library ships are static members. See the file note and `InstructionTagging`.
public nonisolated struct InstructionTag: RawRepresentable, Hashable, Codable, Sendable,
                                          ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }

    // MARK: - Types

    /// Touches only bools, ints, doubles and chars.
    public static let scalar = InstructionTag("scalar")
    /// Touches only ints and doubles.
    public static let numeric = InstructionTag("numeric")
    /// Touches chars, strings or vectors of strings.
    public static let textual = InstructionTag("textual")
    /// Touches a string, a vector or a block.
    public static let collection = InstructionTag("collection")
    /// Touches a vector.
    public static let vector = InstructionTag("vector")
    /// Touches an iterator or a binding: a loop or a variable made into an item.
    public static let reified = InstructionTag("reified")

    // MARK: - Mechanics (the Behavior classes)

    /// A pure, partial function on typed values (`BehaviorClass.operation`).
    public static let operation = InstructionTag("operation")
    /// Rearranges a stack's positions without looking at values (`BehaviorClass.structural`).
    public static let structural = InstructionTag("structural")
    /// Reads the run's state: constants, inputs, depths, searches of a stack (`BehaviorClass.contextRead`).
    public static let contextRead = InstructionTag("contextRead")
    /// Writes the rest of the program (`BehaviorClass.control`).
    public static let control = InstructionTag("control")
    /// Prints (`BehaviorClass.channel`).
    public static let channel = InstructionTag("channel")

    // MARK: - Kind

    /// Arithmetic or logic within one scalar type.
    public static let calculation = InstructionTag("calculation")
    /// Reads its arguments and leaves them, giving a value about them.
    public static let inspection = InstructionTag("inspection")
    /// An inspection that answers with a bool: a test or a comparison.
    public static let detection = InstructionTag("detection")
    /// Relates two values of one type: order, equality, containment.
    public static let comparison = InstructionTag("comparison")
    /// Gives a size or a count.
    public static let measurement = InstructionTag("measurement")
    /// Finds something: a position, a matching element, an element copied out.
    public static let search = InstructionTag("search")
    /// Copies, deletes or reorders items on a stack, the family every stack has.
    public static let stackCombinator = InstructionTag("stackCombinator")
    /// Runs one block or another, or a block or nothing.
    public static let branching = InstructionTag("branching")
    /// Runs a body more than once.
    public static let looping = InstructionTag("looping")
    /// Applies a block to values: map, filter, reduce, and running a block with a value bound.
    public static let higherOrder = InstructionTag("higherOrder")
    /// Runs or places code without choosing or repeating: the combinators over blocks, and deref.
    public static let execution = InstructionTag("execution")
    /// Consumes values and makes a new one, other than a calculation.
    public static let transformation = InstructionTag("transformation")
    /// Changes a value's type, or quotes it as a block.
    public static let conversion = InstructionTag("conversion")
    /// Puts collections or elements together into one.
    public static let assembly = InstructionTag("assembly")
    /// Takes a collection apart: cuts it, or hands out or takes out its elements.
    public static let disassembly = InstructionTag("disassembly")
    /// Turns a collection into another of the same type.
    public static let reshaping = InstructionTag("reshaping")
    /// Pushes a constant or an input.
    public static let source = InstructionTag("source")
    /// Reports on the run itself: stack depths, error counts, the step count.
    public static let introspection = InstructionTag("introspection")
    /// Makes, finds or changes bindings.
    public static let naming = InstructionTag("naming")
    /// Builds, inspects or adjusts an iterator.
    public static let iterators = InstructionTag("iterators")
    /// None of the kinds above fits. Look at its summary.
    public static let complicated = InstructionTag("complicated")

    // MARK: - Cost

    /// Puts work on `.exec` for later steps.
    public static let addsSteps = InstructionTag("addsSteps")
    /// Repeats with nothing in its arguments to bound it; only the step limit or the body stops it.
    public static let mayRunUnbounded = InstructionTag("mayRunUnbounded")
    /// Runs blocks in sub-interpreters, whose steps are charged to the run.
    public static let runsSubprograms = InstructionTag("runsSubprograms")

    // MARK: - Use

    /// Gives a kind of data it did not take: a representation-changer, worth
    /// keeping in play when a search narrows its instructions.
    public static let bridge = InstructionTag("bridge")

    // MARK: - Judgment (declared at the Behavior)

    /// Re-pushes a continuation of itself onto `.exec`, so while its loop is in
    /// flight the instruction sits somewhere down `.exec` waiting for the next
    /// pass. **The runaway guard's control-side signal**: a fast-filling stack is
    /// only a runaway if something is actively feeding it.
    public static let reEntrant = InstructionTag("reEntrant")

    /// Known to make trouble: deep recursion, runaway self-application.
    ///
    /// **Measured here, not only inherited.** A program containing `.execY` hits
    /// the step limit 76% of the time against a 32% baseline (z = 14 over 2,500
    /// random programs); `.execS`, which looks like it belongs in the same pile,
    /// comes in at 36%: one standard error, i.e. nothing. Re-run
    /// `InstructionRiskProfile` before adding to this set, and before believing
    /// anyone who already did.
    ///
    /// That measurement shows correlation with a bad ending in *random* programs,
    /// which is grounds for the tag. Whether something destabilises an evolving
    /// *population* only a long search can answer.
    public static let risky = InstructionTag("risky")

    /// Wants so many arguments that it starves in practice, so it is dead weight
    /// in an evolvable genome even though it works. Useful when reconstructing a
    /// crux by hand; not worth a slot in a random program.
    public static let cruxOnly = InstructionTag("cruxOnly")

    /// **Can refuse arguments it found**: having been satisfied, it ran and then
    /// refused: divide by zero, an overflow, a non-finite result, a setter handed a
    /// field its kind does not have.
    ///
    /// The line is *when*, not *what*. Starvation is refusal **before** the body
    /// runs, and every instruction with requirements can starve
    /// (`Runner.alwaysSatisfiedInstructions` lists the rest).
    ///
    /// **Not** the five combinator families whose bodies contain an "on empty
    /// stack" guard. Those sit behind `alsoNeeds: [stack: 2]`, so the Planner
    /// refuses first and the guard cannot fire; tagging them would describe a
    /// branch no program can reach. That distinction is why this tag is
    /// `.inspected` and not something a grep for `ErrorItem` could produce.
    public static let fallible = InstructionTag("fallible")

    /// The tags this library ships, in display order.
    public static let known: [InstructionTag] = catalog.map(\.tag)
}

public nonisolated extension InstructionTag {

    /// A one-line description, for tooltips and legends.
    var summary: String { Self.entries[self]?.summary ?? "Tag '\(rawValue)'." }

    /// What this tag describes. A tag this library does not ship is `.custom`.
    var facet: TagFacet { Self.entries[self]?.facet ?? .custom }

    /// Where this tag's judgment came from. A tag minted elsewhere reports
    /// `.chosen`: someone made it up on purpose, which is exactly what that means.
    var provenance: TagProvenance { Self.entries[self]?.provenance ?? .chosen }

    /// **Why**, not just *that*: for a derived tag, the rule that computes it.
    var rationale: String {
        Self.entries[self]?.rationale ?? "No rationale recorded. A tag minted locally should say why it exists."
    }
}

nonisolated extension InstructionTag {

    struct Entry: Sendable {
        let tag: InstructionTag
        let facet: TagFacet
        let provenance: TagProvenance
        let summary: String
        let rationale: String
    }

    // swiftlint:disable line_length
    static let catalog: [Entry] = [
        Entry(tag: .scalar, facet: .types, provenance: .derived, summary: "Touches only bools, ints, doubles and chars.",
              rationale: "Every stack in its arguments, observed stacks and results is bool, int, double or char."),
        Entry(tag: .numeric, facet: .types, provenance: .derived, summary: "Touches only ints and doubles.",
              rationale: "Every stack it touches is int or double."),
        Entry(tag: .textual, facet: .types, provenance: .derived, summary: "Touches chars, strings or vectors of strings.",
              rationale: "One of the stacks it touches is char, string or vecString."),
        Entry(tag: .collection, facet: .types, provenance: .derived, summary: "Touches a string, a vector or a block.",
              rationale: "One of the stacks it touches is string, code or a vector."),
        Entry(tag: .vector, facet: .types, provenance: .derived, summary: "Touches a vector.",
              rationale: "One of the stacks it touches is a vector stack."),
        Entry(tag: .reified, facet: .types, provenance: .derived, summary: "Touches an iterator or a binding.",
              rationale: "One of the stacks it touches is iterator or binding."),

        Entry(tag: .operation, facet: .mechanics, provenance: .derived, summary: "A pure, partial function on values.",
              rationale: "Its declared BehaviorClass."),
        Entry(tag: .structural, facet: .mechanics, provenance: .derived, summary: "Rearranges a stack, blind to values.",
              rationale: "Its declared BehaviorClass."),
        Entry(tag: .contextRead, facet: .mechanics, provenance: .derived, summary: "Reads the run's state.",
              rationale: "Its declared BehaviorClass."),
        Entry(tag: .control, facet: .mechanics, provenance: .derived, summary: "Writes the rest of the program.",
              rationale: "Its declared BehaviorClass."),
        Entry(tag: .channel, facet: .mechanics, provenance: .derived, summary: "Prints.",
              rationale: "Its declared BehaviorClass."),

        Entry(tag: .calculation, facet: .kind, provenance: .derived, summary: "Arithmetic or logic within one scalar type.",
              rationale: "An operation whose arguments and results are all on one scalar stack."),
        Entry(tag: .inspection, facet: .kind, provenance: .derived, summary: "Reads its arguments and leaves them.",
              rationale: "Reads or observes its arguments, takes nothing but an int, and gives fixed results other than a binding."),
        Entry(tag: .detection, facet: .kind, provenance: .derived, summary: "An inspection that answers with a bool.",
              rationale: "An inspection giving one bool."),
        Entry(tag: .comparison, facet: .kind, provenance: .derived, summary: "Relates two values of one type.",
              rationale: "Reads two items of one stack and gives a bool: order, equality, containment."),
        Entry(tag: .measurement, facet: .kind, provenance: .derived, summary: "Gives a size or a count.",
              rationale: "An inspection giving one int about something that is not an int, and either reading one thing or never refusing."),
        Entry(tag: .search, facet: .kind, provenance: .derived, summary: "Finds a position or an element.",
              rationale: "An inspection giving an item with its position, an int that refuses on a miss, or an element copied out of a collection that refuses when there is none."),
        Entry(tag: .stackCombinator, facet: .kind, provenance: .derived, summary: "The copy, delete and reorder family every stack has.",
              rationale: "Structural, or registered in the generated stack family."),
        Entry(tag: .branching, facet: .kind, provenance: .derived, summary: "Runs one block or another.",
              rationale: "Control that takes a bool and is not a loop."),
        Entry(tag: .looping, facet: .kind, provenance: .derived, summary: "Runs a body more than once.",
              rationale: "Declared reEntrant, or applies a block per element, or declared looping (the counted loops hand their loop to an iterator, which no declaration shows)."),
        Entry(tag: .higherOrder, facet: .kind, provenance: .derived, summary: "Applies a block to values.",
              rationale: "Runs blocks in sub-interpreters, or is control that reads a value and takes a block to run with it."),
        Entry(tag: .execution, facet: .kind, provenance: .derived, summary: "Runs or places code.",
              rationale: "Writes the continuation without branching, looping or applying."),
        Entry(tag: .transformation, facet: .kind, provenance: .derived, summary: "Makes a new value from what it consumes.",
              rationale: "An operation that consumes and gives values, other than a calculation, a binding or an iterator."),
        Entry(tag: .conversion, facet: .kind, provenance: .derived, summary: "Changes a value's type, or quotes it.",
              rationale: "A transformation from one type to another that is not its element, or of one item into a block."),
        Entry(tag: .assembly, facet: .kind, provenance: .derived, summary: "Puts collections or elements together.",
              rationale: "Takes two of a collection, or a collection and its element, or a variable number of elements, and gives that collection."),
        Entry(tag: .disassembly, facet: .kind, provenance: .derived, summary: "Takes a collection apart.",
              rationale: "Delivers elements, cuts a collection in two, or takes an element out."),
        Entry(tag: .reshaping, facet: .kind, provenance: .derived, summary: "A collection in, the same kind out.",
              rationale: "A transformation giving one collection of a type it took."),
        Entry(tag: .source, facet: .kind, provenance: .derived, summary: "Pushes a constant or an input.",
              rationale: "Produces a deferred push or an input."),
        Entry(tag: .introspection, facet: .kind, provenance: .derived, summary: "Reports on the run itself.",
              rationale: "A context read giving one int or bool, not about bindings, and not a search."),
        Entry(tag: .naming, facet: .kind, provenance: .derived, summary: "Makes, finds or changes bindings.",
              rationale: "Takes, reads, observes or rearranges .binding, or gives a binding."),
        Entry(tag: .iterators, facet: .kind, provenance: .derived, summary: "Builds, inspects or adjusts an iterator.",
              rationale: "Gives an iterator, from an iterator or from other values."),
        Entry(tag: .complicated, facet: .kind, provenance: .derived, summary: "No other kind fits; see its summary.",
              rationale: "Carries no other kind tag and is not a print."),

        Entry(tag: .addsSteps, facet: .cost, provenance: .derived, summary: "Puts work on .exec for later steps.",
              rationale: "Produces a continuation, a delivery, a deferred push or an input, or is reEntrant."),
        Entry(tag: .mayRunUnbounded, facet: .cost, provenance: .derived, summary: "Nothing in its arguments bounds it.",
              rationale: "reEntrant, and takes nothing but a bool and one block."),
        Entry(tag: .runsSubprograms, facet: .cost, provenance: .derived, summary: "Runs blocks in sub-interpreters.",
              rationale: "An applying body, whose sub-interpreters' steps are charged to the run."),

        Entry(tag: .bridge, facet: .use, provenance: .derived, summary: "Gives a kind of data it did not take.",
              rationale: "An operation giving a stack, other than int or bool, that it neither took, read nor observed."),

        Entry(tag: .reEntrant, facet: .judgment, provenance: .inspected, summary: "Re-pushes itself onto .exec to drive a loop.",
              rationale: "Read off each behavior's own continuation: these are the instructions that put a copy of themselves back on .exec."),
        Entry(tag: .risky, facet: .judgment, provenance: .measured, summary: "Known to destabilise an evolving population.",
              rationale: "Suggested by Clojush and Push3 experience, then measured here: .execY hits the step limit 76% of the time against a 32% baseline, z = 14 over 2,500 random programs. The same measurement is what keeps .execS out: it looks like it belongs and scores z = 1.0, which is noise. See InstructionRiskProfile."),
        Entry(tag: .cruxOnly, facet: .judgment, provenance: .measured, summary: "Starves in practice; useful in a crux, not in a genome.",
              rationale: "Measured: the iteratorFrom… constructors want about 7 arguments and starve close to 100% of the time in random programs."),
        Entry(tag: .fallible, facet: .judgment, provenance: .inspected, summary: "Can refuse the arguments it was given.",
              rationale: "By inspection of each behavior body: these construct an ErrorItem for a reason other than starvation. A Behavior declares what it produces, not when it refuses.")
    ]
    // swiftlint:enable line_length

    static let entries: [InstructionTag: Entry] =
        Dictionary(uniqueKeysWithValues: catalog.map { ($0.tag, $0) })
}

nonisolated extension Interpreter {

    /// The language indexed by declared tag. Built once, beside `language`, by
    /// asking each `Behavior` what it declared.
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

    /// Every tag `instruction` declares: possibly none, which is the common case.
    static func declaredTags(of instruction: PushInstruction) -> Set<InstructionTag> {
        language[instruction]?.tags ?? []
    }

    /// The instructions declaring each tag, **sorted**: the reproducible form to
    /// draw from. A `Set`'s iteration order is per-process random; see `Roles.swift`.
    static let sortedDeclaredTags: [InstructionTag: [PushInstruction]] =
        declaredTags.mapValues { $0.sorted { $0.rawValue < $1.rawValue } }
}
