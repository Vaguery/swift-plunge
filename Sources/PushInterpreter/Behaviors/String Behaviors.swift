////
////  String Behaviors.swift
////  Propeller in Swift
////
////  Created by William Tozier on 5/9/26.
////

import DequeModule


extension Interpreter {
                
    static let stringBehaviors:[PushInstruction : Behavior] =
       [
        
        .stringButLast :
            Behavior(
                .stringButLast,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                String(x.value.dropLast(1)),
                                call:[x, InstructionItem(.stringButLast)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),

        .stringConcat :
            Behavior(
                .stringConcat,
                takes: [.string, .string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                y.value + x.value,
                                call:[y, x, InstructionItem(.stringConcat)],
                                isContingent: Behavior.netContingency(of: x,y )
                            )
                        )
                    ]
                }
            ),
        
        .stringConjChar :
            Behavior(
                .stringConjChar,
                takes: [.string, .char],
                fxn: {a in
                    let (y,x) = (a[0] as! StringItem, a[1] as! CharItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                y.value + String(x.value),
                                call:[y, x, InstructionItem(.stringConjChar)],
                                isContingent: Behavior.netContingency(of: x,y )
                            )
                        )
                    ]
                }
            ),
        
        .stringContains :
            Behavior(
                .stringContains,
                takes: [.string, .string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                y.value.contains(x.value),
                                call:[y, x, InstructionItem(.stringContains)],
                                isContingent: Behavior.netContingency(of: x,y )
                            )
                        )
                    ]
                }
            ),
        
        .stringContainsChar :
            Behavior(
                .stringContainsChar,
                takes: [.string, .char],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! CharItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                x.value.contains(y.value),
                                call:[y, x, InstructionItem(.stringContainsChar)],
                                isContingent: Behavior.netContingency(of: x,y )
                            )
                        )
                    ]
                }
            ),
        
        .stringIndexOfChar :
            Behavior(
                .stringIndexOfChar,
                takes: [.string, .char],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! CharItem)
                    if let idx = x.value.firstIndex(of: y.value) {
                        let intIdx = x.value.distance(from: x.value.startIndex, to: idx)
                        return [
                            Router(
                                .int,
                                IntItem(
                                    intIdx,
                                    call: [y, x, InstructionItem(.stringIndexOfChar)],
                                    isContingent: Behavior.netContingency(of: x,y )
                                    )
                                )
                            ]
                    } else {
                        return []  // not found
                    }
                }
            ),

        // the IntItem value is truncated at 0 before use as an index
        //
        .stringDrop :
            Behavior(
                .stringDrop,
                takes: [.string, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! IntItem)
                    let toDrop = max(0,y.value)
                    return [
                        Router(
                            .string,
                            StringItem(
                                String(x.value.dropLast(toDrop)),
                                call: [y, x, InstructionItem(.stringDrop)],
                                isContingent: Behavior.netContingency(of: x,y )
                            )
                        )
                    ]
                }
            ),

        
        // the IntItem value is truncated at 0 before use as an index
        //
        .stringTake :
            Behavior(
                .stringTake,
                takes: [.string, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! IntItem)
                    let toTake = max(0,y.value)
                    return [
                        Router(
                            .string,
                            StringItem(
                                String(x.value.prefix(toTake)),
                                call: [y, x, InstructionItem(.stringTake)],
                                isContingent: Behavior.netContingency(of: x, y )
                            )
                        )
                    ]
                }
            ),

        .stringIsEmpty :
            Behavior(
                .stringIsEmpty,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                x.value.isEmpty,
                                call: [x, InstructionItem(.stringIsEmpty)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),
        
        .stringFirst :
            Behavior(
                .stringFirst,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    if let c = x.value.first {
                        return [
                            Router(
                                .char,
                                CharItem(
                                    c,
                                    call: [x, InstructionItem(.stringFirst)],
                                    isContingent: Behavior.netContingency(of: x )
                                    )
                                )
                            ]
                    } else {
                        return []  // empty string
                    }
                }
            ),

    
        .stringLast :
            Behavior(
                .stringLast,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    if let c = x.value.last {
                        return [
                            Router(
                                .char,
                                CharItem(
                                    c,
                                    call: [x, InstructionItem(.stringLast)],
                                    isContingent: Behavior.netContingency(of: x )
                                    )
                                )
                            ]
                    } else {
                        return []  // empty string
                    }
                }
            ),

        .stringLTE :
            Behavior(
                .stringLTE,
                takes: [.string,.string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                y <= x,
                                call: [y, x, InstructionItem(.stringLTE)],
                                isContingent: Behavior.netContingency(of: x, y )
                            )
                        )
                    ]
                }
            ),

        .stringLT :
            Behavior(
                .stringLT,
                takes: [.string,.string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                y < x,
                                call: [y, x, InstructionItem(.stringLT)],
                                isContingent: Behavior.netContingency(of: x, y )
                            )
                        )
                    ]
                }
            ),

    
        .stringGT :
            Behavior(
                .stringGT,
                takes: [.string,.string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                y > x,
                                call: [y, x, InstructionItem(.stringGT)],
                                isContingent: Behavior.netContingency(of: x, y )
                            )
                        )
                    ]
                }
            ),

        .stringGTE :
            Behavior(
                .stringGTE,
                takes: [.string,.string],
                fxn: {a in
                    let (x,y) = (a[0] as! StringItem, a[1] as! StringItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                y >= x,
                                call: [y, x, InstructionItem(.stringGTE)],
                                isContingent: Behavior.netContingency(of: x, y )
                            )
                        )
                    ]
                }
            ),
        
        
        .stringReverse :
            Behavior(
                .stringReverse,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                String(x.value.reversed() ),
                                call: [ x, InstructionItem(.stringReverse)],
                                isContingent: Behavior.netContingency(of: x, )
                            )
                        )
                    ]
                }
            ),
        
        .stringLength :
            Behavior(
                .stringLength,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    return [
                        Router(
                            .int,
                            IntItem(
                                x.value.count,
                                call: [ x, InstructionItem(.stringLength)],
                                isContingent: Behavior.netContingency(of: x, )
                            )
                        )
                    ]
                }
            ),
        
        .stringFromBool :
            Behavior(
                .stringFromBool,
                takes: [.bool],
                fxn: {a in
                    let (x) = (a[0] as! BoolItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                "\(x.value)",
                                call: [ x, InstructionItem(.stringFromBool)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),
        
        .stringFromChar :
            Behavior(
                .stringFromChar,
                takes: [.char],
                fxn: {a in
                    let (x) = (a[0] as! CharItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                "\(x.value)",
                                call: [ x, InstructionItem(.stringFromChar)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),
        
        .stringFromDouble :
            Behavior(
                .stringFromDouble,
                takes: [.double],
                fxn: {a in
                    let (x) = (a[0] as! DoubleItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                "\(x.value)",
                                call: [ x, InstructionItem(.stringFromDouble)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),
        
        .stringFromInt :
            Behavior(
                .stringFromInt,
                takes: [.int],
                fxn: {a in
                    let (x) = (a[0] as! IntItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                "\(x.value)",
                                call: [ x, InstructionItem(.stringFromInt)],
                                isContingent: Behavior.netContingency(of: x )
                            )
                        )
                    ]
                }
            ),
        
        .stringNth :
            Behavior(
                .stringNth,
                takes: [.string, .int],
                fxn: {a in
                    let (x, y) = (a[0] as! StringItem, a[1] as! IntItem)
                    if x.value.isEmpty {
                        return []
                    } else {
                        let moduloIdx = (max(0,y.value) % x.value.count)
                        let idx = x.value.index(x.value.startIndex, offsetBy: moduloIdx)
                        let c = x.value[idx]
                        return [
                            Router(
                                .char,
                                CharItem(
                                    c,
                                    call: [ y, x, InstructionItem(.stringNth)],
                                    isContingent: Behavior.netContingency(of: x, y )
                                )
                            )
                        ]
                    }
                }
            ),

        // produces one substring of one character each for every character in the string
        // the stack will read backwards vs the order in the string
        //
        .stringParseToLetters :
            Behavior(
                .stringParseToLetters,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    let chars = x.value.split(separator: "")
                    var results : [Router] = []
                    for (idx, c) in chars.enumerated() {
                        results.append(
                            Router(
                                .string,
                                StringItem(
                                    String(c),
                                    call: [ x, InstructionItem(.stringParseToLetters)],
                                    isContingent: Behavior.netContingency(of: x ),
                                    index: idx
                                )
                            )
                        )
                    }
                    return results
                }
            ),

        .stringOccurrencesOfChar :
            Behavior(
                .stringOccurrencesOfChar,
                takes: [.string, .char],
                fxn: {a in
                    let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                    return [
                        Router(
                            .int,
                            IntItem(
                                x.value.filter({ $0 == y.value }).count,
                                call: [ y, x, InstructionItem(.stringOccurrencesOfChar)],
                                isContingent: Behavior.netContingency(of: x, y ),
                            )
                        )
                    ]
                }
            ),

        .stringRemoveChar :
            Behavior(
                .stringRemoveChar,
                takes: [.string, .char],
                fxn: {a in
                    let (x, y) = (a[0] as! StringItem, a[1] as! CharItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                x.value.filter({ $0 != y.value }),
                                call: [ y, x, InstructionItem(.stringRemoveChar)],
                                isContingent: Behavior.netContingency(of: x, y ),
                            )
                        )
                    ]
                }
            ),
        
        
        // ( "0123" '2' '.' .stringReplaceChar ) -> "01.3"
        //
        .stringReplaceChar :
            Behavior(
                .stringReplaceChar,
                takes: [.string, .char, .char],
                fxn: {a in
                    let (x, y, z) = (a[0] as! StringItem,
                                     a[1] as! CharItem,
                                     a[2] as! CharItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                x.value.replacing(String(z.value), with: String(y.value)),
                                call: [z, y, x, InstructionItem(.stringRemoveChar)],
                                isContingent: Behavior.netContingency(of: x, y, z),
                            )
                        )
                    ]
                }
            ),
        
        .stringReplaceFirstChar :
            Behavior(
                .stringReplaceFirstChar,
                takes: [.string, .char, .char],
                fxn: {a in
                    let (x, y, z) = (a[0] as! StringItem,
                                     a[1] as! CharItem,
                                     a[2] as! CharItem)
                    return [
                        Router(
                            .string,
                            StringItem(
                                x.value.replacing(String(z.value), with: String(y.value), maxReplacements: 1),
                                call: [z, y, x, InstructionItem(.stringReplaceFirstChar)],
                                isContingent: Behavior.netContingency(of: x, y, z),
                            )
                        )
                    ]
                }
            ),
        
        
        
        // ("foo" "o" "g" .stringReplace) -> "fgg"
        //
        .stringReplace :
            Behavior(
                .stringReplace,
                takes: [.string, .string, .string],
                fxn: {a in
                    let (x, y, z) = (a[0] as! StringItem, // replacement
                                     a[1] as! StringItem, // target
                                     a[2] as! StringItem) // in this context
                    return [
                        Router(
                            .string,
                            StringItem(
                                z.value.replacing(y.value, with: x.value),
                                call: [z, y, x, InstructionItem(.stringReplace)],
                                isContingent: Behavior.netContingency(of: x, y, z),
                            )
                        )
                    ]
                }
            ),
        
        .stringReplaceFirst :
            Behavior(
                .stringReplaceFirst,
                takes: [.string, .string, .string],
                fxn: {a in
                    let (x, y, z) = (a[0] as! StringItem, // replacement
                                     a[1] as! StringItem, // target
                                     a[2] as! StringItem) // in this context
                    return [
                        Router(
                            .string,
                            StringItem(
                                z.value.replacing(y.value, with: x.value, maxReplacements: 1),
                                call: [z, y, x, InstructionItem(.stringReplace)],
                                isContingent: Behavior.netContingency(of: x, y, z),
                            )
                        )
                    ]
                }
            ),
        
        .stringRest :
            Behavior(
                .stringRest,
                takes: [.string],
                fxn: {a in
                    var (x) = (a[0] as! StringItem)
                    let result = String(x.value.dropFirst(1))
                    return [
                        Router(
                            .string,
                            StringItem(
                                result,
                                call: [ x, InstructionItem(.stringRest)],
                                isContingent: Behavior.netContingency(of: x),
                            )
                        )
                    ]
                }
            ),

        .stringSetChar :
            Behavior(
                .stringSetChar,
                takes: [.string, .int, .char],
                fxn: {a in
                    var (x, y, z) = (a[0] as! StringItem,
                                     a[1] as! IntItem,
                                     a[2] as! CharItem)
                    var result = x.value
                    if result.count > 0 {
                        let moduloIdx = (max(0,y.value) % result.count)
                        let idx = result.index(result.startIndex, offsetBy: moduloIdx)
                        result.replaceSubrange(idx...idx, with: String(z.value))
                    }
                    return [
                        Router(
                            .string,
                            StringItem(
                                result,
                                call: [z, y, x, InstructionItem(.stringSetChar)],
                                isContingent: Behavior.netContingency(of: x,y,z)
                            )
                        )
                    ]
                }
            ),

        // returns every substring delimited by whitespace, if any
        // unlike stringButLast, which always returns a string, this might not return anything
        //
        .stringSplit :
            Behavior(
                .stringSplit,
                takes: [.string],
                fxn: {a in
                    let (x) = (a[0] as! StringItem)
                    var result = [Router]()
                    let chunks = x.value.split {$0.isWhitespace }
                    for (idx, chunk) in chunks.enumerated() {
                        result.append(
                            Router(
                                .string,
                                StringItem(
                                    String(chunk),
                                    call: [x, InstructionItem(.stringSplit)],
                                    isContingent: Behavior.netContingency(of: x),
                                    index: idx
                                )
                            )
                        )
                    }
                    return result
                }
            ),

        .stringSubstring :
            Behavior(
                .stringSubstring,
                takes: [.string, .int, .int],
                fxn: {a in
                    let (x,y,z) = (a[0] as! StringItem,
                                     a[1] as! IntItem,
                                     a[2] as! IntItem)
                    
                    var result = x.value
                    var slice = Substring(result)
                    if result.count > 0 {
                        let range = result.count - 1
                        let lhs = min(range , max(0 , z.value))
                        let rhs = min(range , max(0 , z.value , y.value))
                        let start = result.index(result.startIndex, offsetBy: lhs)
                        let end = result.index(result.startIndex, offsetBy: rhs)
                        slice = result[start...end]
                    }
                    return [
                        Router(
                            .string,
                            StringItem(
                                String(slice),
                                call: [ x, z, y, InstructionItem(.stringSubstring)],
                                isContingent: Behavior.netContingency(of: x, y, z)
                            )
                        )
                    ]
                }
            ),

        // ( "abcd" .stringIterate MOUSE )
        //
        // index:        4          3          2                   1          0
        // reults: ( exec:MOUSE exec:"bcd" exec:.stringIterate exec:MOUSE char:'a' )
        //
        // TODO: explain what THE MOUSE is
        
        .stringIterate :
            Behavior(
                .stringIterate,
                takes: [.string, .exec],
                fxn: {a in
                    let (x, y) = ( a[0] as! StringItem, a[1] )
                    var results = [Router]()
                    var workingString = x.value
                    
                    var mouseCopy = a[1]
                    let count = workingString.count
                    if count > 0 {
                        mouseCopy.index = 1
                        results.append( Router( .exec, mouseCopy)) //1
                        
                        let item = workingString.removeFirst()
                        results.append(
                            Router(
                                .char,
                                CharItem(item,
                                        call: [x, InstructionItem(.stringIterate), y],
                                        isContingent: Behavior.netContingency(of: x, y),
                                        index: 0
                                       )
                            )
                        )
                        if count > 1 {
                            results.append(
                                Router(
                                    .exec,
                                    InstructionItem(
                                        .stringIterate,
                                        call: [x, InstructionItem(.stringIterate), y],
                                        isContingent: Behavior.netContingency(of: x, y),
                                        index: 2
                                    )))
                            results.append(
                                Router(.exec,
                                       StringItem(workingString, // which was changed
                                                  call: [x, InstructionItem(.stringIterate), y],
                                                  isContingent: Behavior.netContingency(of: x, y),
                                                  index: 3
                                                 )
                                      )
                            )
                            mouseCopy.index = 4
                            results.append( Router( .exec, mouseCopy )) //4
                        }
                    }
                    return results
                }
            ),

        .stringPushAllChars : Behavior(
            .stringPushAllChars,
            takes: [.string],
            fxn: {a in
                let (s) = (a[0] as! StringItem)
                
                var results = [Router]()
                if s.value.count > 0 {
                    let chars = Array(s.value)
                    for (idx,char) in chars.enumerated() {
                        results.append(
                            Router(
                                .char,
                                CharItem(char,
                                         call: [s, InstructionItem(.stringPushAllChars)],
                                         isContingent: Behavior.netContingency(of: s),
                                         index: idx
                                        )
                            )
                        )
                    }
                }
                return results
            }
        ),
            


        ]
}
