# Behavior coverage audit

**Status: RULED 2026-11-09, nothing built.** The rulings are in §11 and supersede
the proposals where they differ. An overview of what the
language can and cannot do in a few steps, made now that every Behavior declares
its outputs (#41). It asks which Behaviors are missing or neglected, under three
constraints set by the user:

1. **No stochastic Behaviors.**
2. **Several short ways to do each low-level task**, each no more than 4–5
   instructions (Design Principles §17, "a multiplicity of paths").
3. **Abstract Behaviors over type-specific ones** where possible.

Sources:
- the declared signatures of all 607 instructions (`Interpreter.signatures`),
  read as a graph;
- short programs written for common tasks and **run**: every count of "ways"
  below was checked on the interpreter;
- every note in this folder and in PlungeGP's *Notes and Planning*;
- the enum's history across this repo, PropellerWithStructs and
  propeller-in-swift.


## 1. What the map shows

**The 607 instructions by class:**

| Class | Count | Of which |
|---|---|---|
| Operations | 295 | |
| Structural | 144 | 12 rules × 12 stacks |
| Context reads | 127 | 80 constants, 10 inputs, 37 introspection |
| Control | 28 | |
| Channel | 13 | |

**Producers and consumers per stack.** A producer can put a value on the stack;
a consumer takes or reads a value from it. Structural rules, constants and
inputs are not counted.

| Stack | Producers | Consumers |
|---|---|---|
| bool | **93** | 42 |
| int | 66 | 89 |
| code | 34 | 42 |
| string | 27 | 48 |
| iterator | 27 | 16 |
| double | 22 | 32 |
| each vector type | 20 | 30–34 |
| char | **7** | 20 |

**Which stacks feed which** (value-producing instructions only):

```
in\out     bool  int double char string vBool vInt vDbl vStr code iter
bool        17    3    1     .     1      6    .    .    .    1   13
int          8   12    2     2     8      6   11    6    6   13   18
double       7    3   13     1     1      .    .    6    .    1    .
char         9    3    1     .     6      .    .    .    .    1    .
string       9    6    1     4    18      .    .    .    6    1    3
vecBool      8    5    .     .     .     16    .    .    .    .    1
vecInt       8    9    .     .     .      .   16    .    .    .    1
vecDouble    8    5    4     .     .      .    .   16    .    .    1
vecString    8    5    .     .     4      .    .    .   16    .    1
code         3    5    .     .     .      .    .    .    .   19   17
iterator     2    4    1     1     1      2    2    2    2   11   12
```

What the matrix shows:

- **Each vector type is an island.** It talks to its own scalar type, to `.int`
  for indices and to `.bool` for queries, and to nothing else.
  - There is no conversion from one vector type to another.
  - There is no conversion from a vector to code or from code to a vector.
    There is no `vecXQuote`, although every scalar type has a `Quote`. Vectors
    are the one data type that cannot become code, against the homoiconicity
    principle.
  - The only `vecString` → `string` instructions are element reads. In the
    other direction, `string` → `vecString` exists only as delivery onto
    `.string`: there is no split into a vector and no join.
- **Every vector reduction goes through `vecXIterate`.** No instruction takes a
  vector and returns a sum, mean, maximum or minimum. Nothing sorts, filters,
  removes duplicates, zips or finds an argmax.
- **`.char` is starved.** It has 7 producers and no case operations. There is
  no vector of chars, and nothing builds a string from chars ("`stringFromItems`
  / `FromStack`" was proposed in *Vector and Collection Coverage* and silently
  dropped).
- **`.double` is thin.** It has sin, cos and tan, but no abs, negate, sqrt,
  exp, log, pow, floor or round. `.int` has no abs, negate or sign either.
  SRBench and much of PSB1 and PSB2 assume these.
- **`.bool` is over-supplied.** It has 93 producers:
  - all 16 two-argument boolean functions;
  - 39 comparisons;
  - 12 `StackIsEmpty` and 5 `ItemIsEmpty`.

  None of the proposals below adds to them.
- **The iterator is hard to reach.** All 13 of its constructors are `.cruxOnly`
  and take 5–7 arguments. A program meets an iterator almost only through
  `vecXIterate`, `stringIterate` and the delivery loops.

**History.** 725 names have ever been enum cases, and 118 of them are gone.
Nearly all of those were renamed, such as `float` to `double`. Only three were
deleted with no successor:

- `execEq` (2026-11-07, its crux was a provenance lie);
- `intDivide` (May 2026, in propeller-in-swift);
- `codeSwapPoints` (2026-06-19, no reason given).

A Clojush-style code set in a May stash was never adopted: `codeMap`,
`codeReduce`, `codeFirst`/`Rest`/`Last`/`Drop`, `codeCons`, `codeIsAtom`,
`codeSubstitute`, `codeExtract`, `codePosition`. No name, tag, dictionary or
`.ref` stack has ever existed.


## 2. How many ways each task has today

Each way below was run. "Steps" counts instructions only; the data are inputs,
and a constant counts as a step.

| Task | Ways ≤ 5 | The ways |
|---|---|---|
| nth char of a string | 4 | `stringNth`; `i .intInc .stringTake .stringLast`; `stringCut .stringPop .stringFirst`; `i 1 .stringSubstring .stringFirst` |
| last char | 3 | `stringLast`; `stringReverse .stringFirst`; length − 1, then `stringNth` |
| palindrome | 1 | `.stringDup .stringReverse .stringEq` |
| reverse a string | 1 | `stringReverse` (chars cannot be collected back into a string) |
| sum of a vecInt | 2 | `( .intAdd ) .vecIntIterate`; `.vecIntPushAll .intStackDepth .intDec ( .intAdd ) .execDoTimes` |
| max or min of a vector | 1 | `( .intMax ) .vecIntIterate` |
| **average of a vector** | **0** | 7 instructions at best: dup, iterate, length, convert, divide |
| map f over a vector | 1, fragile | `( f ) .vecIntIterate .vecIntReadStack`: right only if `.int` was empty |
| convert between vector types | 1, fragile | the map idiom with `doubleFromInt` |
| range 0…n as a vector | 2, fragile | `( ) .execDoCount .vecIntReadStack`, `.execDoRange` likewise |
| split into words | 1, fragile | `.stringSplit .vecStringReadStack` |
| join words | 1, no separator | `"" v ( .stringConcat ) .vecStringIterate` |
| **filter, sort, dedupe, zip, argmax, dot product** | **0** | |
| **case change; substring index; trim; starts with** | **0** | |
| absolute value | 0 | `.intDup 0 .intSwap .intSubtract .intMax`: 5 counting the constant, so at the limit |
| parity | 2 | `2 .intMod .boolFromInt`; `2 .intMod 0 .intEq` |
| **a dictionary or a variable** | **0** | |

Every "fragile" route collects with `ReadStack`, which reads the *whole* stack.
That route works only on a stack the program has kept clean, which is rare in
evolved code.


## 3. Defects found on the way

- **`stringDrop` drops from the end; `vecXDrop` drops from the front.**
  - `"hello" 1 .stringDrop` gives `"hell"`, but `[5,6,7] 1 .vecIntDrop` gives
    `[6,7]`.
  - Both `Take`s keep the front, so `stringTake` and `stringDrop` do not split a
    string the way their vector counterparts split a vector.
  - Ruling needed: make `stringDrop` drop from the front.
- **`vecFromIterator` ignores an iterator's body.** Given an iterator with a
  body, it still collects the original elements, not what the body produced.
  So the one collector cannot map. That matches its documentation ("keep what
  it emitted"), but it closes off the natural second way to map.
- **Ruled but not built:**
  - `codeDoIf` (I1);
  - non-destructive member reads for `vecXNth`, `stringNth`, `xMax` and `xMin`
    (I7);
  - map and reduce (#2, design approved).
- ***Open directions* is stale on one point.** It lists head/tail equivalence
  as "status unknown". It is done: First, Last, Rest, ButLast, Take, Drop and
  Cut exist for strings and for all four vector types.


## 4. Proposals

Each new Behavior is meant to be written once and applied to every type it
fits, as `Vector Behaviors.swift` already does with its factories. Where the
output type can follow the data, it does:

- `vecFromIterator` already reads its type off what came out ("uniform or
  refuse");
- a value stored as code and pushed to `.exec` lands on its own stack.

Those two devices let one instruction serve every type, which is "abstract" in
the sense this language allows.

Under each item, **Adds** names the tasks it gives a new short route.

### P1. Collection reductions and orderings: queries, one factory

- **`Sum`, `Mean` (→ `.double`), `Max`, `Min`** on `vecInt` and `vecDouble`.
- **`Max` and `Min`** also on `vecString` and `string` (by ordering).
- **`Sort`** (ascending; `Reverse` gives descending) on every vector type and
  `string`. `Distinct` moved to P1b, with the other set operations.

Each is a query: it reads, does not take, and leaves its argument (Design
Principles §5, I7). About 17 instructions.

**Adds:**
- average: 1 step (`vecIntMean`), or 3 steps (`.vecIntSum .vecIntLength
  .intQuot`, possible because both are queries);
- second and third routes to sum, max and min;
- the first routes to sort and dedupe;
- a median: `Sort`, then `Nth` of `Length` halved.

### P1b. Set operations on every collection (added 2026-11-09)

Treat a set as **operations on existing collections**, not yet as a type. §7
weighs the type.

- The family: **`Distinct`, `Intersect`, `Difference`, `IsSubset`**, on the four
  vector types, `string` and `code`, from one factory. About 24 instructions.
- **Order is the first argument's**, and so is each element's provenance:
  - `Distinct` keeps first occurrences;
  - `[3,1,3,2] [2,3] .vecIntIntersect` gives `[3,2]`.
- On `code`, the members are the root items, compared by value (§9). It is the
  one multitype collection already in the language.
- **No `Union`.** `Concat` then `Distinct` is a 2-step route already, which is
  the multiplicity §17 asks for.

**Adds:**
- **Dedupe:** `Distinct`, alongside `Sort`.
- **Filtering by membership, the most common filter in benchmarks, in 1 step:**
  - remove the vowels: `"hello" "aeiou" .stringDifference` gives `"hll"`
    (today that is five `stringRemoveChar`);
  - keep the allowed words: `.vecStringIntersect`.
- **Several routes to a membership test:** `Contains`, `IndexOf`,
  `Occurrences`, and now `IsSubset` against a one-element collection.
- **Distinct count, all-unique and overlap:**
  - distinct count: `.Distinct .Length`;
  - "all unique?": `Distinct`, `Length`, compare with the original length;
  - the overlap sizes behind Jaccard: `Intersect .Length` over `Concat .Distinct
    .Length`. That is 6–8 steps, so it fits only as two short pieces.

**What sets do not replace:** P2's filter by predicate ("keep the even
numbers"). Membership is one kind of filter; a predicate is the general kind.
Sets are a second route to some filters, not a substitute.

### P2. Map, filter and reduce (#2, as designed, plus filter)

- Build the approved design: one Behavior, no iterator; the function is a
  `CodeItem` with `.inputN` holes, rebound for each element.
- Add **filter** under I4's ruling: a function that leaves no result counts as
  false.
- One factory per form across the four vector types and `string`, so about 15
  instructions.
- **Result type: "uniform or refuse", like `vecFromIterator`**, rather than the
  argument's own type. Then `( .doubleFromInt ) .vecIntMap` returns a
  `vecDouble`, and **one map closes the whole vector-conversion grid** that the
  matrix shows empty. *Map and reduce* deferred this "polymorphic map"; it is
  the cheapest way to fill the grid.

**Adds:**
- a robust map, filter and reduce in 1–2 steps;
- vector conversion;
- dot product (zip aside): map and sum.

### P3. Short iterator constructors

- One-argument **`iteratorOverX`** for each collection type (`string` letters,
  four vectors, code points): walk everything, stride 1, no body.
- About 6 instructions, **not** `.cruxOnly`.
- They make the iterator's getters, `iteratorPlayDelayed` and `vecFromIterator`
  reachable within 2–3 steps.
- Pair them with a decision on `vecFromIterator`: **when the iterator has a
  body, collect the body's results.** That is the second, independent route to
  map, through the iterator rather than the sub-interpreter.

### P4. Code-and-data conversions (homoiconicity)

- **`vecXQuote`** (4), so a vector can become code like every other data type.
- **One `vecFromCode`** (generic): the vector's type is read off the block's
  contents, uniform or refuse, as in `vecFromIterator`.
- **`stringFromChars`** (read a fixed number of chars into a string, like
  `vecXReadItems`) and **`stringReadStack`**. These are the dropped
  `stringFromItems`/`FromStack`, and with them chars can be collected again.
- **`stringSplitOn`** (separator → `vecString`, #30) and **`vecStringJoin`**
  (separator).

About 9 instructions.

**Adds:**
- a second way to reverse a string, through chars: deliver them, then read them
  back with `stringReadStack` (the order to be checked when built);
- a robust split and a join, which Spin Words needs and has to rebuild today;
- vectors as code: pieces of a vector can be cut, wrapped and spliced by the
  code instructions and turned back into a vector.

### P5. Numbers: one numeric factory over int and double

| Instruction | int | double | Note |
|---|---|---|---|
| `Abs`, `Negate`, `Sign` | ✓ | ✓ | |
| `Pow` | ✓ | ✓ | `.fallible` past the size limit |
| `Sqrt`, `Exp`, `Log` | | ✓ | `.fallible` outside the domain |
| `Floor`, `Ceil`, `Round` | | ✓ | `intFromDouble` only truncates |

About 16 instructions.

**Adds:** a 1-step abs and negate beside the existing 3–5-step routes, and the
symbolic-regression basics.

### P6. Strings and chars

- `charUpper`, `charLower`, `charIsUpper`, `charIsLower`;
- `stringUpper`, `stringLower`;
- `stringIndexOf` (a substring; today only a char can be searched);
- `stringStartsWith`, `stringEndsWith`;
- `stringTrim`.

About 10 instructions. They add the first routes to case change and substring
search. Through `stringFromChars` from P4, they also add a second route to case
change: map `charUpper` over the letters.

### P7. A dictionary

Two designs:

1. **A new `.dict` stack:**
   - **String keys.** Any value becomes a key in 1 step through `stringFromX`.
   - **Code values.** `dictGet` pushes the stored item onto `.exec`, which
     routes it to its own stack, as the constants already do (a `.deferred`
     output).
   - **So one `Get` and one `Set` serve every type.** To store an int, write
     `.intQuote k .dictSet`.
   - Instructions: `dictNew`, `Set`, `Get` (an error when the key is absent,
     I11), `Has`, `Remove`, `Keys` (→ `vecString`), `Size`, an iterator over the
     pairs, and `dictIncrement` for counting: get-or-0, add 1, set.
   - Cost: about 9 operations, 12 structural rules and an `Eq`. A new type
     costs about 28 edits in 20 files, four of which fail silently (#37), so the
     type registry (`@PushItem`, A4) would come first.
   - Adds the first route to word frequency and other histograms (split, then
     iterate `dictIncrement`), to lookup tables, and to memoization.
2. **An association list in `.code`:**
   - Shaped `( ( "k" v ) ( "k2" v2 ) )`, with `codeAssocGet` and
     `codeAssocSet`.
   - No new stack, and it fits §7b's "`CodeItem` is the vector-of-anything".
   - Linear lookup, and a dictionary could then be mangled by any `code`
     instruction.

~~**Recommendation: (1).** It is the bigger addition to reach. It also provides
the variables below for almost nothing.~~ **Superseded by §8:** a dictionary
stack starves on three counts at once. Lookup by pattern on the stacks that
already exist does the dictionary's job and starves on one.

**Hashing is fine; only a hash-derived order must not leak** (the user's
clarification, 2026-11-09).
- Hashed keys and sets are not stochastic as long as the hashes stay internal
  and their order is never shown.
- Swift seeds `Hasher` afresh in every process, so a hash's *iteration* order
  varies between runs. Anything that lists contents must not use it: `Keys`, a
  printout, a crux, an iterator over the entries.
- The remedy is **LIFO order, as in a stack**: entries listed newest first, with
  the hash used only for lookup. This is the language's own convention, and it
  matches §8's "topmost match", where a stack already behaves as an
  insertion-ordered store.
- Sorted order would remain an option, but only where a canonical spelling is
  wanted.

The same applies to any set type (§7).

### P8. Local variables (#39), on top of the dictionary

**Superseded by §9**, the `.ref` stack of keyed bindings. What follows is the
first version, kept for the record.

- As the user observed, variables add flexibility of algorithm more than reach
  in the graph.
- The cheapest form is **one dictionary the interpreter owns**, plus ten tokens
  `var0…var9`:
  - each token reads its binding the way `inputN` does (a `.binding` output, so
    the binding goes to `.exec` and lands on its type's stack);
  - **`codeBindVar`** (an int index and a code value) writes the binding.
- That answers #39's storage question with the dictionary's mechanism.
- A read hands back the bound item with its own history, so no stand-in is
  needed (#39).
- It also gives cruxes a name for a shared node instead of `Dup`/`YankDup`
  bookkeeping.
- About 11 instructions.

### P9. Small items

- **`codeDoIf`** (ruled, I1).
- **Non-destructive `Nth`/`First`/`Last`** (ruled, I7). The reductions in P1 can
  follow the same convention from the start.
- **Fix `stringDrop`** (§3).
- **Optional: a zip.** A pairwise `vecXZipWith (code)` (4) for dot products and
  elementwise arithmetic. P2's map with two-input functions could cover this
  later.


## 5. On collapsing int and double into one scalar type

**Not recommended.** A note on the user's idea, which no earlier note recorded:

- **`.int` is the language's argument channel.** It carries every count, index
  and depth: 84 combinators draw on it (*Stack economics* §3). Folded together
  with doubles, every claim would need rounding, and every arithmetic result
  would land in the place indices are read from. Indices would be perturbed
  constantly.
- **The imbalance worry is mostly about drawing, and drawing is already by
  role.** `RandomCode` picks a role by weight, then an instruction uniformly
  within it (`InstructionMix`), so the size of a pile on one stack does not by
  itself skew random code. A collapse would therefore not fix imbalance, nor
  would it make it much worse; the cost lies elsewhere.
- **What a collapse would fix is the doubled definitions, and P5 fixes those in
  the source.** One numeric factory over a protocol, as the vector factory
  already is, gives a single definition and keeps two stacks. Moving a value
  between the two takes one step (`doubleFromInt`, `intFromDouble`), and P5's
  `Round` makes the double-to-int direction honest.


## 6. What this adds, and in what order

| Proposal | New instructions | Depends on |
|---|---|---|
| P9 (fixes and ruled items) | ≈ 8 | — |
| P1 | ≈ 17 | — |
| P1b (set operations) | ≈ 24 | — |
| P5 | ≈ 16 | — |
| P6 | ≈ 10 | — |
| P4 | ≈ 9 | — |
| P3 | ≈ 6 | a ruling on `vecFromIterator` |
| P2 | ≈ 15 | #2's design |
| ~~P7 + P8~~ | ~~≈ 35~~ | ~~the type registry (A4 / #37)~~ |
| P7′ (pattern lookup, §8) | ≈ 43 | — |
| ~~P8 (variables as writable inputs)~~ | ~~≈ 11~~ | |
| P8′ (`.ref` stack, §9–§10) | ≈ 48 | one new stack, so the type registry helps |

In all, about 195, taking 607 to about 800. Only `.ref` is a new stack.

**With P1–P6 and P9, every task in §2 has at least two routes within 5 steps.**
Dedupe has two:
- `Distinct`;
- `Sort` with `Distinct`.

Filters have two routes as well:
- P2's predicate;
- P1b's membership, where the filter is "in these" or "not in these".
For example, average:
- `vecIntMean`;
- `.vecIntSum .vecIntLength .intQuot`;
- `( .doubleFromInt ) .vecIntMap .vecDoubleMean`;
- `( .intAdd ) .vecIntReduce` and divide.

Word frequency and variables wait for P7.

**Open questions for the user** (all answered 2026-11-09; see §11):
1. Should `stringDrop` drop from the front?
2. Should `vecFromIterator` collect a body's results when there is a body?
3. Should map's result type follow the data (uniform or refuse)?
4. A dictionary stack, or association lists in `.code`?
5. Are the new reductions queries (I7) from the start?
6. Set operations on collections now, and a set type only with the dictionary
   (§7)?
7. Pattern lookup (§8) instead of a dictionary type: read the probe, copy the
   match, refuse on a miss? Measure the match rates first?
8. For `.ref` (§9):
   - Does a dereferenced code block **run** (Push3's way, which gives named
     subroutines), or is it delivered to `.code`?
   - Is a miss an error of its own kind, or nothing?
   - Is `execLet` wanted from the start?
9. Keys as ints from an interpreter-owned counter (§10): `refNew` deposits each
   fresh key on `.int`, names are keys 0…9, and the counter starts at 10?


## 7. Sets: operations, or a type? (2026-11-09)

The user asked whether a `set` type would serve dedupe, filtering and search
better than P1b. Three designs:

**(a) Typed sets** (`setInt`, `setString`, `setChar`, …), mirroring the
vectors:
- **Rejected.** Each is a new stack, so 12 structural rules, constants, a
  `Quote` and an `Eq`, plus conversions to and from its vector.
- That is about 40 instructions per type, mostly furniture. Across the five
  candidate element types it is about 200, the largest pile in the language.
- They would add almost no reach that P1b does not already give the vector of
  the same type.

**(b) One multitype set, like `code`:**
- Members of any type, compared by value (§9). `1` and `1.0` are different
  members, and so are `'a'` and `"a"`.
- Hashed internally and listed in LIFO order, as P7 says. Equality ignores
  order, since two sets with the same members are equal however they were
  built.
- The cost is one stack: 12 structural rules, `Eq`, `Quote`, `setEmpty`, and
  about 12 operations. About 30 in all.

What it adds beyond P1b:

1. **Equality regardless of order and repetition.** Two sets are equal when they
   have the same members, so "same letters?" is a direct comparison. With P1b
   it is `Sort` and `Distinct` on both sides first, about 5 steps.
2. **A conversion out that filters by type.** `vecIntFromSet` would keep only
   the int members, and a `string` built from the set only its chars. P4's
   `vecFromCode` refuses a mixed block instead. That is a second route to a
   filter, by type, which only a multitype container offers. It could equally
   be a second mode of `vecFromCode` (`vecIntFromCodeFiltering`), so it does not
   by itself justify the type.
3. **An accumulator for searches.** A "seen" set inside a loop serves "first
   repeated element", cycle detection and graph visiting. A vector plus
   `Contains`, or `Conj` then `Distinct`, does the same at linear cost. Size
   limits keep collections small, so speed is not the argument; what remains is
   one honest instruction (`setAdd`) against two.
4. **A home for a dictionary's keys.** `dictKeys` → set is natural. Without a
   set type, `dictKeys` → `vecString`, newest first, works as well.

There is a cost at membership. A multitype `setHas` must receive its probe from
some stack. Either it takes the probe as code (`5 .intQuote .setHas`, one step
more), or it needs one per type (`intIsIn`, `stringIsIn`, …), which is the
type-specific pile constraint 3 argues against. The quoted probe follows the
same pattern as `dictSet` in P7.

**(c) Sets as operations only:** P1b, which needs no new stack and costs about
24 instructions over six collections.

**Recommendation: (c) now; (b) only together with the dictionary, if at all.**
- What (b) adds is real but small: canonical equality, filtering by type, and
  one-step accumulation.
- Each of these has a 2–5-step route through P1b and P4, so it would be a
  further way to do things, not the first.
- The dictionary is the one structure that cannot be had through operations on
  existing collections. It needs the type registry anyway, and sets are the
  dictionary with no values. If (b) is built, it should be built alongside the
  dictionary, sharing its ordered storage and its quoted-probe convention, so
  the two cost one design between them.

**The overview changes as follows:**
- P1 loses `Distinct` to P1b.
- P2 still needs filter by predicate.
- P7 gains the fixed-order requirement.
- The totals rise by about 20.
- Nothing in §5 changes.


## 8. Key starvation, and lookup by pattern on every stack (2026-11-09)

The user's concern: a dictionary's keys starve, whatever type they are. The
user's alternative: a pattern-matching search, top-down, on every stack,
extending the sieve's "find the top matrix item which matches as an argument".
Pop an item, make it into a pattern, and find the topmost item on the same stack
that matches it.

### Why a dictionary stack starves

`dictGet` succeeds only when three things hold at once:

1. **A dictionary is on `.dict`.** Only `dictNew` and a chain of `dictSet`s put
   one there. That is the profile of `.iterator`, whose instructions starve
   about 100% of the time outside a loop (*Stack economics* §8). A `.dict`
   would be empty almost every time a random program reached for it.
2. **A key is on its stack.** `.string` is contested by everything that handles
   text. An int key would draw on `.int`, the language's argument channel and
   its most-taxed stack (§3).
3. **The key is in the dictionary.** This is the failure the user is pointing
   at, and the worst of the three, because **more supply does not cure it**.
   - A random string is almost never a stored key.
   - A hit happens only when keys and probes come from the same source, as in a
     histogram of words split from one text. Then the key was already in hand,
     and the dictionary only counts.
   - `dictSet` adds a fourth requirement, a value, and its three arguments sit
     on three stacks: the conjunction that makes the iterator constructors
     unfireable (*Stack economics* §7).

The third failure can be mitigated inside the design by making lookup
**total**: return the entry with the greatest key not above the probe, clamped
to the first. That is a sorted map's floor lookup (by key order, whatever the storage order), and it is "Claims may be
clamped" (§12) applied to keys. It keeps order, it is deterministic, and it
never misses on a non-empty dictionary. The first failure remains.

### Pattern lookup: the stacks are already the store

Every stack is a collection that a program keeps full by running. A lookup that
searches a stack for an item resembling a probe needs no new stack, so
requirement 1 disappears. Patterns coarser than equality also make requirement 3
mostly disappear: a probe nearly always finds *something*.

**The rule, for a stack X and a pattern kind K:**

- **Read the probe** from the top of X. Read it, do not take it, so a key is
  never used up. Repeated lookups with one key are what a dictionary is for, and
  a consumed key would starve exactly the use the user worries about.
- Search X **below the probe**, top-down, for the first item that matches the
  probe under K.
- **Copy the match to the top**, leaving it in place: the store survives a
  lookup.
- **No match: a refusal.** Nothing changes and nothing is consumed, as with an
  empty stack.

This is the **sieve made visible to a program**, which answers *Sieve
arguments* question 5 with "yes, as instructions". It belongs to the
**structural** class:
- it rearranges within one stack and makes nothing new;
- the copy keeps the matched item's own crux, so the copy records nothing (law
  1);
- the record names the item and not the position (*Sieve* §1), so it is not
  contingent;
- the composition invariant holds, because the probe is a read.

Cost: one search, bounded by `maxStackDepth` and by each item's size limits, and
one item produced (§4).

### The pattern kinds

The search is useful only when **the match is not the probe**. A copy of an item
equal to the probe is just a `Dup`. So equality serves only as a *question*
about the stack, not as a lookup.

| Kind | Matches a candidate that… | Stacks | Never misses? |
|---|---|---|---|
| **Prefix** | begins with the probe's contents | string, 4 vectors, code | no, but a 1-element probe matches often |
| **Containing** | contains the probe | string, 4 vectors, code | no |
| **Nearest** | is closest to the probe in the type's order (ties to the topmost) | int, double, char, string, vecInt, vecDouble, vecString | **yes**, given one other item |
| **Shape** | has the probe's tree with the same type at each leaf (`cruxShape`'s idea: atoms are parameters) | code | no |
| **Kind** | emits what the probe emits | iterator | no (the sieve's original motivation) |
| **Equal**, as a query | is equal to the probe → `xStackIndexOf` (depth onto `.int`, or a refusal) and `xStackContains` (→ `.bool`) | every data stack | (a question, not a lookup) |

The kinds run from **exact to total** in how selective they are. Evolution can
use a selective pattern when the data allow, and fall back on a total one when
they do not. The diversity of patterns the user asks for is this spread of
selectivity, more than a spread of types.

### Two additions from the user (2026-11-09)

- **The same kinds apply inside a collection**, not only on a stack:
  - nearest within a vector (`[3, 9, 14] 10` → `9`);
  - the first word of a `vecString` that has a prefix or contains a substring;
  - the first sub-block of a code block whose head matches.

  Each lookup then has two homes, the stack and the collection.
- **Every lookup returns both the item and its position** (the user's
  refinement of two separate forms). A copy of the item lands on its own stack;
  the depth on a stack, or the index in a collection, goes onto `.int`. The
  declaration reads `.results([X, .int])`.
  - **One instruction per kind and home**, not two.
  - The position subsumes `xStackIndexOf` and hands the index to `Nth`, `Yank`
    or `Set`, so "find, then act there" is two steps.
  - The index is the extra int that `.int` is short of (§10's argument). A
    program that wanted only the item leaves an int for the next consumer.
  - **When both land on `.int`** (a lookup among ints), the item goes on top
    and its index just beneath; `.intSwap` reaches the index.
  - **A depth is counted after the copy is pushed**, so it is the depth that
    `xYank` or `xYankDup` would need afterwards to reach the original.
  - **Provenance differs between the two homes:**
    - An index in a collection depends only on the collection and the probe,
      so it replays (each result recording its selecting crux, law 5).
    - A depth on a stack depends on the stack's arrangement, so it records a
      stand-in, as `StackDepth` does (law 4b).

### Three dictionaries, none of them a type

1. **Association blocks on `.code`, looked up by prefix.**
   - An entry is a block `( key value )`: `k .stringQuote v .intQuote
     .codePair`, by the singleton-unwrap convention.
   - A lookup is `k .stringQuote .codeLookupPrefix`, then `1 .codeEmitNthRoot`
     to send the value to its own stack. That is 4 steps.
   - **One `codeLookupPrefix` serves keys and values of every type**, because
     anything quotes into code. It is the abstract dictionary constraint 3 asks
     for, in one instruction.
2. **Parallel stacks aligned by depth.** Keys on one stack, values on another:
   `k .stringStackIndexOf .intYankDup` reads the int at the key's depth, in 2
   steps.
   - Fragile, because any push to either stack shifts the alignment. That is
     tolerable for a route that is one of several, and it is the kind of
     stack-native trick Push programs evolve.
3. **Nearest lookup as a total table.** Store sorted pairs, or rely on order:
   `x .intLookupNearest` finds the closest stored int. Rounding to a grid,
   snapping to the nearest allowed value and piecewise tables all come from
   this, and it cannot miss.

The dictionary *type* would be a fourth route, the costliest, and the most
starved.

### Effects on the rest of the overview

- **P7 is replaced by P7′ (pattern lookup):**

  | Family | Instructions |
  |---|---|
  | `Prefix` | 6 |
  | `Containing` | 6 |
  | `Nearest` | 7 |
  | `codeLookupShape` | 1 |
  | `iteratorLookupKind` | 1 |
  | `xStackIndexOf` | 11 |
  | `xStackContains` | 11 |

  About 43 in all, made by one factory per kind, as the structural rules are.
  It needs **no type registry**, so it can come before A4. A planner
  requirement kind `.finds(stack, pattern)` could be added at the same time,
  ready for the matrices.
- **The dictionary type is deferred** until the lookups have been measured with
  the starvation probe. If it is ever built, give it the total floor lookup.
- **P1b gains a stack-level membership test.** `xStackContains` asks "is this
  among the items I have?", where `Contains` asks about the items inside one
  collection.
- **P8 (variables) is unchanged in purpose but loses its free ride.** A named
  association block on `.code` can act as a variable (`( "x" 5 )`, looked up by
  prefix). It is not private, though: any `code` instruction can move or eat
  it. A real environment, writable inputs `var0…var9`, is still about 11
  instructions with its own small storage, and no longer waits for a dictionary
  type.
- **Roadmap #34 (patterns as first-class items)** starts here. The kind is
  carried in the instruction's name rather than in a pattern item. A pattern
  stack would itself be an always-empty stack that starves, which is the
  problem being solved. A first-class pattern can come later, if the kinds turn
  out to want combining.

### To measure before building

Run the existing starvation probe (*Stack economics* Part 2) on random programs
and compare three rates:
- how often a lookup of each kind finds a match;
- how often `.dict` would be non-empty;
- how often a key would hit.

The argument above predicts the order: nearest, prefix, containing, then
equality, with the dictionary type last. Checking that is about a day's work.
Debating it costs more.


## 9. A `.ref` stack: keyed bindings, each variable a stack (2026-11-09)

*Revised by the rulings in §11: the named tokens, the binding from `.exec`
and `execLet` are dropped.*

The user's design:
- A **`.ref` stack whose items are the pairs of §8**, `( key value )`, kept on
  a stack of their own.
- A lookup **sieves** `.ref` for the topmost pair whose key matches. With the
  ability to dereference the key from a matched right-hand side, this gives
  explicitly keyed variable bindings.
- Older pairs with the same key stay below. They are recovered over time as the
  newer pairs are popped, **so each variable's storage becomes a stack in
  itself.**

It supersedes P8. It also answers #39's open question ("how the interpreter
stores the bindings"): **on a stack, like everything else.**

### What it is

**An item.** A `RefItem` is a pair: a key and a value, each any item, compared
by value (§9 of Design Principles).
- It has a stack of its own, so the `code` instructions cannot cut, splice or
  eat a binding. That was §8's objection to association blocks living on
  `.code`.
- It quotes to the block `( key value )` and is made from one, so it stays
  homoiconic.

**Shadowing, for free, from LIFO.**
- Binding a key that is already bound pushes a new pair *above* the old one. A
  lookup finds the new one; the old one waits underneath.
- Removing the newest binding of a key brings the previous one back.
- That is dynamic scoping, which Lisp's special variables and Forth's
  dictionary both have. It costs no machinery beyond the sieve.

**The order is the stack's.** No hash order is ever exposed (the user's
clarification in P7). A hash index could sit beside the stack to speed lookups,
without changing any result.

### The operations

| Operation | What it does | Argument | Notes |
|---|---|---|---|
| **bind** | push a new pair (shadowing any older binding of the key) | a key and a value | |
| **deref** | the value of the topmost pair whose key matches → `.exec`, where it lands on its own stack; the pair stays | a key | |
| **reverse deref** | the key of the topmost pair whose **value** matches → `.exec` | a value | "which variable holds 5?" With §8's nearest kind: "which index holds the value closest to x?", an argmax-like search for free |
| **unbind** | remove the topmost pair with the key, bringing back the one beneath | a key | |
| **binding depth** | how many bindings the key has: its own stack's depth → `.int` | a key | |
| `refPop`, `refSwap`, … | positional, as on any stack | | `refPop` drops the newest binding of *any* variable: the user's "recovered over time by popping" |
| `refQuote`, `refFromCode`, `refEq` | homoiconicity and equality | | |

Shadowing then has several short routes:
- `unbind`, by key;
- `refPop`, by position;
- `refYank` and `refShove`, which reorder bindings.

### Key starvation, again

The three conditions of §8, for `.ref`:

1. **A store exists.** `.ref` holds one item per binding, and a lookup does not
   consume the pair. So the stack fills after the first bind and stays filled.
   That is the opposite of `.iterator`, whose items are consumed by the loop
   that made them.
2. **A key is in hand.** This is the decisive part. **Put the key in the
   instruction's name, as `input0…input9` already do.** Ten tokens `ref0…ref9`
   each dereference the binding of their own name.
   - They take **no arguments at all**, so they cannot starve for a key.
   - The name's key is a fixed item. A general lookup with that item as its
     probe reaches the same binding, so the named and the general routes agree.
3. **The key is bound.** With ten names instead of arbitrary strings, a miss
   happens only if that name has never been bound. After *n* random binds, a
   given name is bound with probability 1 − 0.9ⁿ: two-thirds after 10 binds.

**Binding without starving** comes from the source Push3 used for
`EXEC.DEFINE`: the next item on `.exec`.
- `.exec` never starves (*Stack economics* §9): it is not empty while a program
  runs.
- `bind3 5` binds name 3 to `5`, and `bind3 ( … )` binds it to a block.
- A computed value needs a second route, taking it from `.code`:
  `x .intQuote .codeBind3`.

So a named variable costs nothing to read and one argument, which `.exec`
always supplies, to write. General keys remain available for programs that
build them: **any item quoted is a key**, through `refBind`, `refDeref`,
`refUnbind` and their pattern variants, which take the key from `.code`.

### What dereferencing a block does

Push3 pushed a bound value onto `.exec`, so **a bound block runs when its name
is executed**. That makes bindings **named subroutines**:
- `bind3 ( .intDup .intMultiply )`, then `.ref3`, squares whatever is on `.int`.
- A block that mentions `.ref3` calls itself. That is recursion, and it ends at
  the step limit unless it is guarded. These tokens therefore belong with the
  runaway guard's re-entrant set, as `execY` does.

The alternative is to deliver the block to `.code` as data, safe and inert. Both
routes have uses. The note's suggestion, since "code is data until a program
asks to run it" (§7):
- **the named tokens run** (the program asked, by naming it);
- **a general `refDerefToCode` delivers.**

### Scope as a combinator

With shadowing in place, a `let` is one control instruction:
- **`execLet`**: bind, run the next block, then unbind. The binding is visible
  only inside the block, and the outer binding returns after it.
- That is lexical-looking scope from dynamic machinery.
- Without it, the same thing takes 3 steps: `bind3 x ( … ) unbind3`. So `let`
  is one more route, not the only one.

### Provenance

- **A dereferenced value keeps its own crux.** The binding is transparent, a
  copy that records nothing (law 1). Nothing has to stand in for the value
  (#39), and the crux reads as the computation that made the value, not as "the
  value of variable 3".
- The *pair* has a crux like any built item: its key's crux, its value's crux,
  and `refBind`.
- This is also what a crux needs to **name a shared node**. A value used three
  times appears three times in the crux, each copy carrying the same history,
  instead of being threaded through `Dup` and `YankDup`. (Compressing the
  repetition is #36's business, not this one's.)

### How this relates to §8

`.ref` is pattern lookup specialized to pairs, so §8's kinds apply on either
side of the pair:
- **exact on the key**: variables;
- **nearest on the key**: a total table, which never misses;
- **prefix on the key**: namespaces, e.g. every key beginning `"pt."`;
- **any kind on the value**: reverse lookup.

One factory over (kind × side) builds them.

The other routes stay, because the constraints ask for several:
- association blocks on `.code`;
- parallel stacks aligned by depth;
- the nearest lookup on scalar stacks.

### Size

| Group | Instructions |
|---|---|
| Structural rules for `.ref` | 12 |
| `refQuote`, `refFromCode`, `refEq` | 3 |
| `ref0…ref9` (deref) | 10 |
| `bind0…bind9` (from `.exec`) | 10 |
| General `refBind`, `refDeref`, `refDerefToCode`, `refUnbind`, `refBindingDepth`, reverse deref, two pattern variants | about 8 |
| `execLet` | 1 |
| **Total** | **about 45** |

The `codeBindN` family from `.code` would add 10 more. It could be left out,
since `refBind` covers it in one more step.

It is a new stack, so it pays the type-adding cost (#37), and building the type
registry first would make that cheaper. **It is the one new stack this audit
recommends**, because it is the one structure the existing stacks cannot provide
privately.


## 10. Where keys come from, and what to make extras of (2026-11-09)

*Int keys and the owned counter stand. The operations table is revised by
§11.*

The user's point:
- Hand-written programs use strings as keys. Evolved programs need a
  **deterministic generator** that hands out a fresh key on demand.
- The generator should be a standard run-time structure owned by the
  interpreter.
- The real decision is **what type to produce extras of**: something that is
  starving and flexible, so that evolution can put the keys to other uses as
  well.

### Which type: the supply table answers it

From *Stack economics* (the deepen/shallow ratio across the language) and §1
above:

| Type | Supply | Consumers | As a key | Verdict |
|---|---|---|---|---|
| **int** | **drains, 0.53**: the most-demanded stack, about half empty when wanted | **159 Behaviors**, 84 of them combinators | exact, nearest, floor and range lookups; **arithmetic on keys** | **the answer** |
| code | starves, 0.29 | 42 | a key that could also be run, but a fresh one would only wrap a number, `( 10 )`; equality costs a tree walk | runner-up, for no gain over int |
| double | drains, 0.80 | 32 | nearest lookups, and **keys *between* keys** (2.5 between 2 and 3); exact equality is fragile after arithmetic | an option for ordered insertion only |
| string | drains, 0.70 | 48 | prefix and containing lookups, but generated keys share a prefix (`"k1"`, `"k2"`), so prefix matches everything | poor as generated keys |
| bool, iterator | **pile up**, 1.52 and 2.43 | | | extras would be waste |

**Ints win on every count:**

- **Starving.** Every fresh key is one more int on the stack the whole language
  draws its counts and indices from.
- **Flexible.** A key used as an index, a count or a number is a key put to
  another use, which is what the user asks for. The reverse also happens: a
  computed int that equals a key reaches the binding. Small consecutive keys
  collide with the small numbers programs compute most, so **hits are frequent**
  (§8's third condition).
- **Addressable.** `k .intInc` is the next variable. Ints make `.ref` a
  **heap**:
  - consecutive keys are an array;
  - a value holding a key is a **pointer**;
  - so linked lists, trees and graphs can be built from bindings.

  These are structures *Structured data types* lists as needing new types.
  Strings cannot be incremented, and double keys drift.

### The generator

- **A counting iterator owned by the interpreter**, not placed on `.iterator`,
  where a program could consume or reorder it. It is built from the existing
  `IteratorItem` counting kind, so nothing new is needed to step it.
- It is **reset at every load**, so a run's keys are 10, 11, 12, … every time:
  deterministic, with no hashing and no randomness.
- **This is the standard structure the user asks for.** Should any other supply
  be wanted later (fresh doubles for keys between keys, say), it is a second
  owned iterator of another kind, with one instruction to draw from it.
- **Its keys are names, not computations.** A fresh key records a **stand-in**
  (`.refFresh_actuallyWas_12`), exactly as `pushStepCount` does (law 4b).
  Recording `.refFresh` instead would replay as 10 on a fresh interpreter, not
  12, which is the lie the round-trip sweep exists to catch.

### The names are keys too

- `ref0…ref9` and `bind0…bind9` (§9) are **keys 0 through 9**.
- The counter **starts at 10**, so a fresh key never aliases a named variable by
  construction.
- Arithmetic can still reach the names on purpose, and so can computed small
  ints by accident, which counts as a feature here.
- A general lookup with the int 3 finds what `ref3` finds: two routes to one
  binding.

### Operations, revised from §9 for int keys

| Operation | Key | Value | Starves? |
|---|---|---|---|
| **`refNew`** | fresh, **left on `.int`** | the next item on `.exec` | **never**, and it gives one int back |
| **`refFresh`** | fresh, pushed to `.int` | none | never: a deterministic `gensym`, useful as a unique id or a label |
| `refBind` | taken from `.int` (rebind or shadow) | the next item on `.exec` | needs an int |
| `refBindCode` | taken from `.int` | from `.code` | needs an int and a block |
| `refDeref`, `refUnbind`, `refBindingDepth` | **read** from `.int`, left in place | | needs an int; reading does not drain it |
| `refDerefNearest`, `refDerefFloor` | read from `.int` | | **never misses** on a non-empty `.ref` |
| reverse deref | the value probe is read from its stack; the key is returned to `.int` | | |

**`refNew` is the answer to "what to make extras of", in one instruction.**
- Binding a variable deposits an int on the stack that needs ints most.
- It takes nothing from any stack, since `.exec` always has a next item.
- So a program that binds variables feeds the rest of itself.

**The cost to watch is that every fresh key lands on top of `.int`**, where the
next int-taking instruction will use it as an index or a count.
- That is the intended reuse, and any harm is bounded: keys are small, and
  counts and indices are clamped (§12).
- A key used as an index is consumed, though, and then that variable can be
  reached only by a computed int, a nearest lookup, or its position on `.ref`.
  That is three routes, which is enough.

**Size:** §9's general operations take their keys from `.int` instead of
`.code`, and gain `refNew`, `refFresh` and the floor variant. That is about 48 in
all for P8′.

**Other key types.** Keys stay *any* item (§9), and a quoted-probe variant can
add string or code keys later if a problem wants them. The generator and the
named tokens produce ints, because ints are what the language is short of.


## 11. Rulings (2026-11-09)

**General:**

1. **Drop and Take.** `stringDrop` drops from the **front**, like `vecXDrop`.
   Add **`xDropLast`** and **`xTakeLast`** for `string` and all four vector
   types, so both ends have routes.
2. **`vecFromIterator`.** Given an iterator with a body, it collects **the
   body's results**, uniform or refuse. Without a body it collects the elements,
   as now.
   *Deferred to P2 (2026-11-09):* collecting a body's results means running the
   body on each element in a sub-interpreter, which is the map design's
   machinery, with the same open rule for which stack holds the result. It is
   built with map.
   **Built 2026-11-09:** ruling 1 (`stringDrop` from the front; `xDropLast`,
   `xTakeLast`), `codeDoIf` (I1), and the `Peek` forms below.
3. **Map's result type follows the data**, uniform or refuse. This is #2's
   deferred polymorphic map; `( .doubleFromInt ) .vecIntMap` gives a
   `vecDouble`.
4. **Queries.**
   - The fact-reporting collection instructions read and leave: `Sum`, `Mean`,
     `Max`, `Min`, `IsSubset`.
   - The transforming ones consume, as other transforms do: `Sort`, `Distinct`,
     `Intersect`, `Difference`.
5. **Structures.**
   - Build **pattern lookup on the existing stacks** (§8) and the **`.ref`
     stack**.
   - Sets are **operations on collections** (P1b).
   - There is **no dictionary type and no set type**.
   - **Measure** the lookups' match rates with the starvation probe as part of
     building them.
6. **A lookup that finds no match is a refusal**, like starvation: nothing is
   consumed, and it is a missing-arguments error. This holds for every pattern
   lookup and every `.ref` lookup.

**I7, amended in building (2026-11-09).** Making `vecXNth`, `stringNth`,
`xMax` and `xMin` non-destructive would have lengthened every element's address
crux from `v 2 .vecIntNth` (3 items) to 7, since the cleanup would then be part
of every address. So, by the user's choice:
- the consuming forms stay;
- **`Peek` forms** are added: `vecXPeekNth`, `stringPeekNth`, `intPeekMax`,
  `intPeekMin`, `doublePeekMax` and `doublePeekMin`.

That makes two routes, not a change. `Peek` is the language's existing label for
a read that does not consume (the iterator getters); the user's suggestion was
Ruby's and Clojure's `Nth!`.

**The `.ref` stack** (supersedes §9's named tokens, the binding from `.exec`,
and `execLet`):

7. **Keys are ints** (§10).
   - A counter owned by the interpreter, reset at every load and never on
     `.iterator`, hands out fresh keys **starting at 10**.
   - A fresh key records a stand-in (law 4b).
8. **Keys 0–9 hold the inputs.**
   - At each load, the interpreter pushes a pair (n, the value of `inputN`)
     onto `.ref` for every bound input.
   - `.input0…9` stay as the direct path; the `.ref` lookup is a redundant,
     alternative path (the user's choice).
   - A program can shadow key 3 with its own binding, and `.input3` still gives
     the original.
9. **Permanent binders, one per type: `xRef`.**
   - Read the top item of stack X and leave it there.
   - Push the pair (fresh key, copy of the item) onto the top of `.ref`.
   - Push the fresh key onto `.int`.
   - Types: bool, int, double, char, string, code and the four vectors.
     `.iterator` is excluded, because loop state is private (Design Principles
     §10). `.exec` is excluded, because arguments do not come from `.exec`.
10. **Assignment is one generic `refRekey`.** It takes an int key k and re-keys
    the top `.ref` pair to k, shadowing k's older binding.
    - Assigning a value of any type to an existing variable is `x .intRef`
      (or `stringRef`, …), then `k .refRekey`.
    - One abstract instruction instead of one per type.
11. **Temporary binders, one per type: `xWith`** (a `with` block).
    - Read the top item of X and leave it.
    - Bind it to a fresh key, and push the key onto `.int` (the "as name").
    - Run **the body, taken from `.code`**: the convention of `execIf`,
      `execDoTimes` and the other control instructions, so that, in the user's
      words, "most exec arguments should come from `code`".
    - Then remove the binding.
    - The key is fresh, so the closing unbind cannot remove anything but its
      own binding. That retires §9's caveat about a body rebinding the same
      key, except where the body rekeys on purpose.
12. **Nothing in the `.ref` design takes an argument from `.exec`.** Dropped:
    - `ref0…ref9` and `bind0…bind9` (the inputs fill keys 0–9 instead);
    - `refNew` and `codeBindN`;
    - `execLet` (replaced by `xWith`).
13. **Two lookup paths:**
    - **`refDeref`** reads a key from `.int` (leaving it) and sends the value
      to `.exec`, where it lands on its own stack, so a block **runs**. It is
      tagged re-entrant for the runaway guard, because a bound block can look
      itself up.
    - **`refDerefToCode`** delivers the value to `.code` as data.
    - Alongside them:
      - the **nearest** and **floor** variants, which never miss on a
        non-empty `.ref`;
      - **reverse lookup** (value → key onto `.int`);
      - `refUnbind` and `refBindingDepth`, with their keys read from `.int`;
      - `refFresh`, which pushes a fresh key and is a deterministic gensym.

**Slot counts are not fixed** (the user, 2026-11-09). Ten inputs and ten
constants per type are today's numbers, not permanent ones. Some day they will be
arrays of any length. So the counter starts at **N, the number of input slots**,
derived from the slot definitions and never written as 10. Keys 0…N−1 hold the
inputs.

**`.ref`'s size as ruled:**

| Group | Instructions |
|---|---|
| Structural rules | 12 |
| `refQuote`, `refFromCode`, `refEq` | 3 |
| `xRef` | 10 |
| `xWith` | 10 |
| `refRekey` | 1 |
| The lookups and their companions (`refDeref`, `refDerefToCode`, nearest, floor, reverse, `refUnbind`, `refBindingDepth`, `refFresh`) | 8 |
| **Total** | **about 44** |

**Order of work**, a suggestion and not a ruling:
1. The small fixes and the ruled leftovers (P9 and rulings 1–2).
2. Then P1, P1b, P5, P6 and P4, the operations needing no new machinery.
3. Then map, reduce and filter (P2, with ruling 3) and the short iterator
   constructors (P3).
4. Then pattern lookup (P7′) with its measurements.
5. Then `.ref`, the one new stack. The type registry (#37, A4) would make it
   cheaper.
