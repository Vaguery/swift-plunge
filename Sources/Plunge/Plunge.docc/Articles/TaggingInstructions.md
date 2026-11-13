# Tagging Instructions

Tags label sets of instructions: what types they touch, what they do, what they
cost and how a search might use them. Anyone can add their own.

## Overview

A **tag** is a label on a set of instructions. Tags overlap freely. `.vecIntSum`
is a `collection`, `vector`, `inspection` and `measurement` instruction all at
once, and nothing requires two instructions to have different tags. The
vocabulary is open: an ``InstructionTag`` is any string, and the tags this
library ships are its static members.

Tags are for explaining and relating instructions, not for cutting the language
down. A search normally runs with every instruction enabled, and leans on tags
only softly: weighting draws with a floor, or swapping an instruction for one
like it. Excluding instructions by tag is the rare, deliberate case. The reason
is that nobody can say in advance which instructions a solution will need.

## The standard tags

``InstructionTagging/standard`` holds the library's tags, about forty of them,
and every instruction carries at least one. Each tag has a ``TagFacet`` saying
what it describes:

| Facet | Tags |
|---|---|
| Types | `scalar`, `numeric`, `textual`, `collection`, `vector`, `reified` |
| Mechanics | `operation`, `structural`, `contextRead`, `control`, `channel` (the ``BehaviorClass``) |
| Kind | `calculation`, `inspection`, `detection`, `comparison`, `measurement`, `search`, `stackCombinator`, `branching`, `looping`, `higherOrder`, `execution`, `transformation`, `conversion`, `assembly`, `disassembly`, `reshaping`, `source`, `introspection`, `naming`, `iterators`, `complicated` |
| Cost | `addsSteps`, `mayRunUnbounded`, `runsSubprograms` |
| Use | `bridge` |
| Judgment | `fallible`, `reEntrant`, `risky`, `cruxOnly` |

Most are **derived**: computed from what each instruction's definition declares
(its arguments, outputs, class and the stacks it looks at), never from its name.
A derived tag can't disagree with the definitions, but it can't see what they
don't say: `.vecIntIndexOf` and `.vecIntPeekNth` both read a vector and an int
and give an int, so they carry the same tags, though one int is an element and
the other an index. The **judgment** tags are declared where each instruction is
defined. ``InstructionTag/provenance`` says which kind a tag is, and
``InstructionTag/rationale`` gives its rule or its evidence.

`bridge` marks the instructions that give a kind of data they didn't take:
conversions, quotes, iterator constructors. They change a program's
representation, which is how an unexpected solution often works, so a search
that narrows its instructions should keep them in play.

To ask which instructions touch a particular stack, use
``Runner/instructions(touching:)`` instead of a tag.

## Tags are not roles

The library also divides the language into five *roles* (``InstructionRole``):
constants, inputs, the family of stack instructions, comparisons, and everything
else. Every instruction has exactly one role. Roles exist for drawing the random
programs the library tests itself with, in proportions that keep those programs
from starving, and are not a description of the language. To describe
instructions, or to steer a search, use tags.

## Adding your own tags

Layer your tags over the standard ones:

```swift
let tagging = InstructionTagging.standard
    .adding("psb:vectorAverage", to: [.vecIntSum, .vecDoubleSum])
    .adding("myProject", to: [.intAdd, .intMultiply])

tagging.tags(of: .vecIntSum)          // the standard tags, and psb:vectorAverage
tagging.neighbors(of: .intAdd).first // the instruction sharing most of its tags
```

``InstructionTagging/merging(_:)`` combines two taggings, and
``InstructionTagging/similarity(_:_:)`` scores how alike two instructions are by
their tags.

To keep a benchmark from being handed instructions that would solve it outright,
tag them and disable the tag. A program that still contains a disabled
instruction runs, and the instruction leaves an error:

```swift
let configuration = RunnerConfiguration(
    disabledBehaviors: tagging.instructions(taggedAnyOf: ["psb:vectorAverage"]))
```

## See Also

- <doc:DesignOfPlunge>
- <doc:EvaluatingPrograms>
- ``InstructionTag``
- ``InstructionTagging``
- ``InstructionRole``
