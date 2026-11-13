# Functions: Map, Filter and Reduce

Apply a function to every element of a vector or string, keep the elements a
function approves of, or fold them into one value.

## Overview

A **function** is an item on the `.function` stack: a body with typed **holes**.
Filling every hole gives a runnable program. A function is data: met on `.exec`,
it comes to rest on `.function`, as a code block comes to rest on `.code`, and
nothing runs it except an instruction that applies it.

A code block can already be run on each element of a collection (see
<doc:Iterators>). A function adds one thing a code block lacks: it says what it
needs. Its holes are typed, so an instruction looking for something to apply can
tell which functions on the stack would do the job, and take the first that
fits.

A function prints as `ƒ( … )`, with each hole shown as its type in angle
brackets: `ƒ( ⟨int⟩ 2 .intAdd )` adds 2 to one int.

## Where functions come from

Functions come from two places.

**Starvation.** An instruction that comes up short for arguments records its
missing-arguments error, as always, and is also put on `.function` as a *bare*
function: the instruction alone, whose holes are the arguments it wanted.
Nothing it found is bound into it or taken. `.intAdd` on an empty `.int` leaves
`ƒ( ⟨int⟩ ⟨int⟩ .intAdd )`. Every instruction does this, the ones that copy and
reorder a stack included, so `.intDup` and `.intSwap` reach `.function` too.

**`.codePushAllFunctions`.** It takes a code block from `.code` and runs it in a
sandbox, supplying a placeholder for every argument an instruction is missing.
Every item the code block makes from a placeholder becomes a function, with a
hole where the placeholder was:

```
( 2 .intAdd .intMultiply ) .codePushAllFunctions
    →  .function holds ƒ( ⟨int⟩ ⟨int⟩ 2 .intAdd .intMultiply ) ƒ( ⟨int⟩ 2 .intAdd )
```

The code block made two items from placeholders, a sum and then a product, so it
yields two functions, and the one made last is on top.

Three things are worth knowing about a derivation:

- **One hole can sit in several places.** `( .intDup .intMultiply )` yields
  `ƒ( ⟨int⟩ .intDup .intMultiply )`, which squares its one argument.
- **It runs the code block once**, so it follows only the branch its
  placeholders take. A code block that chooses with `.execIf` yields the branch
  it ran, not the choice.
- **It is paid for.** A code block whose derivation runs too long yields nothing
  and leaves one error, and errors the code block raises inside the sandbox stay
  there. A run pays in steps for deriving a code block the first time it
  converts one with those contents; later copies cost nothing more.

## Applying a function

`.vecIntMap`, `.vecIntFilter`, `.vecIntReduce`, their siblings for the other
vector types, and `.stringMap`, `.stringFilter` and `.stringReduce` each take a
collection and the **topmost function on `.function` that fits** the job:

- **map** needs a hole of the element's type and a value a collection can hold;
- **filter** needs a hole of the element's type and a bool;
- **reduce** needs two holes of the element's type and a value of that type.

Every starved instruction lands on `.function`, so the function on top is often
the wrong shape for the job. Taking the first that fits, instead of whatever is
on top, lets a suitable one further down be used.

The element fills the function's first hole of its type. For reduce, the running
value fills the first and the next element the second: a left fold from the
first element. **Every other hole is filled from the program's own stacks**, top
first, read and left in place, so every element sees the same values:

```
.intAdd 10 [1, 2, 3] .vecIntMap     →  .vecInt holds [11, 12, 13], and 10 is still on .int
```

Here `.intAdd` starved and became a function with two int holes. The map gave
each element to the first hole, and filled the second from the 10 on `.int`.

Each application runs the filled function in a sandbox, which sees the
program's inputs and constants. Its **result** is the top of the function's
output stack afterward. An application that leaves nothing there passes its
element through (map), drops it (filter) or keeps the running value (reduce). A
map's results must all be one type, or the map is refused.

```
( 2 .intMultiply ) .codePushAllFunctions [1, 2, 3] .vecIntMap     →  .vecInt holds [2, 4, 6]
( 2 .intMod 0 .intEq ) .codePushAllFunctions [1, 2, 3, 4] .vecIntFilter     →  .vecInt holds [2, 4]
( .intAdd ) .codePushAllFunctions [1, 2, 3, 4] .vecIntReduce     →  .int holds 10
```

## More jobs for a function

The same choice of the topmost function that fits serves more instructions,
each over the four vector types and strings. What fits depends on the job:

| Job | Instructions | The function needs |
|---|---|---|
| map | `Map` | a hole of the element's type; a bool, int, double, string or char |
| filter, predicate | `Filter`, the searches and cuts below | a hole of the element's type; a bool |
| fold | `Reduce`, `Scan` | two holes of the element's type; a value of that type |
| zip | `Zip` | two holes of the element's type; a value a collection can hold |
| key | `SortBy`, `MinBy`, `MaxBy` | a hole of the element's type; a bool, int, double, string or char |

- **Zip** applies the function to matching elements of two collections of the
  same length: `a b f .vecIntZip` puts a[i] and b[i] in its first two holes. As
  for the element-by-element operations (<doc:Collections>), `b` is the top
  vector and `a` the first one below it with the same length.
- **Scan** folds as reduce does, keeping every running value:
  `.intAdd` scanned over `[1, 2, 3, 4]` gives `[1, 3, 6, 10]`.
- **Keys** order elements by the value the function gives each: `.stringLength`
  as a key sorts words by length, stably. Keys order as everything else does:
  false before true, NaN above every number. An element with no key refuses.
- **Searches** read the collection and leave it: `OccurrencesWhere` counts the
  elements the predicate holds for, `ContainsWhere` and `AllWhere` test them,
  `IndexOfWhere`, `LastIndexOfWhere` and `FindWhere` locate the first or last
  (a miss when none holds).
- **Cuts** take it: `TakeWhile` and `DropWhile` keep or drop the longest prefix
  that holds, and `Partition` gives the elements that hold below the others.

```
.charIsDigit "ab3c4" .stringFindWhere     →  .char holds '3'
```

## Working with functions themselves

- **`.functionApply`** runs the topmost function with an output on the program's
  own values, **taking** a filler for each hole from its stack as the
  instruction itself would: with a bare `.intSubtract` on `.function`,
  `10 3 .functionApply` gives 7. The result lands on the function's output
  stack; an application that leaves nothing there refuses.
- **`.functionCompose`**, written `f g .functionCompose`, makes f after g: g's
  program goes into f's first hole of g's output type, wherever that hole
  occurs.
- **`.functionFill`** is partial application: the topmost function with a hole
  takes the top item of its first hole's stack, which fills that hole wherever
  it occurs. `.intSubtract` with 10 filled is `ƒ( 10 ⟨int⟩ .intSubtract )`,
  ten minus its argument.
- **`.functionArity`** counts the holes of the top function, leaving it.
- **`.functionIterate`**, written `x n .functionIterate`, applies the topmost
  *step* function (one with a hole of its own output's type) n times from x.
- **`.functionIterateUntil`**, written `x p f`, gives the orbit x, f(x),
  f(f(x)), … up to and including the first value the predicate p holds for, as a
  vector: f is the topmost step function and p the topmost predicate on its type
  below it. Halving from 16 until 1 gives `[16, 8, 4, 2, 1]`.
- **`.functionRef`**, `.functionWith` and `.functionRefAs` bind functions to
  keys, as the other types' binders do (<doc:Variables>).

## Functions as loop bodies

A function can also run **as code**, on the program's own stacks instead of in a
sandbox: `.codeFromFunction` gives its body as a code block, its holes left out,
so each hole is simply an argument its instructions take from the stacks as they
run. The loops do that for you: `.functionDo`, `.functionDoTimes`,
`.functionDoCount`, `.functionDoRange`, `.functionWhile` and `.functionIf` each
rewrite themselves into the code loop of the same name, over the top function's
body (`n f .functionDoTimes` is `n f .codeFromFunction .execDoTimes`). A bare
`.intAdd` repeated three times over `1 2 3 4` leaves 10. As every loop's body
does, the body returns to `.code` as a code block when the loop ends.

## When there is no function

- An **empty** `.function` starves the instruction: it takes nothing, and is
  itself put on `.function`.
- A `.function` with **nothing that fits**, or a function whose other holes can't
  be filled from the program's stacks, is a miss: the instruction takes its
  arguments and refuses with a ``ErrorKind/notFound`` error.

## Cost

Every step a function takes counts against the program's own step limit, and so
does every step `.codePushAllFunctions` spends deriving a code block. A map that
would run past the limit is refused, so a function can't be used to escape it.
See <doc:LimitsAndGuards>.

## Another way to map

An iterator with a body maps too, **stack-fed**: for each element,
`.vecFromIterator` runs the element and then the body in a sandbox, so the
element arrives on its own stack, and it collects what the body leaves. The
`.iteratorOver…` instructions build such an iterator in one step from a
collection and a code block. The difference is in how the work is chosen: an
iterator carries the one code block it was built with, and a function
instruction picks, from all the functions on the stack, the first that fits.

## See Also

- <doc:FunctionInstructions>
- <doc:Collections>
- <doc:Iterators>
- <doc:ErrorsAndRefusals>
