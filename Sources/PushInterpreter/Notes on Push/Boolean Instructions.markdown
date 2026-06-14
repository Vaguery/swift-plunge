# Boolean Instruction Names

Some missing and improved names for Boolean 2-input functions.

| 00 01 10 11 | instruction  | in Propeller            |
| ----------- | ------------ | ----------------------- |
| 0  0  0  0  |              | false                   |
| 1  0  0  0  | boolNor      |                         |
| 0  1  0  0  | boolNotPandQ | boolInvertFirstThenAnd  |
| 1  1  0  0  | boolNotP     |                         |
| 0  0  1  0  | boolPandNotQ | boolInvertSecondThenAnd |
| 1  0  1  0  | boolNotQ     |                         |
| 0  1  1  0  | boolXor      | boolXor                 |
| 1  1  1  0  | boolNand     |                         |
| 0  0  0  1  | boolAnd      | boolAnd                 |
| 1  0  0  1  | boolXnor     |                         |
| 0  1  0  1  | boolQ        |                         |
| 1  1  0  1  | boolQ->P     |                         |
| 0  0  1  1  | boolP        |                         |
| 1  0  1  1  | boolP->Q     |                         |
| 0  1  1  1  | boolOr       | boolOr                  |
| 1  1  1  1  |              | true                    |
