# Grammars as patterns: PEGs in Push (2026-11-09)

**Status: explored, not ruled; saved for step 6 or later** (the user, 2026-11-09),
its questions (§9) still open. Written before step 4b of the coverage audit
(*Behavior coverage audit (2026-11-09)* §8, §11). It answers Roadmap #34
(pattern as a first-class item) with a specific proposal, and asks the
questions in §9.

The user's prompt: with `.ref` handling keyed storage, and pattern lookups on
the stacks, string matching (and perhaps vectors) "opens the possibility of
using Parsing Expression Grammars". How easily would a PEG representation work
for strings, code and the other structured types?

**Short answer: easily, and better than a regex would. A PEG is a tree of a few
combinators over terminals, so it can be a *reading of a code block*, the same
way a function is a code block with `.inputN` holes. No new type, no new
stack, no syntax that can fail to parse. One matcher, generic over "a sequence
of elements", serves strings, the four vectors, and code (where it becomes a
tree matcher). The fixed kinds already built (Equal, Prefix, Containing,
Shape) are all special cases of it.**

---

## 1. What a PEG is, and why it suits Push

A parsing expression grammar (Ford, 2004) has:

| Expression | Meaning |
|---|---|
| terminal `a` | match one element equal to `a` (or a literal run) |
| any `.` | match any one element |
| sequence `e₁ e₂` | match e₁, then e₂ from where it stopped |
| **ordered** choice `e₁ / e₂` | try e₁; only if it fails, try e₂ |
| `e*`, `e+`, `e?` | greedy repetition, never backtracked into |
| `&e`, `!e` | lookahead: succeed if e would (or would not) match; consume nothing |
| nonterminal `A` | a named rule, possibly recursive |

Three properties make it a better fit than regular expressions:

1. **Deterministic by construction.** Ordered choice and possessive repetition
   mean a PEG has *one* parse or none. There is no ambiguity and no "which of
   the matches" question. That is the audit's first constraint (no stochastic
   Behaviors) met by the formalism itself, not by a tie-breaking rule.
2. **A PEG is a tree, not a string.** A regex is a string in a second syntax:
   most mutations of it are syntax errors, and string instructions edit it
   blindly. A PEG is naturally an S-expression, so it can be a code block, and
   every `code` instruction already edits it (homoiconicity principle).
3. **It extends to structured data.** OMeta (Warth & Piumarta, 2007) showed
   that PEGs match lists and trees as easily as text: a pattern in brackets
   matches *one element that is itself a list*, whose contents match the
   inner pattern. That is the step from strings to code.

**Cost.** Without memoization, a PEG with nested choices can backtrack
exponentially; packrat memoization makes it linear in the subject at the cost
of a table. We need neither: subjects are capped at 1,000 (`maxStringLength`,
`maxVectorLength`, `maxCodePoints`), and the matcher's work can be **charged to
the program's step budget** exactly as map's sub-runs are (`ReadContext.charge`).
A pathological pattern then runs out of steps and is refused, like a runaway
map. One more standard guard: a repetition stops when an iteration consumes
nothing, so `(ε)*` cannot loop.

---

## 2. The representation: a pattern is a code block, read as a PEG

The proposal mirrors map's design: **"a function is a block with `.inputN`
holes" becomes "a pattern is a block read as a grammar".** The pattern comes
from `.code`, as the ruling has it for every block argument ("most exec
arguments should come from `code`").

### Reading every item (totality)

Every item must mean *something* as a pattern, or random and evolved blocks
would mostly be malformed. Push's rule for a meaningless instruction is "do
nothing", so the pattern rule for a meaningless item is **ε: match the empty
sequence and succeed**.

| Item in the pattern | Reads as |
|---|---|
| a block with no `peg` head | **sequence** of its items |
| `( .pegChoice A B … )` | ordered choice among A, B, … |
| `( .pegStar A … )`, `( .pegPlus A … )`, `( .pegOptional A … )` | repetition of the sequence A … |
| `( .pegAnd A … )`, `( .pegNot A … )` | lookahead |
| `( .pegInside A … )` | one element **that is itself a sequence** (a block, a string in a `vecString`) whose whole contents match A … |
| `.pegSelf` | the whole pattern again: recursion (§5) |
| a literal of the **element** type (`'a'` on a string, `7` on a `vecInt`, `"x"` on a `vecString`) | that element |
| a literal of the **subject** type (`"ab"` on a string, `[1 2]` on a `vecInt`) | that run of elements |
| `true` / `false` | any one element / fail |
| an int, where ints are not the element type | any *n* elements (a negative *n* fails) |
| an instruction that **reads one element and gives a bool** (`.charIsDigit`, `.charIsUpper`, `.stringItemIsEmpty`, …) | a **class**: one element for which the predicate holds |
| anything else (other instructions, other types) | ε |

The class rule is the payoff of the homoiconic choice. The language's
existing predicates become the pattern language's character classes, with no
new instructions: `.charIsDigit` is `[0-9]`, `.charIsWhitespace` is `\s`, and so
on. Each new predicate added to the language becomes a new class for free.
Ints and doubles have no unary predicates yet (only `intSign`), so for numbers
a general **`( .pegWhere B )`** would run the element followed by the block B
in a sub-run (the stack-fed `Interpreter.apply(_:after:in:)` that iterators
already use) and test the last push for `true`: `( .pegWhere 0 .intGT )` is
"a positive element". It is costlier, and charged like map.

### Examples

```
( .charIsLetter ( .pegStar .charIsLetter ) )         a word: [A-Za-z]+
( ( .pegOptional '-' ) .charIsDigit ( .pegStar .charIsDigit ) )      an integer
( "key" ( .pegStar ( .pegNot ';' ) true ) )          "key" then all up to ';'
( '(' ( .pegStar ( .pegChoice ( .pegNot '(' .pegNot ')' true ) .pegSelf ) ) ')' )
                                                      balanced parentheses
```

On code, OMeta-style:

```
( .pegInside "a" true )            a sub-block whose contents are "a" then any one item:
                                    the association ( "a" 1 ), of any value
( .pegInside 1 2 .intAdd )         a sub-block that is exactly ( 1 2 .intAdd )
```

### The `peg` instructions also run as ordinary code

A `.pegStar` met on `.exec` must do something. It **builds**: it takes the top
of `.code` and pushes `( .pegStar that )`, and `.pegChoice` takes two and
pushes `( .pegChoice A B )`. So the same instruction is the constructor when
executed and the tag when read as data, and a program can assemble grammars
the ordinary way (`codeQuote`, `codeCons`, `codeConcat`) or by these
constructors. There are eight or nine of them: `Choice`, `Star`, `Plus`,
`Optional`, `And`, `Not`, `Inside`, `Self`, and perhaps `Where`.

---

## 3. One matcher, many subjects

The matcher is generic over a **subject: a random-access sequence of elements,
some of which may themselves be subjects** (for `.pegInside`).

| Subject | Elements | Terminals that mean something | `.pegInside` descends into |
|---|---|---|---|
| string | characters | chars, strings, char predicates | (a single char, trivially) |
| `vecInt`, `vecDouble` | numbers | the number, sub-vectors, `.pegWhere` | — |
| `vecBool` | bools | the bool (note: `true`/`false` collide with "any/fail"; §9 Q4) | — |
| `vecString` | strings | the string, string predicates | **each string**, as text: a grammar for words inside a grammar for lists of words |
| code | root items | any item by `isEqual`, nested blocks by `.pegInside` | **each sub-block** |

`vecString` and code are where grammars nest: a list-of-words grammar whose
items are word grammars, and a tree grammar.

### The fixed kinds are special cases

| Built kind | As a pattern |
|---|---|
| Equal *p* | the whole subject is *p* (anchored, to the end) |
| Prefix *p* | *p*, anchored at the start, unanchored at the end |
| Containing *p* | found anywhere: the standard PEG search `( .pegStar ( .pegNot p ) true ) p` |
| Shape (code) | *p* with each atom replaced by its type's class |

They should **stay**. The audit's second constraint asks for several ways to
do each low-level task, and a fixed kind's probe comes from the searched stack
itself (well fed), where a grammar's comes from `.code`. The grammar is the
way that combines; the kinds are the ways that need no assembly.

---

## 4. Where a pattern is used

Each use takes the pattern from `.code` and is a `.reads` query on the subject
where it answers a question.

| Instruction (per subject X) | Result | Note |
|---|---|---|
| `xMatches` | bool: the whole subject matches | the anchored test |
| `xMatchLength` | int: how much of the front matches, or a refusal | PEG's native answer |
| `xFind` / `xFindFrom` | the first matching stretch **and its index** | the user's "item and position" rule; `From` starts at an index |
| `xStackFind` / `…From` | lookup on the stack by grammar: a copy of the first item that matches whole, and its position | §8's lookups with a grammar for a kind; the probe is the pattern, so the search starts at the top |
| `xSplitOn` (string, vectors) | the pieces between matches | generalizes `stringSplitOn` |
| `xReplaceAll` | the subject with each match replaced by a given value | generalizes `stringReplace` |

Six subject types times about six uses is roughly 36; with the constructors,
about **45 instructions**, all from three generic helpers (`matches`,
`find`, `split`) plus the matcher. That is close to the size of step 4.

**Provenance** is unproblematic. The matcher is a pure function of (pattern,
subject), so a found stretch is a written call on both cruxes; a matched
substring keeps its characters' origins (as `stringTrim` does); a stack
position is a stand-in (law 4b), as for the lookups already built.

### Not provided: benchmark trivializers

- **All match positions as a `vecInt`** (or an iterator emitting positions):
  with a literal pattern, that is PSB2 *Indices of Substring* in two steps.
  `xFindFrom` in a loop gets there, and evolving that loop is the benchmark.
- **A count of matches**, combined with a vowel class: PSB1 *Syllables*. There
  is no vowel predicate, and there should not be one; a vowel choice
  `( .pegChoice 'a' 'e' 'i' 'o' 'u' 'y' )` is evolvable, but a count-matches
  instruction would leave only that choice to find. Leave it out unless it is
  measured to be harmless.
- **Backreferences** ("the same letter again") are not PEG and are not
  proposed; PSB1 *Double Letters* stays a looping problem.

---

## 5. Recursion, and the `.ref` connection

Without recursion a PEG is not much stronger than a regular expression with
lookahead; balanced nesting needs a rule to refer to itself.

- **`.pegSelf`** (one rule, the whole pattern) is enough for balanced
  brackets and nested lists, and has no naming problem. A depth limit
  (the code nesting limit) plus the step charge bounds it.
- **Many rules** would naturally live on the coming **`.ref` stack**:
  `( .pegRule k )` matches whatever pattern is bound to key *k*, so a grammar
  is an environment of bindings, mutual recursion comes free, and rebinding a
  key changes a rule for the scope of a `with`. That is a reason to build
  `.ref` before grammars, and to keep `.pegRule` for after.
- **Left recursion** (`A ← A x / y`) loops in a plain PEG. With the step
  charge it is refused rather than hung, and that is enough.

## 6. Captures (later)

A capturing PEG returns a parse tree rather than a yes/no, and for Push a
parse tree is naturally a code block (homoiconic again): `( .pegCapture A )`
marks a stretch, and `xParse` returns a block of the captured stretches, as
strings for a string subject, as sub-blocks for code. This is the parsing
payoff ("split this line into fields by grammar") but doubles the matcher's
bookkeeping. Proposed as a second stage once matching is measured.

---

## 7. Will evolution find patterns? — the risk to measure

A random block read as a pattern will be mostly ε (most of its items are
instructions with no pattern reading), so it **matches almost everything**,
trivially. A block with many int literals will often fail, because large ints
read as "skip *n*". So random patterns sit at both extremes, and the useful
middle needs evolved assembly. Two measurements before committing to the full
family, as for the lookups:

1. **Match rates by subject** for random patterns over random subjects (the
   `Lookup Match Rates` harness, with a grammar kind).
2. **Pattern selectivity**: the fraction of random patterns that match some but
   not all of the items they are tried on. ε-everything and fail-everything
   patterns are both useless as *selection*.

If random patterns are hopelessly unselective, clamping "skip *n*" to small *n*
and giving instructions with no reading a *fail* meaning instead of ε are the
two knobs (§9 Q2).

## 8. Smaller alternatives considered

- **A regex string type.** Rejected: a second syntax, mostly unparsable
  under mutation, and nondeterminism to rule out by convention.
- **A `.pattern` stack of compiled pattern items.** Rejected for the reason
  §8 of the audit gave: a stack only its own constructors feed starves, and
  `.code` is the best-fed stack there is.
- **Only the fixed kinds, never combined.** That is what is built; this note
  is the case for combining them, which the audit deferred "if the kinds turn
  out to want combining".

## 8b. Other grammar systems (the user's follow-up: "CFGs, or some other matcher")

The representation in §2 does not commit to PEG semantics. A block of
choices, sequences and repetitions can be *read* under more than one
formalism, so the real choice is which matcher reads it.

| System | What it adds | What it costs here |
|---|---|---|
| **PEG** (proposed) | one parse or none; linear with memo, small without; lookahead | cannot express some ambiguous context-free languages naturally; ordered choice means alternative order matters |
| **CFG** (Earley or CYK recognizer) | unordered choice: the alternatives' order does not matter, which is kinder to mutation; the classic formal class; **also generates** (below) | O(n³) worst case, so a 1,000-element subject is up to 10⁹ operations, only bounded by the step charge; **ambiguous**: recognition (yes/no) is still deterministic, but "which parse" and "which stretch" need a fixed tie-break (leftmost, then longest), and captures need a choice of tree |
| **Tree automata / tree grammars** | the right formalism for code as trees, with regular tree languages closed under intersection and complement | only for code; OMeta-style `.pegInside` gets most of it inside the PEG reading |
| **Unification patterns** (Lisp/Prolog style, pattern variables) | `( ?x ?x )` says "the same thing twice", which neither PEG nor CFG can; bindings would naturally go to **`.ref`** keys | variables are a second kind of state; and `( ?x ?x )` with a Find nearly is PSB1 *Double Letters*, so it is a trivializer to measure first |
| **Regex** | familiar | rejected in §8 |
| **Attribute / boolean grammars, parser combinators** | more power; combinators are what PEG is in code | no case yet that PEG plus `.ref` rules lacks |

**Generation is the one thing CFGs give that PEGs do not.** A CFG is also a
*producer*: the *k*-th string of a grammar (in a fixed enumeration order) is
deterministic. That ties to the key-supply question (audit §10): a grammar
could generate structured keys or test strings, and it is the mechanism of
grammatical evolution. A PEG can only recognize.

**Recommendation: one representation, more than one reading.** Build the PEG
reading first, because its "first match" and "the parse" are unique without a
tie-break and its cost is small. A CFG reading of the *same blocks* can come
later as a second instruction family (`xMatchesCFG`, and a generator
`xFromGrammar` taking *k*), which is the audit's "several ways" applied to
matching: the same evolved pattern, read strictly in order or as unordered
alternatives. `.pegChoice` would then be named for the shape it gives
(`.patternChoice`), not for one formalism. Unification waits for `.ref` and
a trivializer measurement.

## 9. Questions for the user

1. **Representation:** a pattern as a *reading of a code block* (recommended),
   or a separate pattern type?
2. **Items with no pattern reading:** ε, as Push's no-op convention
   (recommended), or fail?
3. **Recursion:** `.pegSelf` in the first build, and `.pegRule k` on `.ref`
   after it is built (recommended), or no recursion at first?
4. **`true`/`false` as any/fail** collides with matching a `vecBool`'s
   elements. Either bools mean themselves on a `vecBool` only (the
   element-type rule wins), or "any" gets its own `.pegAny` and bools are
   always literals. The first is more uniform with ints.
5. **Sequencing:** build after `.ref` (step 5), as a step 6 with its
   measurements first (recommended), or sooner?
6. **Formalism** (§8b): PEG reading first, with a CFG reading and generator
   of the same blocks later (recommended); or CFG first; or both at once?
   If more than one reading is coming, the combinator instructions should be
   named for their shape (`patternChoice`) rather than `pegChoice`.
