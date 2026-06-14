#  Vector/String Instructions

Missing instructions in bold; proposed modifications and additions in the right column.

| String now              | VecInt Now               | Proposed                          |
| s---------------------t | v----------------------t | --------------------------------- |
| stringButLast           | **vecIntButLast**        | use split?                        |
| **stringButFirst**      | **vecIntButFirst**       | use split?                        |
| stringConcat            | vecIntConcat             |                                   |
| stringConjChar          | vecIntConj               |                                   |
| stringContains          | **vecIntContainsSubvec** | ND version                        |
| stringContainsChar      | vecIntContains           | ND version                        |
| stringDeepDup           | vecIntDeepDup            |                                   |
| stringDrop              | vecIntDrop               | use split?                        |
| stringDup               | vecIntDup                |                                   |
| stringDupItems          | vecIntDupItems           |                                   |
| stringDupTimes          | vecIntDupTimes           |                                   |
| stringIsEmpty           | **vecIntIsEmpty**        | ND version                        |
| **stringEmpty**         | vecIntEmptyVector        |                                   |
| stringEq                | vecIntEq                 | ND version                        |
| stringFirst             | vecIntFirst              | use split?                        |
| stringFlush             | vecIntFlush              |                                   |
| stringFromBool          |                          |                                   |
| stringFromChar          |                          |                                   |
| stringFromDouble        |                          |                                   |
| stringFromInt           |                          |                                   |
| stringGT                | **vecIntGT**             | ND version                        |
| stringGTE               | **vecIntGTE**            | ND version                        |
| stringIndexOfChar       | vecIntIndexOf            | ND version                        |
| stringIterate           | vecIntIterate            |                                   |
| stringLast              | vecIntLast               | use split?                        |
| stringLength            | vecIntLength             | ND version                        |
| stringLT                | **vecIntLT**             | ND version                        |
| stringLTE               | **vecIntLTE**            | ND version                        |
| stringNth               | vecIntNth                | ND version                        |
| stringOccurrencesOfChar | vecIntOccurrencesOf      | ND version                        |
| stringParseToChars      | vecIntPushAll            |                                   |
| stringPop               | vecIntPop                |                                   |
| stringRemoveChar        | vecIntRemove             | ND version                        |
| stringReplace           | **vecIntReplaceSubvec**  |                                   |
| stringReplaceChar       | vecIntReplace            |                                   |
| stringReplaceFirstChar  | vecIntReplaceFirst       |                                   |
| stringRest              | vecIntRest               | use split?                        |
| stringReverse           | vecIntReverse            |                                   |
| stringRot               | vecIntRot                |                                   |
| stringSetChar           | vecIntSet                |                                   |
| stringShove             | vecIntShove              |                                   |
| stringSplit             | **vecIntSplit**          |                                   |
| stringStackDepth        | vecIntStackDepth         |                                   |
| stringSubstring         | vecIntSubVec             | ND version                        |
| stringSwap              | vecIntSwap               |                                   |
| stringTake              | vecIntTake               | use split?                        |
| stringYank              | vecIntYank               |                                   |
| stringYankDup           | vecIntYankDup            |                                   |
|                         |                          | create from N parts               |
|                         |                          | create as N repeats               |
|                         |                          | create by comparison across types |
|                         |                          | create from stack                 |
|                         |                          | create by cycling small vec       |
|                         |                          |                                   |
