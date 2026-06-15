//
//  VecDouble Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/14/26.
//

import DequeModule

extension Interpreter {
    
    static let vecDoubleBehaviors: [PushInstruction : Behavior] =
    [
        // returns a new vecDouble with the old value's last element removed
        // if the argument was empty, an empty vector is pushed
        .vecDoubleButLast :
            Behavior(
                .vecDoubleButLast,
                takes: [.vecDouble],
                fxn: {a in
                    let (x) = (a[0] as! VecDoubleItem)
                    return [
                        Router(
                            .vecDouble,
                            VecDoubleItem(x.value.dropLast(1),
                                       call:[x, InstructionItem(.vecDoubleButLast)],
                                       isContingent: Behavior.netContingency(of: x)
                                      )
                        )
                    ]
                }
            ),
        
        .vecDoubleConcat :
            Behavior(
                .vecDoubleConcat,
                takes: [.vecDouble, .vecDouble],
                fxn: {a in
                    let (x,y) = (a[0] as! VecDoubleItem, a[1] as! VecDoubleItem)
                    return [
                        Router(
                            .vecDouble,
                            VecDoubleItem(y.value + x.value,
                                       call:[y, x, InstructionItem(.vecDoubleButLast)],
                                       isContingent: Behavior.netContingency(of: x, y)
                                      )
                        )
                    ]
                }
            ),

        .vecDoubleIsEmpty :
            Behavior(
                .vecDoubleIsEmpty,
                takes: [.vecDouble],
                fxn: {a in
                    let (x) = (a[0] as! VecDoubleItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                x.value.isEmpty,
                                call:[ x, InstructionItem(.vecDoubleIsEmpty)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),

        .vecDoubleLength :
            Behavior(
                .vecDoubleLength,
                takes: [.vecDouble],
                fxn: {a in
                    let (x) = (a[0] as! VecDoubleItem)
                    return [
                        Router(
                            .int,
                            IntItem(
                                x.value.count,
                                call:[ x, InstructionItem(.vecDoubleLength)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),

        .vecDoubleRest :
            Behavior(
                .vecDoubleRest,
                takes: [.vecDouble],
                fxn: {a in
                    let (x) = (a[0] as! VecDoubleItem)
                    return [
                        Router(
                            .vecDouble,
                            VecDoubleItem(
                                Array(x.value.dropFirst(1)),
                                call:[ x, InstructionItem(.vecDoubleRest)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),

        .vecDoubleReverse :
            Behavior(
                .vecDoubleReverse,
                takes: [.vecDouble],
                fxn: {a in
                    let (x) = (a[0] as! VecDoubleItem)
                    return [
                        Router(
                            .vecDouble,
                            VecDoubleItem(
                                Array(x.value.reversed() ),
                                call:[ x, InstructionItem(.vecDoubleReverse)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),


        .vecDoubleTake :
            Behavior(
                .vecDoubleTake,
                takes: [.vecDouble, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! VecDoubleItem, a[1] as! IntItem)
                    let range = x.value.count
                    let idx = range - (min(range, max(y.value,0)))
                    let result = Array(x.value.dropLast(idx))

                    return [
                        Router(
                            .vecDouble,
                            VecDoubleItem(
                                result,
                                call:[ x, y, InstructionItem(.vecDoubleTake)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecDoubleDrop :
            Behavior(
                .vecDoubleDrop,
                takes: [.vecDouble, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! VecDoubleItem, a[1] as! IntItem)
                    let range = x.value.count
                    let idx = (min(range, max(y.value,0)))
                    let result = Array(x.value.dropFirst(idx))

                    return [
                        Router(
                            .vecDouble,
                            VecDoubleItem(
                                result,
                                call:[ x, y, InstructionItem(.vecDoubleDrop)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecDoubleConj :
            Behavior(
                .vecDoubleConj,
                takes: [.vecDouble, .double],
                fxn: {a in
                    let (x,y) = (a[0] as! VecDoubleItem, a[1] as! DoubleItem)
                    var result = x.value
                    result.append(y.value)
                    return [
                        Router(
                            .vecDouble,
                            VecDoubleItem(
                                result,
                                call:[ x, y, InstructionItem(.vecDoubleConj)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecDoubleContains :
            Behavior(
                .vecDoubleContains,
                takes: [.vecDouble, .double],
                fxn: {a in
                    let (x,y) = (a[0] as! VecDoubleItem, a[1] as! DoubleItem)
                    var result = x.value.contains(y.value)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                result,
                                call:[ x, y, InstructionItem(.vecDoubleContains)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecDoubleFirst :
            Behavior(
                .vecDoubleFirst,
                takes: [.vecDouble],
                fxn: {a in
                    let (x) = (a[0] as! VecDoubleItem)
                    if let result = x.value.first {
                        return [
                            Router(
                                .double,
                                DoubleItem(
                                    result,
                                    call:[ x, InstructionItem(.vecDoubleFirst)],
                                    isContingent: Behavior.netContingency(of: x)
                                )
                            )
                        ]
                    } else {
                        return []
                    }
                }
            ),

        .vecDoubleLast :
            Behavior(
                .vecDoubleLast,
                takes: [.vecDouble],
                fxn: {a in
                    let (x) = (a[0] as! VecDoubleItem)
                    if let result = x.value.last {
                        return [
                            Router(
                                .double,
                                DoubleItem(
                                    result,
                                    call:[ x, InstructionItem(.vecDoubleLast)],
                                    isContingent: Behavior.netContingency(of: x)
                                )
                            )
                        ]
                    } else {
                        return []
                    }
                }
            ),
    
        .vecDoubleNth :
            Behavior(
                .vecDoubleNth,
                takes: [.vecDouble, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! VecDoubleItem, a[1] as! IntItem)
                    let range = x.value.count
                    if range == 0 {
                        return []
                    } else {
                        let position = abs(y.value)
                        let idx = position % range
                        let result = x.value[idx]
                        return [
                            Router(
                                .double,
                                DoubleItem(
                                    result,
                                    call:[ x, y, InstructionItem(.vecDoubleNth)],
                                    isContingent: Behavior.netContingency(of: x, y)
                                )
                            )
                        ]
                    }
                }
            ),

        
        .vecDoubleIndexOf :
            Behavior(
                .vecDoubleIndexOf,
                takes: [.vecDouble, .double],
                fxn: {a in
                    let (x,y) = (a[0] as! VecDoubleItem, a[1] as! DoubleItem)
                    var result:Int? = nil
                    if let idx = x.value.firstIndex(of: y.value) {
                        result = idx
                    } else {
                        result = -1
                    }
                    return [
                        Router(
                            .int,
                            IntItem(
                                result!,
                                call:[ x, y, InstructionItem(.vecDoubleIndexOf)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),
        
        .vecDoubleOccurrencesOf :
            Behavior(
                .vecDoubleOccurrencesOf,
                takes: [.vecDouble, .double],
                fxn: {a in
                    let (x,y) = (a[0] as! VecDoubleItem, a[1] as! DoubleItem)
                    let result = x.value.count(where: {$0 == (y.value)})
                    return [
                        Router(
                            .int,
                            IntItem(
                                result,
                                call:[ x, y, InstructionItem(.vecDoubleOccurrencesOf)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        
        .vecDoubleRemove :
            Behavior(
                .vecDoubleRemove,
                takes: [.vecDouble, .double],
                fxn: {a in
                    let (x,y) = (a[0] as! VecDoubleItem, a[1] as! DoubleItem)
                    var result = x.value
                    result.removeAll(where: {$0 == (y.value)})
                    return [
                        Router(
                            .vecDouble,
                            VecDoubleItem(
                                result,
                                call:[ x, y, InstructionItem(.vecDoubleRemove)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),
        
        // ( [1,2,3] 2 9 .vecDoubleReplace)
        //
        // replace every occurrence of 2 in the argument (above) with 9
        //
        .vecDoubleReplace :
            Behavior(
                .vecDoubleReplace,
                takes: [.vecDouble, .double, .double],
                fxn: {a in
                    let (x, y, z) = (a[0] as! VecDoubleItem,
                                     a[1] as! DoubleItem,
                                     a[2] as! DoubleItem)
                    let result = x.value.map({$0 == z.value ? y.value : $0})
                    return [
                        Router(
                            .vecDouble,
                            VecDoubleItem(
                                result,
                                call:[ x, z, y, InstructionItem(.vecDoubleReplace)],
                                isContingent: Behavior.netContingency(of: x, y, z)
                            )
                        )
                    ]
                }
            ),
        
        // ( [1,1,2,3] 1 9 .vecDoubleReplace)
        //
        // replace the first occurrence of 1 in the argument (above) with 9
        //
        .vecDoubleReplaceFirst :
            Behavior(
                .vecDoubleReplaceFirst,
                takes: [.vecDouble, .double, .double],
                fxn: {a in
                    let (x, y, z) = (a[0] as! VecDoubleItem,
                                     a[1] as! DoubleItem,
                                     a[2] as! DoubleItem)
                    var result = x.value
                    if let idx = result.firstIndex(where: {$0 == z.value}) {
                        result[idx] = y.value
                    }
                    return [
                        Router(
                            .vecDouble,
                            VecDoubleItem(
                                result,
                                call:[ x, z, y, InstructionItem(.vecDoubleReplaceFirst)],
                                isContingent: Behavior.netContingency(of: x, y, z)
                            )
                        )
                    ]
                }
            ),
        
        // ( [1,1,2,3] 1 9 .vecDoubleSet)
        //
        // replace the element at position 1 in the argument (above) with 9
        //
        .vecDoubleSet :
            Behavior(
                .vecDoubleSet,
                takes: [.vecDouble, .int, .double],
                fxn: {a in
                    let (x, y, z) = (a[0] as! VecDoubleItem,
                                     a[1] as! IntItem,
                                     a[2] as! DoubleItem)
                    var result = x.value
                    if result.count > 0 {
                        let idx = abs(y.value) % (result.count)
                        result[idx] = z.value
                    }
                    return [
                        Router(
                            .vecDouble,
                            VecDoubleItem(
                                result,
                                call:[ x, z, y, InstructionItem(.vecDoubleSet)],
                                isContingent: Behavior.netContingency(of: x, y, z)
                            )
                        )
                    ]
                }
            ),
        
        // ( [1,1,2,3] 1 2 .vecDoubleSubVec)
        //
        // return a stretch of the original vector from positions 1...2
        // if idx1 is negative, make it zero
        // if idx2 < idx1, return an empty vector
        
        //
        .vecDoubleSubVec :
            Behavior(
                .vecDoubleSubVec,
                takes: [.vecDouble, .int, .int],
                fxn: {a in
                    let (x, y, z) = (a[0] as! VecDoubleItem,
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
                            .vecDouble,
                            VecDoubleItem(
                                result,
                                call: [ x, z, y, InstructionItem(.vecDoubleSubVec)],
                                isContingent: Behavior.netContingency(of: x, y, z)
                            )
                        )
                    ]
                }
            ),
        
        
        // ( [1,1,2,3] .vecDoublePushAll)
        //
        // return every item on the argument (in reverse order)
        // routing them to the correct stack
        //
        .vecDoublePushAll :
            Behavior(
                .vecDoublePushAll,
                takes: [.vecDouble],
                fxn: {a in
                    let (x) = (a[0] as! VecDoubleItem)
                    var results = [Router]()
                    let backwards = Array(x.value.reversed())
                    for idx in 0 ..< backwards.count {
                        results.append(
                            Router(
                                .double,
                                DoubleItem(
                                    backwards[idx],
                                    call: [x, InstructionItem(.vecDoublePushAll)],
                                    isContingent: Behavior.netContingency(of: x),
                                    index: backwards.count - idx - 1
                                    )
                                )
                            )
                    }
                    return results
                }
            ),
            
        
        
        // ( [1,1,2,3] .vecDoubleIterate MOUSE )
        //
        //               4          3            2                   1         0
        // reults: ( exec:MOUSE exec:remains exec:.vecDoubleIterate exec:MOUSE int:CHEESE )
        //
        
        .vecDoubleIterate :
            Behavior(
                .vecDoubleIterate,
                takes: [.vecDouble, .exec],
                fxn: {a in
                    let (x, y) = ( a[0] as! VecDoubleItem, a[1] )
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
                                .double,
                                DoubleItem(item,
                                        call: [x, InstructionItem(.vecDoubleIterate), y],
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
                                        .vecDoubleIterate,
                                        call: [x, InstructionItem(.vecDoubleIterate), y],
                                        isContingent: Behavior.netContingency(of: x, y),
                                        index: 2
                                    )))
                            results.append(
                                Router(.exec,
                                       VecDoubleItem(workingVector, // which was changed
                                                  call: [x, InstructionItem(.vecDoubleIterate), y],
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

