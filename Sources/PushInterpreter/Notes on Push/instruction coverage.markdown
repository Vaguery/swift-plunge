#  Vector/String Instructions

Missing instructions in bold; proposed modifications and additions in the right column.

New instructions added here:
- `vec???ButLast`
- `vec???ContainsSubvec`
- `vec???IsEmpty`
- `vec???GT`
- `vec???GTE`
- `vec???LT`
- `vec???LTE`
- `stringEmptyString`
- `vec???As???s`
- `vec???replaceSubvec`
- `vec???SplitOn???`
- `stringFromNChars`
- `vec???FromN???s`
- `vec???FromRepeat`
- `vec???From???`
- `vec???cyclingSubvec`
- `stringCut`
- `vec???cut`

Nondestructive versions:
- several, but they may be pissible to work through using an interpreter behavior toggle
```
| String now              | VecInt Now               | Proposed                          |
| s---------------------t | v----------------------t | --------------------------------- |
| stringButLast           | **vecIntButLast**        | use cut?                          |
| stringConcat            | vecIntConcat             |                                   |
| stringConjChar          | vecIntConj               |                                   |
| stringContains          | **vecIntContainsSubvec** | ND version                        |
| stringContainsChar      | vecIntContains           | ND version                        |
| stringDeepDup           | vecIntDeepDup            |                                   |
| stringDrop              | vecIntDrop               | use cut?                          |
| stringDup               | vecIntDup                |                                   |
| stringDupItems          | vecIntDupItems           |                                   |
| stringDupTimes          | vecIntDupTimes           |                                   |
| stringIsEmpty           | **vecIntIsEmpty**        | ND version                        |
| **stringEmptyString**   | vecIntEmptyVector        |                                   |
| stringEq                | vecIntEq                 | ND version                        |
| stringFirst             | vecIntFirst              | use cut?                          |
| stringFlush             | vecIntFlush              |                                   |
| stringFromBool          |                          |                                   |
| stringFromChar          |                          |                                   |
| stringFromDouble        |                          |                                   |
| stringFromInt           |                          |                                   |
| stringGT                | **vecIntGT**             | ND version                        |
| stringGTE               | **vecIntGTE**            | ND version                        |
| stringIndexOfChar       | vecIntIndexOf            | ND version                        |
| stringIterate           | vecIntIterate            |                                   |
| stringLast              | vecIntLast               | use cut?                          |
| stringLength            | vecIntLength             | ND version                        |
| stringLT                | **vecIntLT**             | ND version                        |
| stringLTE               | **vecIntLTE**            | ND version                        |
| stringNth               | vecIntNth                | ND version                        |
| stringOccurrencesOfChar | vecIntOccurrencesOf      | ND version                        |
| stringParseToChars      | **vecIntAsPieces**       |                                   |
| charAllFromString       | vecIntPushAll            |                                   |
| stringPop               | vecIntPop                |                                   |
| stringRemoveChar        | vecIntRemove             | ND version                        |
| stringReplace           | **vecIntReplaceSubvec**  |                                   |
| stringReplaceChar       | vecIntReplace            |                                   |
| stringReplaceFirstChar  | vecIntReplaceFirst       |                                   |
| stringRest              | vecIntRest               | use cut?                          |
| stringReverse           | vecIntReverse            |                                   |
| stringRot               | vecIntRot                |                                   |
| stringSetChar           | vecIntSet                |                                   |
| stringShove             | vecIntShove              |                                   |
| stringSplit             | **vecIntSplitOnNeg**     |                                   |
| stringStackDepth        | vecIntStackDepth         |                                   |
| stringSubstring         | vecIntSubVec             | ND version                        |
| stringSwap              | vecIntSwap               |                                   |
| stringTake              | vecIntTake               | use cut?                          |
| stringYank              | vecIntYank               |                                   |
| stringYankDup           | vecIntYankDup            |                                   |
|                         |                          | create from N parts               |
|                         |                          | create as N copies                |
|                         |                          | create by comparison across types |
|                         |                          | create from stack                 |
|                         |                          | create by cycling small vec       |
|                         |                          | create stringCut/vecIntCut        |
|                         |                          |                                   |
`