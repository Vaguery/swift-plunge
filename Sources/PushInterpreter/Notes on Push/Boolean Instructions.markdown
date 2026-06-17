# Boolean Instruction Names


Some missing and improved names for Boolean 2-input functions.

|  11 10 01 00  | instruction  | in Propeller            |
|  -----------  | ------------ | ----------------------- |
|  0  0  0  0   |              | false                   |
|  0  0  0  1   | boolNor      |                         |
|  0  0  1  0   | boolNotPandQ | boolInvertFirstThenAnd  |
|  0  0  1  1   | boolNotP     |                         |
|  0  1  0  0   | boolPandNotQ | boolInvertSecondThenAnd |
|  0  1  0  1   | boolNotQ     |                         |
|  0  1  1  0   | boolXor      | boolXor                 |
|  0  1  1  1   | boolNand     |                         |
|  1  0  0  0   | boolAnd      | boolAnd                 |
|  1  0  0  1   | boolXnor     |                         |
|  1  0  1  0   | boolQ        |                         |
|  1  0  1  1   | boolQcondP   |                         |
|  1  1  0  0   | boolP        |                         |
|  1  1  0  1   | boolPcondQ   |                         |
|  1  1  1  0   | boolOr       | boolOr                  |
|  1  1  1  1   |              | true                    |

