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

## Writing programs

Programs are written as the library's `pretty()` function prints them:

| Written | Is |
|---|---|
| `3`, `2.5`, `true` | an `Int`, a `Double`, a `Bool` value |
| `"hello"`, `'h'` | a `String`, a `Character` |
| `[1, 2, 3]` | a vector, with commas |
| `.intAdd` | an instruction |
| `( 1 .intAdd )` | a code block |
| `⟨3 ↦ "x"⟩` | a binding |
| `ƒ( ⟨int⟩ 2 .intAdd )` | a function with one `int` hole |

- A program reads left to right in the order it runs, and an arrow shows what
  it leaves: `3 4 .intAdd  →  .int holds 7`.
- A stack's contents are listed **top first**: after `1 2 3`, `.int` holds
  3 2 1.
- When argument order matters, show the instruction as a program writes it:
  `a b .intSubtract` gives a − b.
- A program is a code block. For now, examples show a program without its outer
  parentheses; see *Not yet settled*.

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

Raise these before relying on either reading:

- **Plain English plurals** for items in passing ("the top two ints") alongside
  the backticked form ("the top two `int` items").
- **Outer parentheses around a program.** A program is a code block, and the
  preferred way to show one is inside its own parentheses:
  `( 3 4 .intAdd )`. Much of the documentation (and possibly some tests) shows
  programs without them. The change waits until there is a norm for how
  `pretty()` shows the other composite things, such as a crux and a function, so
  that one choice of punctuation covers all of them.
- **How a function is written.** The preferred form gives a signature of stack
  names, then the body with its holes written `$0`, `$1`, …:
  `f(int, double) -> vecDouble { $0 $1 … }`. Until `pretty()` prints that, and
  it is settled whether a program holding such a function can still be read
  (by people, and by a parser), write functions as `pretty()` prints them today:
  `ƒ( ⟨int⟩ 2 .intAdd )`. Issue #32 tracks the change.
