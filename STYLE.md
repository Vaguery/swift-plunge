# Style

How to write about Plunge: in the DocC articles, documentation comments,
instruction summaries, the README, notes and issues. For how to build, test and
change the code, see [CONTRIBUTING.md](CONTRIBUTING.md).

These rules exist because the same few words kept drifting between meanings.
They apply to everyone, the maintainers included.

## Spelling

- US English everywhere: behavior, color, catalog, labeled, toward, -ize.
  Apple's API spellings stay as Apple wrote them (`isCancelled`).
- *Genetic programming* is two words, with no hyphen, wherever it appears, and
  can be abbreviated to GP in reader-facing text after the first occurrence on that page.

## The language and its names

- *Push* is the family of stack-based languages and the ideas they share.
- *Plunge* is this dialect and the module, and `swift-plunge` is the name of the Swift package.
- A *search*, as a noun, is the process outside the library that makes programs
  and decides which to keep. The instructions that search a stack or a
  collection are *lookups* and *finds*, to keep the two apart.

## Values, items, types and stacks

Four different things are easy to blur. Each has its own spelling:

| Talking about | Write | Example |
|---|---|---|
| the value an item expresses | the Swift type | `17` is an `Int`; `"foo"` is a `String` |
| the thing on a stack, or taken as an argument | the item type | an `IntItem`, a `StringItem` |
| in passing, what an instruction takes or gives | the undotted stack name, in backticks | takes two `int` items, gives a `vecInt` |
| the stack itself | the dotted stack name | the `.int` stack, `.exec` |

The instruction reference's *Takes* and *Gives* columns follow the third row.

In plain sentences, plurals of these words are ordinary English and need no
backticks: "the top two ints", "several strings are moved". This reads better
than "two `int` items" and means the same.

## Code blocks

The parenthesized, nested thing on the `.code` stack is a *code block*, a
`code` item, or a `CodeItem`. Never write *block* alone: the word means too
many other things in other languages. A loop's body is a code block, and so is
a branch of `.execIf`.

Its parentheses are separated from what they hold by spaces, as `pretty()`
prints them: `( 1 .intAdd )` and `( ( 1 2 ) 3 )`, never `(1 .intAdd)`. An empty
code block is `( )`.

## Instructions

- An instruction is written with its dot, in running text as in programs:
  `.intAdd`, `.codeDo`.
- A family of instructions is written with X standing for the type
  (`.vecXSort` for `.vecIntSort`, `.vecStringSort` and the rest), or by the
  ending its members share (`Rotate`, `Map`). A bare ending is not an
  instruction name, so it has no dot.
- An instruction's name starts with the stack it works on, and a verb that makes
  something from another stack's item follows that stack (`.intQuote`,
  `.intRef`). See CONTRIBUTING for naming new instructions.
- Another interpreter's instruction keeps its own spelling and gets no dot, and
  names its source: `exec_if` (in Clojush and Propeller).

## Writing programs

Programs are written as the library's `pretty()` function prints them:

| Written | Is |
|---|---|
| `3`, `2.5`, `true` | an `Int`, a `Double`, a `Bool` value |
| `"hello"`, `'h'` | a `String`, a `Character` |
| `[1, 2, 3]` | a vector, with commas |
| `.intAdd` | an instruction |
| `( 1 .intAdd )` | a code block |
| `«bind: 3 -> "x"»` | a binding |
| `«fn (int) -> int: $0 2 .intAdd»` | a function with one `int` hole |
| `«iter 0 to 3 by 1 at 2»` | an iterator |
| `«err missingArgument: .intAdd»` | an error: its kind, then the instruction that raised it |
| `«observed .intStackDepth: 4»` | a stand-in (also `elided`, `minted`) |

- A program reads left to right in the order it runs, and an arrow shows what
  it leaves: `3 4 .intAdd  →  .int holds 7`.
- A stack's contents are listed **top first**: after `1 2 3`, `.int` holds
  3 2 1.
- When argument order matters, show the instruction as a program writes it:
  `a b .intSubtract` gives a − b.
- A program is a code block. For now, examples show a program without its outer
  parentheses; see *Not yet settled*.

## Printed forms

The rule for `pretty()`, and for anything written by hand in its notation:
**from an item's printed text alone, a reader can tell its type and its value.**
Two items that are not equal never print alike. `Printed Form Tests` holds
every item type to this; add a new type's confusable cases there.

- **Short forms** are for the types whose punctuation already says what they
  are: numbers and bools bare, strings in `"…"`, chars in `'…'`, vectors in
  `[ ]`, code blocks in `( )`, instructions with a leading dot.
- **Everything else is labeled**: guillemets, a short tag for the type first,
  then its contents. `«bind: 3 -> "x"»`, `«fn (int) -> int: $0 2 .intAdd»`,
  `«iter 0 to 5 by 1 at 2: ( true )»`, `«err overflow: .intAdd»`. A new structured type
  (a matrix, a point) prints this way too, with named fields where position
  alone wouldn't be clear: `«point x: 1.5, y: 2.0»`.
- **Every item also has an explicit form**, `«type …»` around its short form:
  `«int 88»`, `«str "foo"»`, `«char '\n'»`, `«vecInt [1, 2, 3]»`,
  `«code ( 1 .intAdd )»`, `«inst .intAdd»` (`explicitPretty()`). Use it
  where the short form could be misread or the type is the point. `pretty()`
  itself uses it where the short form is ambiguous: an empty vector prints as
  `«vecInt []»`, since `[]` alone doesn't say which of four types it is.
- **The tags are short**: the stack's name, abbreviated where it is long.
  `int`, `bool`, `char` and `code` are unchanged; the rest are `dbl`, `str`,
  `vecDbl`, `vecStr` (with `vecInt` and `vecBool`), `fn`, `bind`, `iter`, `err`
  and `inst` for an instruction. These tags belong to the printed form only: in
  prose a type is still named by its stack (`string`, `function`). A function's
  signature uses them too: `«fn (str) -> dbl: …»`.
  `PushStack.tag` is the one table of them. Stand-ins are labeled by their
  reason instead: `observed`, `elided`, `minted`.
- **Strings and chars are escaped**: their own quote mark, `\\`, and every
  character that might not show on a page (`\n`, `\t`, `\r`, `\0`, `\u{…}`).
  That covers the ASCII controls and the invisible Unicode ones: every space
  but the plain one, the line and paragraph separators, zero-width and
  direction marks, the byte-order mark. Printed text can then be read back
  exactly. A string may hold `'` unescaped, and a char may be `"`.
- **Plain characters only.** Words, not symbols: `to`, `by`, `at`, `over`,
  `repeated`. Arrows are `->`, two characters. No emoji, and no brackets beyond
  `( )`, `[ ]` and `« »`. Inside a function, a hole is `$0`, `$1`, … in the
  order of its signature.
- **Arrows outside printed forms.** In prose, examples and messages the
  typographic right arrow is fine: `3 4 .intAdd  →  .int holds 7`. Use only
  that plain one, never the barred "maps to" arrow or other variants.
- **No free text.** Everything inside a printed form is a tag, a keyword or
  another printed item, so a simple grammar can read it back. An error prints
  its kind and the instruction that raised it, `«err overflow: .intAdd»`, or
  its kind alone when the interpreter raised it, `«err sizeRefusal»`. Its
  sentence (`Overflow in .intAdd: …`) stays on the item as `value`, for logs.
  Equality follows the printed form: errors are equal when kind and
  instruction match. A new kind of refusal gets a one-word `ErrorKind`, not a
  new sentence shape.
- **How an item was made is not printed.** A function made by starvation
  (a *bare* function) prints like any other,
  `«fn (int, int) -> int: $0 $1 .intAdd»`, and equals a derived function
  with the same body, holes and output. An item's history never affects its
  printed form or its equality.

## What can go wrong

- An instruction *starves* when a stack it needs holds too few items. It takes
  nothing, leaves a *missing arguments* error, and becomes a bare function.
- An instruction *refuses* when it has its arguments and can't use them. It
  leaves an error that says why, and no result.
- A *miss* is the refusal of an instruction that looked for something and found
  nothing. Its error kind is `notFound`.
- An error is a record, not an exception. Don't call it a crash, a failure of
  the run, or a thrown error.

## Documentation comments

- The first sentence is the summary a reader sees in lists. Write it for
  someone using the library.
- Explain behavior and intent. Don't cite issue numbers or documents outside
  this repository.
- Notes for people changing the code (measurements, history, why something is
  declared where it is) go in ordinary `//` comments, which DocC leaves out.

## Instruction summaries

Every instruction has a one-sentence summary, declared with `.described(…)`,
from which the instruction reference is generated:

- start with a verb, and keep to one sentence (semicolons allowed);
- when the order of arguments matters, show the written form:
  "Subtracts: `` `a b .intSubtract` `` gives a − b.";
- say what a query leaves ("…, leaving both") and when an instruction refuses
  ("refuses when b is 0");
- don't mention starvation, provenance or implementation details;
- name what an instruction takes or pushes in passing, by its undotted stack
  name: "pushes an `int`", not "pushes an `Int`".

## Not yet settled

Raise this before relying on either reading:

- **Outer parentheses around a program.** A program is a code block, and the
  preferred way to show one is inside its own parentheses:
  `( 3 4 .intAdd )`. Much of the documentation (and possibly some tests) shows
  programs without them. The change waits until there is a norm for how
  `pretty()` shows the other composite things, such as a crux and a function, so
  that one choice of punctuation covers all of them.
