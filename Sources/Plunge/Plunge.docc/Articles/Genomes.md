# Genomes

What a search edits, and how it becomes a program.

## Overview

A search changes programs by changing their *genomes*. A ``Genome`` holds:

| Part | What it is |
|---|---|
| `tokens` | the instructions, in order |
| `constants` | the values of `.constant(k)` slots, each of any type |
| `permutation` | numbers whose sorted order places the default plan's code blocks |
| `codeTarget` | how much of the genome the default plan cuts into code blocks: a third unless set |
| `plan` | an explicit list of ``GenomePiece``s, or nil for the default plan |

Every part can be edited, and every edit gives a program: a plan with numbers
out of range is clamped rather than refused. An ``Individual`` made with
`Individual(id:genome:)` runs the genome's translation and keeps the genome,
so a search can edit it further.

## The default plan

With no plan of its own, a genome is cut the way Fibonacci genomes always
were: blocks of 1, 1, 2, 3, 5, … tokens are cut from the head while the running
total is at most the code target's share of the genome, and the blocks are
placed at the top of the program, ahead of the remaining tokens, in the order
the permutation's values sort into.

The third is not part of the rule. It is the value a genome's code target has
unless it is given another, ``Genome/defaultCodeTarget``.

```swift
let genome = Genome(tokens: [.intAdd, .intSubtract, .input(0), .constant(0), .intMultiply, .intInc])
genome.translate()
// ( .intAdd ) ( .intSubtract ) ( .input0 .constant0 ) .intMultiply .intInc
```

Six tokens give blocks of 1, 1 and 2: the last of them is the one that takes
the running total past a third of the genome, the default code target.

The code target ranges from 0, which cuts no blocks, to 1, which cuts every
token into blocks. The block that crosses the line is kept, so the share cut is
never less than the code target and is often well above it. At the default the
comparison is made in whole numbers, so a genome of 21 tokens gets a fifth
block (7 cut is at most a third of 21) where a rounded 0.333 would stop at
four. An empty permutation places the blocks in the order they were cut.

## Explicit plans

A plan says exactly where each code block comes from and where it goes, so it
can nest blocks and put them anywhere. It is applied in two passes:

1. **Cut.** Each piece in turn cuts `length` tokens starting at `start`, counted
   in the tokens the earlier pieces left. What is left over is the *trunk*, the
   program's top level.
2. **Place.** Each piece in turn is wrapped as a code block and inserted at
   position `at` into a later piece (`into`), or into the trunk (`into` nil).

A piece can only go into a later piece, so nesting can never loop. An explicit
plan replaces the permutation and the code target; the default plan is itself
just a plan made from them (``Genome/defaultPlan(tokenCount:permutation:codeTarget:)``).

```swift
let tokens: [PushInstruction] = [.intAdd, .intSubtract, .intMultiply, .intQuot, .intMod, .intInc, .intDec]
let nested = Genome(tokens: tokens, plan: [
    GenomePiece(start: 2, length: 2, into: 2, at: 1),
    GenomePiece(start: 2, length: 0, into: 2, at: 2),
    GenomePiece(start: 1, length: 2, at: 1),
    GenomePiece(start: 2, length: 1, at: 3),
])
nested.translate()
// .intAdd ( .intSubtract ( .intMultiply .intQuot ) ( ) .intMod ) .intInc ( .intDec )
```

## From a program back to a genome

`Genome(program:constants:)` makes the genome of any program, so that an
operation that produces a program (tuning, joining, construction) can hand
its result back to a search that edits genomes. The tokens are the program's
instructions in reading order, and the code blocks become the plan, innermost
first. Anything else in the program, such as a literal `3` or `"fizz"`, becomes
a new constant slot and its token.

When the program has the shape the default plan makes (code blocks of
Fibonacci sizes, none nested, all ahead of the other tokens), the genome has no
explicit plan: its code target and permutation say the same thing. The default
code target is kept when it fits; otherwise the genome records one that cuts
those blocks. In this form the tokens are in the order the blocks are cut, which
is the program's reading order only when the blocks were placed in cut order.
The same program always gives the same genome.

``Genome/tokenIndices()`` maps each position of the translated program back to
the token it came from, for operators that choose an edit by looking at the
program.

## Topics

- ``Genome``
- ``GenomePiece``
- ``GenomeEncoding``

## See Also

- <doc:InputsAndConstants>
- <doc:EvaluatingPrograms>
- ``Individual``
