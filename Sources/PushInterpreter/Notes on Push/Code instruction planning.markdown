#  Missing Code instructions

Missing instructions in bold

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
| code_list        | code-list       |             | codeGather                |
|                  | code-list!      |             |                           |
| code_wrap        | code-wrap       |             | codeWrap                  |
|                  | code-wrap!      |             |                           |
| code_member      | code-member?    |             | codeContains              |
| code_nth         | code-nth        |             | codeNth                   |
|                  | code-nth!       |             |                           |
| code_nthcdr      | code-rest       |             | codeCut                   |
| code_null        | code-null?      |             | codeIsEmpty               |
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
|                  |                 |             | codePostOrderIterate      |
|                  |                 |             | codePreOrderIterate       |
|                  |                 |             | codeCutPostOrder          |
|                  |                 |             | codeCutPreorder           |
|                  |                 |             | codeFlattenPostOrder      |
|                  |                 |             | codeFlattenPreOrder       |
|                  |                 |             | codeFlattenNth            |
|                  |                 |             | codeFlatten               |
|                  |                 |             | codeLiftSubtree           |
|                  |                 |             | codeFlattenSubtree        |
|                  |                 |             |                           |


This feels like a reasonable collection:

- codeAppend: concatenate the values of two `.code` args
- codeContainer: find a target `.code` item in another's tree, and if so return its parent
- codeContains: `true` if a target `.code` item is present in another's tree
- codeCutAtGap: convert `.code` argument to a flat Plushy, count points and gaps, and cut where indexed by an `.int`; repair both pieces with `Open` and `Close` as needed at the ends, then return
- codeCutRoot: cut the root of a `.code` item where indexed by an `'.int`
- codeDepth: maximum steps from root to leaf
- codeFlatten: flatten then entire tree of a `.code` item in post-order traversal
- codeFlattenPoint: find the indexed point in the tree and flatten that
- codeFlattenRange: find two indexed gaps in the tree, and flatten every container with one end overlapping that range; do not flatten containers that are entirely inside or outside the range
- codeGather: take two `.code` items and put them into a new one
- codeIf: pop two `.code` arguments, and send the correct one to `.exec` based on a `.bool`
- codeIndexOfPoint: if a `.code` item's contents can be found in the tree of another, return the position as an `.int` index of the point it's first found
- codeInsertAtGap: insert a second `.code` item into the tree of another, at an `.int`-indexed gap between points
- codeIsEmpty: `true` if empty
- codeIteratePoints: standard `iterate` but using every point in turn
- codeIterateRoot: standard `iterate` using root elements only
- codeLengthPoints: count of points in entire tree
- codeLengthRoot: count of points in the root
- codeNthPoint: return the indexed point
- codeNthRoot: return the indexed root element
- codeRemovePoint: delete the entire point (subtree) at the indexed location
- codeReplaceAllPoints: every place a given subtree is found in a larger tree, replace as indeicated
- codeReplaceFirstPoint: as above, but first location only (in point order)
- codeWidth: total number of leaves in the tree
- codeWrapRoot: insert `Open` and `Close` marks around a root element of the tree and rebuild
- codeWrapPoints: pick two indexed gaps; insert an `Open` at the first and a `Close` at the second, and rebuild

- codeFuncFrom_Crux: takes an item of the specified type and an `.int`, looks at its history (aka 
"crux"), and removes the indexed leaf from that tree. The result is pushed as a new `.code` item
- codeFuncFromBoolCrux
- codeFuncFromCharCrux
- codeFuncFromCodeCrux
- codeFuncFromDoubleCrux
- codeFuncFromIntCrux
- codeFuncFromStringCrux

- codeToCrux: takes a single `.code` item and rewrites it so that the internal structure is stored in post-order "runnable" mode

