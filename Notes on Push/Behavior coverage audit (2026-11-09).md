# Behavior coverage audit

**Status: PROPOSAL, nothing built (2026-11-09).** An overview of what the
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
- **`Sort`** (ascending; `Reverse` gives descending) and **`Distinct`** on every
  vector type and `string`.

Each is a query: it reads, does not take, and leaves its argument (Design
Principles §5, I7). About 22 instructions.

**Adds:**
- average: 1 step (`vecIntMean`), or 3 steps (`.vecIntSum .vecIntLength
  .intQuot`, possible because both are queries);
- second and third routes to sum, max and min;
- the first routes to sort and dedupe;
- a median: `Sort`, then `Nth` of `Length` halved.

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

**Recommendation: (1).** It is the bigger addition to reach. It also provides
the variables below for almost nothing.

### P8. Local variables (#39), on top of the dictionary

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
| P1 | ≈ 22 | — |
| P5 | ≈ 16 | — |
| P6 | ≈ 10 | — |
| P4 | ≈ 9 | — |
| P3 | ≈ 6 | a ruling on `vecFromIterator` |
| P2 | ≈ 15 | #2's design |
| P7 + P8 | ≈ 35 | the type registry (A4 / #37) |

In all, about 120, taking 607 to about 730. Excluding P7 and P8, about 85.

**With P1–P6 and P9, every task in §2 has at least two routes within 5 steps.**
For example, average:
- `vecIntMean`;
- `.vecIntSum .vecIntLength .intQuot`;
- `( .doubleFromInt ) .vecIntMap .vecDoubleMean`;
- `( .intAdd ) .vecIntReduce` and divide.

Word frequency and variables wait for P7.

**Open questions for the user:**
1. Should `stringDrop` drop from the front?
2. Should `vecFromIterator` collect a body's results when there is a body?
3. Should map's result type follow the data (uniform or refuse)?
4. A dictionary stack, or association lists in `.code`?
5. Are the new reductions queries (I7) from the start?
