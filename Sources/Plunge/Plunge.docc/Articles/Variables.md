# Variables and Bindings

Name a value with an int key, look it up later, shadow it, and bind it for the
length of a block.

## Overview

The `.binding` stack holds **bindings**: pairs of an int key and any item, written
`⟨3 ↦ "x"⟩`. A variable is every binding with one key. The topmost is its
current value; older ones below it are shadowed, not lost, so each variable is a
stack of its own values.

Instructions that work on the stack are named for it, as everywhere in Push:
`bindingDeref`, `bindingPopKey`. The one exception is the verb **ref**, which
makes a binding *from* another stack's item, just as `intQuote` makes a block
from an int: `intRef`, `stringRef`, and so on.

## Keys

Keys are ints, and any int can be a key, negative ones included. At the start of
every run the inputs are bound under their slot numbers: input 0 is key 0, input 1
is key 1, and so on, for every input the training case binds. So a program can
reach input 3 as `.input3` or as key 3. Rebinding key 3 changes what key 3 gives,
but `.input3` still gives the input.

New keys come from a counter that starts just after the input slots (10, with ten
slots) and counts up. They are the same in every run of the same program:
nothing about a key is random.

## Binding and looking up

`intRef` (and `boolRef`, `stringRef`, `codeRef`, one for each type of value)
binds a copy of the top item of its stack to a fresh key, leaves the item where it
was, and pushes the key onto `.int`:

```
7 .intRef                        →  .binding holds ⟨10 ↦ 7⟩, .int holds 10 7
```

Lookups read a key from the top of `.int` and leave it there:

- `bindingDeref` runs what the key holds. A block's contents run, and any other
  item lands on its stack.
- `bindingDerefToCode` delivers it to `.code` as data, a block as it is and
  anything else wrapped in a one-item block.
- `bindingDerefFrom` and `bindingDerefToCodeFrom` take a depth from `.int` and
  search from there, which reaches the older, shadowed bindings of the same key.

A key with no binding is a refusal, as if `.binding` were empty.

## Assignment

`intRefAs` (one for each type) is assignment: it takes a value and a key and
binds the one to the other, shadowing whatever that key held before. The key is
on top, so for ints the value is just below it:

```
7 3 .intRefAs                    →  key 3 now holds 7
"x" 3 .stringRefAs               →  key 3 now holds "x", and 7 is shadowed
```

`bindingRekey` gives the top binding a new key, whatever its type. So
`7 .intRef .intPop 3 .bindingRekey` also binds 7 to key 3, but leaves the 7 where
it was (the pop clears the fresh key that `intRef` pushed).

## Scoped bindings

`intWith` (one for each type) binds the top item of its stack for the length of a
block taken from `.code`, then removes the binding. Inside the block, the
binding's key is on top of `.int`:

```
5 ( .bindingDerefToCode ) .intWith     →  .code holds ( 5 ); the binding is gone
```

`bindingScope` does the same for a key that is already bound:
`k ( body ) .bindingScope` runs the body, then pops k's binding.

## Removing bindings

Each removal pops a key's topmost binding, so its previous value comes back:

- `bindingPopKey` discards it.
- `bindingDo` runs its value as it pops it, as `codeDo` runs the block it takes:
  `bindingDeref` is the reading form, `bindingDo` the consuming one.
- `bindingUnpack` takes the top binding apart, its value onto its own stack (a
  block as data) and its key onto `.int` above it. `.bindingUnpack .intRefAs`
  puts an int binding back as it was.

## Asking about keys

These read a key from `.int` and leave it. An unbound key is an answer here, not
a refusal:

- `bindingContainsKey` gives whether the key is bound.
- `bindingOccurrencesOfKey` gives how many bindings it has, the shadowed ones
  included.

## Finding keys

These refuse when there is nothing to find:

- `bindingFreshKey` pushes a fresh key, without binding anything.
- `bindingKeyDepth` gives how deep a key's topmost binding is.
- `bindingNearestKey` gives the bound key nearest a given int.
- `bindingFloorKey` gives the largest bound key at or below it, and
  `bindingCeilingKey` the smallest at or above it.
- `bindingKeyOf` gives the key bound to a value, the value given as a block on `.code`.

They are useful because keys are ints: arithmetic can walk from one variable to
the next, and these find the bound keys near wherever it lands.

## Bindings as data

`bindingQuote` turns a binding into the block `( k value )`, and
`bindingFromCode` turns such a block back into a binding. A binding written in a
program lands on `.binding`, as a block lands on `.code`.

## See Also

- <doc:BindingInstructions>
