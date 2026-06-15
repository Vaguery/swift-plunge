//
//  VecBool Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/14/26.
//

import DequeModule

extension Interpreter {
    
    static let vecBoolBehaviors: [PushInstruction : Behavior] =
    [
        // returns a new vecBool with the old value's last element removed
        // if the argument was empty, an empty vector is pushed
        .vecBoolButLast :
            Behavior(
                .vecBoolButLast,
                takes: [.vecBool],
                fxn: {a in
                    let (x) = (a[0] as! VecBoolItem)
                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(x.value.dropLast(1),
                                       call:[x, InstructionItem(.vecBoolButLast)],
                                       isContingent: Behavior.netContingency(of: x)
                                      )
                        )
                    ]
                }
            ),
        
        .vecBoolConcat :
            Behavior(
                .vecBoolConcat,
                takes: [.vecBool, .vecBool],
                fxn: {a in
                    let (x,y) = (a[0] as! VecBoolItem, a[1] as! VecBoolItem)
                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(y.value + x.value,
                                       call:[y, x, InstructionItem(.vecBoolButLast)],
                                       isContingent: Behavior.netContingency(of: x, y)
                                      )
                        )
                    ]
                }
            ),

        .vecBoolIsEmpty :
            Behavior(
                .vecBoolIsEmpty,
                takes: [.vecBool],
                fxn: {a in
                    let (x) = (a[0] as! VecBoolItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                x.value.isEmpty,
                                call:[ x, InstructionItem(.vecBoolIsEmpty)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),

        .vecBoolLength :
            Behavior(
                .vecBoolLength,
                takes: [.vecBool],
                fxn: {a in
                    let (x) = (a[0] as! VecBoolItem)
                    return [
                        Router(
                            .int,
                            IntItem(
                                x.value.count,
                                call:[ x, InstructionItem(.vecBoolLength)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),

        .vecBoolRest :
            Behavior(
                .vecBoolRest,
                takes: [.vecBool],
                fxn: {a in
                    let (x) = (a[0] as! VecBoolItem)
                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(
                                Array(x.value.dropFirst(1)),
                                call:[ x, InstructionItem(.vecBoolRest)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),

        .vecBoolReverse :
            Behavior(
                .vecBoolReverse,
                takes: [.vecBool],
                fxn: {a in
                    let (x) = (a[0] as! VecBoolItem)
                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(
                                Array(x.value.reversed() ),
                                call:[ x, InstructionItem(.vecBoolReverse)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),


        .vecBoolTake :
            Behavior(
                .vecBoolTake,
                takes: [.vecBool, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! VecBoolItem, a[1] as! IntItem)
                    let range = x.value.count
                    let idx = range - (min(range, max(y.value,0)))
                    let result = Array(x.value.dropLast(idx))

                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(
                                result,
                                call:[ x, y, InstructionItem(.vecBoolTake)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecBoolDrop :
            Behavior(
                .vecBoolDrop,
                takes: [.vecBool, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! VecBoolItem, a[1] as! IntItem)
                    let range = x.value.count
                    let idx = (min(range, max(y.value,0)))
                    let result = Array(x.value.dropFirst(idx))

                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(
                                result,
                                call:[ x, y, InstructionItem(.vecBoolDrop)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecBoolConj :
            Behavior(
                .vecBoolConj,
                takes: [.vecBool, .bool],
                fxn: {a in
                    let (x,y) = (a[0] as! VecBoolItem, a[1] as! BoolItem)
                    var result = x.value
                    result.append(y.value)
                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(
                                result,
                                call:[ x, y, InstructionItem(.vecBoolConj)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecBoolContains :
            Behavior(
                .vecBoolContains,
                takes: [.vecBool, .bool],
                fxn: {a in
                    let (x,y) = (a[0] as! VecBoolItem, a[1] as! BoolItem)
                    var result = x.value.contains(y.value)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                result,
                                call:[ x, y, InstructionItem(.vecBoolContains)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecBoolFirst :
            Behavior(
                .vecBoolFirst,
                takes: [.vecBool],
                fxn: {a in
                    let (x) = (a[0] as! VecBoolItem)
                    if let result = x.value.first {
                        return [
                            Router(
                                .bool,
                                BoolItem(
                                    result,
                                    call:[ x, InstructionItem(.vecBoolFirst)],
                                    isContingent: Behavior.netContingency(of: x)
                                )
                            )
                        ]
                    } else {
                        return []
                    }
                }
            ),

        .vecBoolLast :
            Behavior(
                .vecBoolLast,
                takes: [.vecBool],
                fxn: {a in
                    let (x) = (a[0] as! VecBoolItem)
                    if let result = x.value.last {
                        return [
                            Router(
                                .bool,
                                BoolItem(
                                    result,
                                    call:[ x, InstructionItem(.vecBoolLast)],
                                    isContingent: Behavior.netContingency(of: x)
                                )
                            )
                        ]
                    } else {
                        return []
                    }
                }
            ),
    
        .vecBoolNth :
            Behavior(
                .vecBoolNth,
                takes: [.vecBool, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! VecBoolItem, a[1] as! IntItem)
                    let range = x.value.count
                    if range == 0 {
                        return []
                    } else {
                        let position = abs(y.value)
                        let idx = position % range
                        let result = x.value[idx]
                        return [
                            Router(
                                .bool,
                                BoolItem(
                                    result,
                                    call:[ x, y, InstructionItem(.vecBoolNth)],
                                    isContingent: Behavior.netContingency(of: x, y)
                                )
                            )
                        ]
                    }
                }
            ),

        
        .vecBoolIndexOf :
            Behavior(
                .vecBoolIndexOf,
                takes: [.vecBool, .bool],
                fxn: {a in
                    let (x,y) = (a[0] as! VecBoolItem, a[1] as! BoolItem)
                    var result:Int? = nil
                    if x.value.isEmpty == true {
                        return []
                    } else {
                        if let idx = x.value.firstIndex(of: y.value) {
                            result = idx
                        }
                    }
                    if result != nil {
                        return [
                            Router(
                                .int,
                                IntItem(
                                    result!,
                                    call:[ x, y, InstructionItem(.vecBoolIndexOf)],
                                    isContingent: Behavior.netContingency(of: x, y)
                                )
                            )
                        ]
                    } else {
                        return []
                    }
                }
            ),
        
        .vecBoolOccurrencesOf :
            Behavior(
                .vecBoolOccurrencesOf,
                takes: [.vecBool, .bool],
                fxn: {a in
                    let (x,y) = (a[0] as! VecBoolItem, a[1] as! BoolItem)
                    let result = x.value.count(where: {$0 == (y.value)})
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call:[ x, y, InstructionItem(.vecBoolOccurrencesOf)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        
        .vecBoolRemove :
            Behavior(
                .vecBoolRemove,
                takes: [.vecBool, .bool],
                fxn: {a in
                    let (x,y) = (a[0] as! VecBoolItem, a[1] as! BoolItem)
                    var result = x.value
                    result.removeAll(where: {$0 == (y.value)})
                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(
                                result,
                                call:[ x, y, InstructionItem(.vecBoolRemove)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),
        
        // ( [1,2,3] 2 9 .vecBoolReplace)
        //
        // replace every occurrence of 2 in the argument (above) with 9
        //
        .vecBoolReplace :
            Behavior(
                .vecBoolReplace,
                takes: [.vecBool, .bool, .bool],
                fxn: {a in
                    let (x, y, z) = (a[0] as! VecBoolItem,
                                     a[1] as! BoolItem,
                                     a[2] as! BoolItem)
                    let result = x.value.map({$0 == z.value ? y.value : $0})
                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(
                                result,
                                call:[ x, z, y, InstructionItem(.vecBoolReplace)],
                                isContingent: Behavior.netContingency(of: x, y, z)
                            )
                        )
                    ]
                }
            ),
        
        // ( [1,1,2,3] 1 9 .vecBoolReplace)
        //
        // replace the first occurrence of 1 in the argument (above) with 9
        //
        .vecBoolReplaceFirst :
            Behavior(
                .vecBoolReplaceFirst,
                takes: [.vecBool, .bool, .bool],
                fxn: {a in
                    let (x, y, z) = (a[0] as! VecBoolItem,
                                     a[1] as! BoolItem,
                                     a[2] as! BoolItem)
                    var result = x.value
                    if let idx = result.firstIndex(where: {$0 == z.value}) {
                        result[idx] = y.value
                    }
                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(
                                result,
                                call:[ x, z, y, InstructionItem(.vecBoolReplaceFirst)],
                                isContingent: Behavior.netContingency(of: x, y, z)
                            )
                        )
                    ]
                }
            ),
        
        // ( [1,1,2,3] 1 9 .vecBoolSet)
        //
        // replace the element at position 1 in the argument (above) with 9
        //
        .vecBoolSet :
            Behavior(
                .vecBoolSet,
                takes: [.vecBool, .int, .bool],
                fxn: {a in
                    let (x, y, z) = (a[0] as! VecBoolItem,
                                     a[1] as! IntItem,
                                     a[2] as! BoolItem)
                    var result = x.value
                    if result.count > 0 {
                        let idx = abs(y.value) % (result.count)
                        result[idx] = z.value
                    }
                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(
                                result,
                                call:[ x, z, y, InstructionItem(.vecBoolSet)],
                                isContingent: Behavior.netContingency(of: x, y, z)
                            )
                        )
                    ]
                }
            ),
        
        // ( [1,1,2,3] 1 2 .vecBoolSubVec)
        //
        // return a stretch of the original vector from positions 1...2
        // if idx1 is negative, make it zero
        // if idx2 < idx1, return an empty vector
        
        //
        .vecBoolSubVec :
            Behavior(
                .vecBoolSubVec,
                takes: [.vecBool, .int, .int],
                fxn: {a in
                    let (x, y, z) = (a[0] as! VecBoolItem,
                                     a[1] as! IntItem,
                                     a[2] as! IntItem)
                    var result = x.value
                    
                    if result.count > 0 {
                        let range = result.count - 1
                        let lhs = min(range , max(0 , z.value))
                        let rhs = min(range , max(0 , z.value , y.value))
                        result = Array( result[lhs...rhs] )
                    }
                    return [
                        Router(
                            .vecBool,
                            VecBoolItem(
                                result,
                                call: [ x, z, y, InstructionItem(.vecBoolSubVec)],
                                isContingent: Behavior.netContingency(of: x, y, z)
                            )
                        )
                    ]
                }
            ),
        
        
        // ( [1,1,2,3] .vecBoolPushAll)
        //
        // return every item on the argument (in reverse order)
        // routing them to the correct stack
        //
        .vecBoolPushAll :
            Behavior(
                .vecBoolPushAll,
                takes: [.vecBool],
                fxn: {a in
                    let (x) = (a[0] as! VecBoolItem)
                    var results = [Router]()
                    let backwards = Array(x.value.reversed())
                    for idx in 0 ..< backwards.count {
                        results.append(
                            Router(
                                .bool,
                                BoolItem(
                                    backwards[idx],
                                    call: [x, InstructionItem(.vecBoolPushAll)],
                                    isContingent: Behavior.netContingency(of: x),
                                    index: backwards.count - idx - 1
                                    )
                                )
                            )
                    }
                    return results
                }
            ),
            
        
        
        // ( [1,1,2,3] .vecBoolIterate MOUSE )
        //
        //               4          3            2                   1         0
        // reults: ( exec:MOUSE exec:remains exec:.vecBoolIterate exec:MOUSE int:CHEESE )
        //
        
        .vecBoolIterate :
            Behavior(
                .vecBoolIterate,
                takes: [.vecBool, .exec],
                fxn: {a in
                    let (x, y) = ( a[0] as! VecBoolItem, a[1] )
                    var results = [Router]()
                    var workingVector = x.value
                    
                    var mouseCopy = a[1]
                    let count = workingVector.count
                    if count > 0 {
                        mouseCopy.index = 1
                        results.append( Router( .exec, mouseCopy)) //1
                        
                        let item = workingVector.removeFirst()
                        results.append(
                            Router(
                                .bool,
                                BoolItem(item,
                                        call: [x, InstructionItem(.vecBoolIterate), y],
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
                                        .vecBoolIterate,
                                        call: [x, InstructionItem(.vecBoolIterate), y],
                                        isContingent: Behavior.netContingency(of: x, y),
                                        index: 2
                                    )))
                            results.append(
                                Router(.exec,
                                       VecBoolItem(workingVector, // which was changed
                                                  call: [x, InstructionItem(.vecBoolIterate), y],
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
        
    ]
}

