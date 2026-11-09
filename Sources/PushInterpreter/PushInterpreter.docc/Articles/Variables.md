# Variables and Bindings

Name a value with an int key, look it up later, shadow it, and bind it for the
length of a block.

## Overview

The `.binding` stack holds **bindings**: pairs of an int key and any item, written
`⟨3 ↦ "x"⟩`. A variable is every binding with one key. The topmost is its
current value; older ones below it are shadowed, not lost, so each variable is a
stack of its own values.

Instructions that work on the stack are named for it, as everywhere in Push:
`bindingDeref`, `bindingUnbind`. The one exception is the verb **ref**, which
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
- `bindingDerefBelow` and `bindingDerefToCodeBelow` take a depth from `.int` and
  search from there, which reaches the older, shadowed bindings of the same key.

A key with no binding is a refusal, as if `.binding` were empty.

## Assignment

`bindingRekey` takes a key from `.int` and gives it to the top binding, shadowing
whatever that key held before. Binding a value and re-keying it is assignment, for
a value of any type:

```
7 .intRef .intPop .intPop 3 .bindingRekey     →  key 3 now holds 7
```

(The two pops clear the fresh key and the 7 that `intRef` left behind.)
`bindingUnbind` removes a key's topmost binding, so its previous value comes back.

## Scoped bindings

`intWith` (one for each type) binds the top item of its stack for the length of a
block taken from `.code`, then removes the binding. Inside the block, the
binding's key is on top of `.int`:

```
5 ( .bindingDerefToCode ) .intWith     →  .code holds ( 5 ); the binding is gone
```

`bindingScope` does the same for a key that is already bound:
`k ( body ) .bindingScope` runs the body, then unbinds k.

## Finding keys

- `bindingFreshKey` pushes a fresh key, without binding anything.
- `bindingKeyDepth` gives how deep a key's topmost binding is.
- `bindingNearestKey` gives the bound key nearest a given int.
- `bindingFloorKey` gives the largest bound key at or below it.
- `bindingKeyOf` gives the key bound to a value, the value given as a block on `.code`.

They are useful because keys are ints: arithmetic can walk from one variable to
the next, and these find the bound keys near wherever it lands.

## Bindings as data

`bindingQuote` turns a binding into the block `( k value )`, and
`bindingFromCode` turns such a block back into a binding. A binding written in a
program lands on `.binding`, as a block lands on `.code`.

## See Also

- <doc:BindingInstructions>
