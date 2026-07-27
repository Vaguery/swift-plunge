#  Missing Code instructions

> **Status (2026-07-26): complete** — every `code*` instruction below is implemented, the four
> gap-based ops (`codeCutAtGap`, `codeInsertAtGap`, `codeFlattenRange`, `codeWrapPoints`) included.
> They waited on the gap-model design pass, which is now `CodeGaps.swift`; read that file's header
> for the model and **ignore the "flat Plushy" wording in the four sketches below**, which predates
> the removal of that genome type and its code-making mechanism. The model is stated natively as a
> `CodeItem` operation and depends on no genome layer.
>
> Two semantics were decided in that pass and are worth having here:
>
> - **A cut preserves every leaf, in order.** The pieces are repaired — an unclosed block is closed,
>   an unmatched close dropped — so nothing is lost. Nesting *on the cut path* does change, which
>   means cut-then-`codeAppend` is the identity only for a gap between root elements, as
>   `codeCutRootAtGap` always was. A block split in two cannot reassemble.
> - **`codeFlattenRange` leaves enclosing blocks alone.** A block flattens iff its head or tail gap
>   falls in the range, so a block that merely contains the range keeps its shape. Otherwise a
>   one-gap range would flatten the whole tree, since the root encloses every range. `codeGather` was renamed
> **`codePair`** (wrap two items into `(x y)`) and `codeFlattenOnce` added. The singleton-unwrap
> convention (a one-element block denotes its element) lets code needles name leaves — Design Principles
> §7b. A later pass added the `.exec` point-access family beyond the list below —
> `codeEmitNth{Point,Root}`/`codeDoNth{Point,Root}` and `codeIterate{Emit,Do}Points` (the three-way
> `PointsEmission`: boxed / whole / unwrapped) — the neutral-paths idea in Design Principles §17. See
> Roadmap.


## Action items

1. Examine the current Instruction definitions and ensure there is a mapping between the list of proposed instructions given in `swift-push-interpreter plan` and the ones currently named in the language enum; ask about accidental renames I may have made (there are a lot, and many names have changed over the months); after discussion, adjust this document's list to match the ground truth decided
2. Check which of the currently implemented Behaviors match the descriptions here, and which are not yet implemented
3. Implement what remains

### Notes
- As mentioned elsewhere, the `points` traversals and indexing are based on the implementation of the `zipper` data structure from Clojure, which offers a low-complexity immutable way to traverse and manipulate a tree structure. There is no need to replicate that if Swift or some simple library provides the necessary functionality already; this is just how the nomenclature arose originally, and isn't a decision, just a metaphor
- As a rule of thumb, any counting or traversal of a nested CodeItem tree is **pre-order** (a node before its children, depth-first, left to right). Point index 0 is the CodeItem itself.
- Some of the iterators mentioned here have already been discussed and imlpemented
- Unit testing should be rigorous and expressive, because these CodeItem manipulations may be strange when an empty code block is involved
- The use cases for CodeItems as "crux-based functions" is postponed to a later increment phase

## A historical comparison

Code in propeller and Clojush/Klapaucius


| Clojush          | Klapaucius      | Propeller   | Swift                     |
| ---------------- | --------------- | ----------- | ------------------------- |
| code_append      | code-append     | code_append | codeAppend                |
|                  | code-append!    |             |                           |
| code_atom        | code-atom?      |             |                           |
| code_car         | code-first      |             | codeCut                   |
|                  | code-first!     |             |                           |
| code_cdr         | code-rest       |             | codeCut                   |
|                  | code-rest!      |             |                           |
| code_cons        | code-cons       |             | codeInsert                |
|                  | code-cons!      |             |                           |
| code_do          | code-do         |             | codeIterate               |
| code_do*         | code-do*        |             |                           |
| code_do*range    | code-do*range   |             |                           |
| code_do*count    | code-do*count   |             |                           |
| code_do*times    | code-do*times   |             |                           |
|                  | code-drop       |             | codeCut                   |
|                  | code-drop!      |             |                           |
| code_map         | code-map        |             | codeIterate               |
| code_fromboolean |                 |             | boolQuote                 |
| code_fromint     |                 |             | intQuote                  |
| code_fromfloat   |                 |             | doubleQuote               |
| code_quote       | code-quote      |             | execQuote                 |
| code_if          | code-if         |             | codeIf                    |
| code_length      | code-length     |             | codeLength                |
| code_list        | code-list       |             | codePair               |
|                  | code-list!      |             |                           |
| code_wrap        | code-wrap       |             | codeWrap                  |
|                  | code-wrap!      |             |                           |
| code_member      | code-member?    |             | codeContains              |
| code_nth         | code-nth        |             | codeNth                   |
|                  | code-nth!       |             |                           |
| code_nthcdr      | code-rest       |             | codeCut                   |
| code_null        | code-null?      |             | codeItemIsEmpty           |
| code_size        | code-size       |             | codeTreeSize              |
|                  | code-points     |             | codePointSize             |
| code_extract     | code-extract    |             | codeNthPoint              |
|                  | code-extract!   |             |                           |
| code_insert      | code-insert     |             | codeInsert                |
|                  | cde-insert!     |             |                           |
| code_subst       | code-subst      |             | codeReplaceAllOccurrences |
|                  | code-subst!     |             |                           |
| code_contains    | code-contains?  |             | codeContains              |
| code_container   | code-container  |             | codeContainer             |
|                  | code-container! |             |                           |
| code_position    | code-position   |             | codeIndexOf               |
|                  | code-reduce     |             |                           |
|                  | code-return     |             |                           |

Many of these instructions are from Push interpreters where code items are handled by immediate unwrapping and execution, not by pushing to the code stack and manipulation, so only the ones that are compatible have been retained here.


## swift-push-interpreter plan

This feels like a reasonable collection to implement:

- codeAppend: concatenate the values of two `.code` args
- codeContainer: find a target `.code` item in another's tree, and if so return its parent; NONDESTRUCTIVE
- codeContains: `true` if a target `.code` item is present in another's tree; NONDESTRUCTIVE
- codeCutAtGap: convert `.code` argument to a flat Plushy, count points and gaps, and cut where indexed by an `.int`; repair both pieces as needed at the ends so they contain the entire CodeItem tree (essentially, remove and extract some arbitrary subtree of the argument's root .value array, as a new CodeItem), then return
- codeCutRootAtGap: cut the root of a `.code` item where indexed by an `'.int`
- codeDepth: maximum steps from root to the farthest leaf; NONDESTRUCTIVE
- codeDo: pop code item and unwrap onto .exec stack
- codeFlatten: flatten the entire tree of a `.code` item to its leaves, left to right (pre- and post-order agree on leaf order)
- codeFlattenOnce: flatten the `CodeItem` tree one level towards the root, bringing any subtrees in the root value down into the root itself, but not flattening their grandchildren nodes 
- codeFlattenPoint: find the indexed point in the tree and flatten that (replace the subtree with its leaves as a flat CodeItem)
- codeFlattenRange: find two indexed gaps in the tree (inclusive), and flatten every subtree with either of its ends overlapping that range; do not flatten containers that are entirely outside the range
- codePair: take two `.code` items and put them into a new one
- codeIf: pop two `.code` arguments, and send the correct one (unwrapped) to `.exec` based on a `.bool`
- codeIndexOfPoint: if a `.code` item's contents can be found in the tree of another, return the position as an `.int` index of the point it's first found; NONDESTRUCTIVE
- codeInsertAtGap: insert a second `.code` item into the tree of another, at an `.int`-indexed gap between points
- codeItemIsEmpty: `true` if empty; NONDESTRUCTIVE
- codeIteratePoints: standard `iterate` but using every point in turn
- codeIterateRoot: standard `iterate` using root elements only
- codeLengthPoints: count of points in entire tree; NONDESTRUCTIVE
- codeLengthRoot: count of points in the root; NONDESTRUCTIVE
- codeNthPoint: return the indexed point; NONDESTRUCTIVE
- codeNthRoot: return the indexed root element; NONDESTRUCTIVE
- codeRemovePoint: delete the entire point (subtree) at the indexed location
- codeReplaceAllPoints: every place a given subtree is found in a larger tree, replace as indeicated
- codeReplaceFirstPoint: as above, but first location only (in point order)
- codeWidth: total number of leaves in the tree; NONDESTRUCTIVE
- codeWrapRoot: insert `Open` and `Close` marks around a root element of the tree and rebuild
- codeWrapPoints: pick two indexed gaps; insert an `Open` at the first and a `Close` at the second, and rebuild

## For later, not now

- ~~codePreOrderIterate~~ — this is `codeIteratePoints` (built): points are always walked pre-order, so the separate name was redundant
     
- codeFuncFromXCrux: takes an item of the specified type `X` and an `.int`, looks at its history (aka 
"crux"), and removes the indexed leaf from that tree. The result is pushed as a new `.code` item
    - codeFuncFromBoolCrux
    - codeFuncFromCharCrux
    - codeFuncFromCodeCrux
    - codeFuncFromDoubleCrux
    - codeFuncFromIntCrux
    - codeFuncFromStringCrux

