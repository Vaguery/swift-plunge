# vector and collection instruction coverage

In some of the oldest planning documents I have a few more stray instructions (and families) I would like to
add, for completeness. The first batch is from the planning document in Instruction Coverage.markdown, and let
 me go through them all in turn. This is a collected proposal for how to proceed, and what I want is some argument where asked and a plan for implementing the clear-cut cases. In some cases these will help the flow of items between types, and may help the shortage of some stack items.

### vector comparisons

 It is an open question whether there should be .vecXLT, .vecXLTE, and so on, because there is no canonical approach to sorting vector items. Since there is an implicit analogy that a string is a vector of characters, the natural-seeming analogy would be a similar lexicographic sorting algorithm (see https://en.wikipedia.org/wiki/Lexicographic_order), and by that argument `[9, 2, 3, 4]` > `[1, 1, 1, 1, 1]`, and `[9.9, 8.8]` > `[0.0, 0.0, 0.0]`. I do not think the "shortlex" approach makes sense for this. This would work for `vecInt`, `vecDouble`, `vecString`, and `vecChar` as far as I can see. 

Therefore, add the missing comparison instrucitons and behaviors for the four default vector types. 

This does not make sense for `.code`

### vector partitioning

The recent addition of `vecXcut` can act synonymously witht he explicit `vecXfirst` and `vecXLast` instructions, and I think that level of overlap is worthwhile, especially since the special-case ones are sometimes used in crux descriptions.

Therefore, ensure there is equivalence among the various `head`, `tail`, `first`, `last`, `butLast` and so on intructions among the vector and string Behavior suite.

This does make sense for `code`, and there should be at least two variants: one that acts at the root level and partitions the root `CodeItem.value` array at an index, and one which works at the "points" level, using a tree zipper approach, and snips away a subtree at a given zipper position traveersing in depth-first order.

### vector search

I think we currently have the vector equivalent of `.stringContainsChar`, but not the equivalent of `.stringContainsSubstring`, and definitely do not have the `replace` equivalent.

Therefore, ensure there is equal coverage for the vector types to find sub-vectors and replace them in the same way as `string` already can.

This is in the planned instruction set for `code`, both at the root and "points" level.

It also pushes against an implicit design principle, which is only recently surfacing: pattern matching. In the current design plans, the idea of "sieve" lookups is getting closer to realization, and there is a potentially large aspect of Push more broadly which makes me wonder if a "pattern" can reasonably be considered a first-class item, in any practical way.
  
### vector components

It looks like there's no vector equivalent to `.stringParseToLetters` and `stringSplit`. The first, as vector version in the current design framework, would produce an IteratorItem that emitted one single-element vector taken from the larger argument at each step. The second would break the argument vector into "words" subvectors at each step, and in this case there would need to be design decisions made about an analogy to "whitespace" in a numerical string. For `int` and `double`, this would naturally be something like "blocks of positive values only, and read all negative values as 'white space'". For `char`, actual "white space" will still work, though it may be rare depending on the `vecCharItem`. For `vecString`, the question is open and opaque. Maybe "split on any string containing whitespace"?

Therefore, add if that rule does not suit and no replacement is obvious, use it and add the missing `split` instructions to the vector Behaviors.

I can't quite see how this would apply to a `.code` item, unless an empty container is treated as a vague analogy to "whitespace" in a tree. for obvious reasona an empty container has no "following" content in a tree, unless it's being traversed pointwise.

### vector constructors

There is another source of `vecX` items available, which based on my review of the codebase is still pending, and that is the ones previously called `vecXgather`. Originally this would have consumed items from the `X` stack, but now that there are nondestructive `reads` instructions, it's entirely feasible to have the instructions read nondestructively the required number of items from the `X` stack. Maybe these should be called `.vecXFromSItems`. A version with an `.int` argument that specifies the number of items to read is possible, but so is a `vecXFromStack` which takes no integer argument and simply reads the stack whole.

Therefore, check whether we currently have destructive string versions of these, and consider reworking those to be nondestructive, and adding the `stringFromItems` and `stringFromStack` nondestructively, and `vecXFromItems` and `vecXFromStack`

The case of `code` equivalents is interesting, since there is no obvious pracical reason to wrap multiple single-type items in a flat `code` item except sequestering them, and if the construction is nondestructive those items may as well be in a vector. The exceptions are `code` and `exec` items, which do seem the natural places to collect items. In both cases the resulting `code` item would be heterogeneous and possibly tree-shaped. 

### vector and string chunking

A missing aspect of standard vector manipulation is chunking: processing a vector by fixed-size subunits, either overlapping, or in nonoverlapping segments of fixed size.

Explore the potential downsides; this is a lot of vector manipulation instructions at once, and it may be a future (if needed) proposal. It may be easily reachable by using the existing `stride` infrastructure in the `IteratorItem` struct.
