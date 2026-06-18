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