# Searching the Stacks

Find an item by what it looks like, on a stack or inside a collection, and use
what you find without losing your place.

## Overview

Most instructions use whatever is on top of a stack. A **lookup** instead searches
a stack from the top down for the first item that matches a probe, and a **find**
does the same inside one collection. Between them, a program can use the stacks
themselves as a store of keyed records, without a dictionary type.

## Lookups on a stack

A lookup's probe is the top item of the stack it searches. The probe is read and
left in place, and the search runs down from the item below it. When an item
matches:

- a **copy** of it goes on top of the stack, and the original stays where it was;
- its **position** goes onto `.int`: its depth plus one, which is where the
  original sits once the copy is on top. So `stringYank` reaches it, and a
  `…From` lookup starting there continues the search.

```
"pear" "apple pie" "apple" .stringLookupPrefix
    →  .string holds "apple pie" "apple" "apple pie" "pear"; .int holds 2
```

When nothing matches, the lookup refuses and changes nothing, as if the stack
were empty. Each lookup has a `…From` form that takes a starting depth from `.int`,
so a program can walk every match: look up, use the copy, then look up again
from the position the last match left.

## Kinds of match

A lookup's kind is part of its name:

| Kind | Matches an item that… | On |
|---|---|---|
| `Equal` | equals the probe | every value stack but `.bool` |
| `Prefix` | begins with the probe's contents | strings, blocks, vectors |
| `Containing` | contains the probe | strings, blocks, vectors |
| `Shape` | has the probe's shape, with any values at its leaves | blocks |
| `Nearest` | is closest to the probe; ties go to the topmost | ints, doubles, chars |

They run from exact to forgiving. `Nearest` misses only when there is nothing
below the probe; `Equal` misses most often.

## Records on the code stack

Blocks make good records, and a prefix lookup on `.code` finds one by its first
item. Here `( "a" 1 )` and `( "b" 2 )` are two records, and the program looks up
the one whose key is `"a"`, then takes out its value:

```
( "a" 1 ) ( "b" 2 ) "a" .stringQuote .codeLookupPrefix 1 .codeEmitNthRoot
    →  .int holds 1 (and the lookup's position below it)
```

For variables a program sets and changes, the `.binding` stack is the dedicated
store; see <doc:Variables>.

## Finds inside a collection

A **find** reads a collection and a probe, leaves both, and pushes the first
matching element and its index: the index first, the element on top of it.

```
[3 9 14] 10 .vecIntFindNearest     →  .int holds 9 1 10
```

The finds are `vecIntFindNearest`, `vecDoubleFindNearest`, `stringFindNearest`
(a char probe), `vecStringFindPrefix`, `vecStringFindContaining` and
`codeFindPrefix` (a record inside one block of records), each with a `…From` form
that takes a starting index. The `IndexOf` instructions have `…From` forms too,
so every search inside a collection can resume where the last one stopped.
