//
//  VecInt Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/12/26.
//

import DequeModule

extension Interpreter {
    
    static let vecIntBehaviors: [PushInstruction : Behavior] =
    [
        // returns a new vecInt with the old value's last element removed
        // if the argument was empty, an empty vector is pushed
        .vecIntButLast :
            Behavior(
                .vecIntButLast,
                takes: [.vecInt],
                fxn: {a in
                    let (x) = (a[0] as! VecIntItem)
                    return [
                        Router(
                            .vecInt,
                            VecIntItem(x.value.dropLast(1),
                                       call:[x, InstructionItem(.vecIntButLast)],
                                       isContingent: Behavior.netContingency(of: x)
                                      )
                        )
                    ]
                }
            ),
        
        .vecIntConcat :
            Behavior(
                .vecIntConcat,
                takes: [.vecInt, .vecInt],
                fxn: {a in
                    let (x,y) = (a[0] as! VecIntItem, a[1] as! VecIntItem)
                    return [
                        Router(
                            .vecInt,
                            VecIntItem(y.value + x.value,
                                       call:[y, x, InstructionItem(.vecIntButLast)],
                                       isContingent: Behavior.netContingency(of: x, y)
                                      )
                        )
                    ]
                }
            ),

        .vecIntIsEmpty :
            Behavior(
                .vecIntIsEmpty,
                takes: [.vecInt],
                fxn: {a in
                    let (x) = (a[0] as! VecIntItem)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                x.value.isEmpty,
                                call:[ x, InstructionItem(.vecIntIsEmpty)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),

        .vecIntLength :
            Behavior(
                .vecIntLength,
                takes: [.vecInt],
                fxn: {a in
                    let (x) = (a[0] as! VecIntItem)
                    return [
                        Router(
                            .int,
                            IntItem(
                                x.value.count,
                                call:[ x, InstructionItem(.vecIntLength)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),

        .vecIntRest :
            Behavior(
                .vecIntRest,
                takes: [.vecInt],
                fxn: {a in
                    let (x) = (a[0] as! VecIntItem)
                    return [
                        Router(
                            .vecInt,
                            VecIntItem(
                                Array(x.value.dropFirst(1)),
                                call:[ x, InstructionItem(.vecIntRest)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),

        .vecIntReverse :
            Behavior(
                .vecIntReverse,
                takes: [.vecInt],
                fxn: {a in
                    let (x) = (a[0] as! VecIntItem)
                    return [
                        Router(
                            .vecInt,
                            VecIntItem(
                                Array(x.value.reversed() ),
                                call:[ x, InstructionItem(.vecIntReverse)],
                                isContingent: Behavior.netContingency(of: x)
                            )
                        )
                    ]
                }
            ),


        .vecIntTake :
            Behavior(
                .vecIntTake,
                takes: [.vecInt, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                    let range = x.value.count
                    let idx = range - (min(range, max(y.value,0)))
                    let result = Array(x.value.dropLast(idx))

                    return [
                        Router(
                            .vecInt,
                            VecIntItem(
                                result,
                                call:[ x, y, InstructionItem(.vecIntTake)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecIntDrop :
            Behavior(
                .vecIntDrop,
                takes: [.vecInt, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                    let range = x.value.count
                    let idx = (min(range, max(y.value,0)))
                    let result = Array(x.value.dropFirst(idx))

                    return [
                        Router(
                            .vecInt,
                            VecIntItem(
                                result,
                                call:[ x, y, InstructionItem(.vecIntDrop)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecIntConj :
            Behavior(
                .vecIntConj,
                takes: [.vecInt, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                    var result = x.value
                    result.append(y.value)
                    return [
                        Router(
                            .vecInt,
                            VecIntItem(
                                result,
                                call:[ x, y, InstructionItem(.vecIntConj)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecIntContains :
            Behavior(
                .vecIntContains,
                takes: [.vecInt, .int],
                fxn: {a in
                    let (x,y) = (a[0] as! VecIntItem, a[1] as! IntItem)
                    var result = x.value.contains(y.value)
                    return [
                        Router(
                            .bool,
                            BoolItem(
                                result,
                                call:[ x, y, InstructionItem(.vecIntContains)],
                                isContingent: Behavior.netContingency(of: x, y)
                            )
                        )
                    ]
                }
            ),

        .vecIntFirst :
            Behavior(
                .vecIntFirst,
                takes: [.vecInt],
                fxn: {a in
                    let (x) = (a[0] as! VecIntItem)
                    if let result = x.value.first {
                        return [
                            Router(
                                .int,
                                IntItem(
                                    result,
                                    call:[ x, InstructionItem(.vecIntFirst)],
                                    isContingent: Behavior.netContingency(of: x)
                                )
                            )
                        ]
                    } else {
                        return []
                    }
                }
            ),

        .vecIntLast :
            Behavior(
                .vecIntLast,
                takes: [.vecInt],
                fxn: {a in
                    let (x) = (a[0] as! VecIntItem)
                    if let result = x.value.last {
                        return [
                            Router(
                                .int,
                                IntItem(
                                    result,
                                    call:[ x, InstructionItem(.vecIntLast)],
                                    isContingent: Behavior.netContingency(of: x)
                                )
                            )
                        ]
                    } else {
                        return []
                    }
                }
            ),

//        name = PushInstruction(rawValue: "\(stackname)Nth")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, .int],
//                        fxn: {a in
//                            let (x,y) = (a[0].vecVal(), a[1].iVal())
//                            let range = x!.count
//                            if range == 0 {
//                                return []
//                            } else {
//                                let position = abs(y!)
//                                let idx = position % range
//                                let result = switch x![idx] {
//                                case is Int: PushItem.makeInt(x![idx] as! Int)
//                                case is Bool: PushItem.makeBool(x![idx] as! Bool)
//                                case is Double: PushItem.makeFloat(x![idx] as! Double)
//                                case is String: PushItem.makeString(x![idx] as! String)
//                                default: PushItem.error("BAD TYPE")
//                                }
//                                return [Router(itemStack, result)]
//                            }
//                        })
//        result[name] = inst
//
//        name = PushInstruction(rawValue: "\(stackname)IndexOf")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, itemStack],
//                        fxn: {a in
//                            let (x,y) = (a[0].vecVal(), a[1].vectorItemGetter())
//                            var result:Int?
//                            if x!.isEmpty == true {
//                                return []
//                            } else {
//                                switch (x, y) {
//                                case let (array as [Int], item as Int):
//                                    if let idx = array.firstIndex(of: y as! Int) {
//                                        result = idx
//                                    }
//                                case let (array as [Double], item as Double):
//                                    if let idx = array.firstIndex(of: y as! Double) {
//                                        result = idx
//                                    }
//                                case let (array as [Bool], item as Bool):
//                                    if let idx = array.firstIndex(of: y as! Bool) {
//                                        result = idx
//                                    }
//                                case let (array as [String], item as String):
//                                    if let idx = array.firstIndex(of: y as! String) {
//                                        result = idx
//                                    }
//                                default:
//                                    result = nil
//                                }
//                            }
//                            if let result {
//                                return [Router(.int, PushItem.makeInt(result))]
//                            } else {
//                                return []
//                            }
//                        })
//        result[name] = inst
//
//
//        name = PushInstruction(rawValue: "\(stackname)OccurrencesOf")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, itemStack],
//                        fxn: {a in
//                            let (x,y) = (a[0].vecVal(), a[1].vectorItemGetter())
//                            var result:Int
//                            if x!.isEmpty == true {
//                                return [Router(.int, PushItem.makeInt(0))]
//                            } else {
//                                switch (x, y) {
//                                case let (array as [Int], item as Int):
//                                    result = array.count(where: {$0 == (y as! Int)})
//                                case let (array as [Double], item as Double):
//                                    result = array.count(where: {$0 == (y as! Double)})
//                                case let (array as [Bool], item as Bool):
//                                    result = array.count(where: {$0 == (y as! Bool)})
//                                case let (array as [String], item as String):
//                                    result = array.count(where: {$0 == (y as! String)})
//                                default:
//                                    result = -1
//                                }
//                            }
//                            if result >= 0 {
//                                return [Router(.int, PushItem.makeInt(result))]
//                            } else {
//                                return []
//                            }
//                        })
//        result[name] = inst
//
//        name = PushInstruction(rawValue: "\(stackname)Remove")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, itemStack],
//                        fxn: {a in
//                            let (x,y) = (a[0].vecVal(), a[1].vectorItemGetter())
//                            var result: PushItem
//                            if x!.isEmpty == true {
//                                return [Router(stack, a[0])]
//                            } else {
//                                switch (x, y) {
//                                case var (array as [Int], item as Int):
//                                    array.removeAll(where: {$0 == (item )})
//                                    result = PushItem.makeVecInt(array)
//                                case var (array as [Double], item as Double):
//                                    array.removeAll(where: {$0 == (item )})
//                                    result = PushItem.makeVecFloat(array)
//                                case var (array as [Bool], item as Bool):
//                                    array.removeAll(where: {$0 == (item )})
//                                    result = PushItem.makeVecBool(array)
//                                case var (array as [String], item as String):
//                                    array.removeAll(where: {$0 == (item )})
//                                    result = PushItem.makeVecString(array)
//                                default:
//                                    result = PushItem.error("bad \(name)")
//                                }
//                            }
//                            return [Router(stack, result)]
//                        })
//        result[name] = inst
//
//
//        name = PushInstruction(rawValue: "\(stackname)Replace")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, itemStack, itemStack],
//                        fxn: {a in
//                            let (x,y,z) = (a[0].vecVal(), a[1].vectorItemGetter(), a[2].vectorItemGetter())
//                            var result: PushItem
//                            if x!.isEmpty == true {
//                                return [Router(stack, a[0])]
//                            } else {
//                                switch (x, y, z) {
//                                case var (array as [Int], old as Int, new as Int):
//                                    let updated = array.map {$0 == old ? new : $0 }
//                                    result = PushItem.makeVecInt(updated)
//                                case var (array as [Double], old as Double, new as Double):
//                                    let updated = array.map {$0 == old ? new : $0 }
//                                    result = PushItem.makeVecFloat(updated)
//                                case var (array as [Bool], old as Bool, new as Bool):
//                                    let updated = array.map {$0 == old ? new : $0 }
//                                    result = PushItem.makeVecBool(updated)
//                                case var (array as [String], old as String, new as String):
//                                    let updated = array.map {$0 == old ? new : $0 }
//                                    result = PushItem.makeVecString(updated)
//                                default:
//                                    result = PushItem.error("bad \(name)")
//                                }
//                            }
//                            return [Router(stack, result)]
//                        })
//        result[name] = inst
//
//
//
//        name = PushInstruction(rawValue: "\(stackname)ReplaceFirst")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, itemStack, itemStack],
//                        fxn: {a in
//                            let (x,y,z) = (a[0].vecVal(), a[1].vectorItemGetter(), a[2].vectorItemGetter())
//                            var result: PushItem = PushItem.error("bad \(name)")
//                            if x!.isEmpty == true {
//                                return [Router(stack, a[0])]
//                            } else {
//                                switch (x, y, z) {
//                                case var (array as [Int], old as Int, new as Int):
//                                    if let idx = array.firstIndex(where: {$0 == old}) {
//                                        array[idx] = new
//                                        result = PushItem.makeVecInt(array)
//                                    } else {
//                                        result = a[0]
//                                    }
//                                case var (array as [Double], old as Double, new as Double):
//                                    if let idx = array.firstIndex(where: {$0 == old}) {
//                                        array[idx] = new
//                                        result = PushItem.makeVecFloat(array)
//                                    } else {
//                                        result = a[0]
//                                    }
//                                case var (array as [Bool], old as Bool, new as Bool):
//                                    if let idx = array.firstIndex(where: {$0 == old}) {
//                                        array[idx] = new
//                                        result = PushItem.makeVecBool(array)
//                                    } else {
//                                        result = a[0]
//                                    }
//                                case var (array as [String], old as String, new as String):
//                                    if let idx = array.firstIndex(where: {$0 == old}) {
//                                        array[idx] = new
//                                        result = PushItem.makeVecString(array)
//                                    } else {
//                                        result = a[0]
//                                    }
//                                default:
//                                    result = PushItem.error("bad \(name)")
//                                }
//                            }
//                            return [Router(stack, result)]
//                        })
//        result[name] = inst
//
//
//        name = PushInstruction(rawValue: "\(stackname)Set")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, itemStack, .int],
//                        fxn: {a in
//                            let (x,y,z) = (a[0].vecVal(), a[1].vectorItemGetter(), a[2].iVal())
//                            var result: PushItem = PushItem.error("bad \(name)")
//
//                            if x!.isEmpty == true {
//                                return [Router(stack, a[0])]
//                            } else {
//                                let range = x!.count
//                                let position = abs(z!)
//                                let idx = position % range
//                                switch (x, y) {
//                                case var (array as [Int], new as Int):
//                                        array[idx] = new
//                                        result = PushItem.makeVecInt(array)
//                                case var (array as [Double], new as Double):
//                                        array[idx] = new
//                                        result = PushItem.makeVecFloat(array)
//                                case var (array as [Bool], new as Bool):
//                                        array[idx] = new
//                                        result = PushItem.makeVecBool(array)
//                                case var (array as [String], new as String):
//                                        array[idx] = new
//                                        result = PushItem.makeVecString(array)
//                                default:
//                                    result = PushItem.error("bad \(name)")
//                                }
//                            }
//                            return [Router(stack, result)]
//                        })
//        result[name] = inst
//
//
//        name = PushInstruction(rawValue: "\(stackname)SubVec")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, .int, .int],
//                        fxn: {a in
//                            let (x,starter,ender) = (a[0].vecVal(), a[1].iVal(), a[2].iVal())
//                            var result: PushItem = PushItem.error("bad \(name)")
//
//                            if x!.isEmpty == true {
//                                return [Router(stack, a[0])]
//                            } else {
//                                let range = x!.count-1
//                                let lhs = min(range,max(0,starter!))
//                                let rhs = min(range,max(0,starter!,ender!))
//                                switch (x) {
//                                case var (array as [Int]):
//                                    result = PushItem.makeVecInt(Array(array[lhs...rhs]))
//                                case var (array as [Double]):
//                                    result = PushItem.makeVecFloat(Array(array[lhs...rhs]))
//                                case var (array as [Bool]):
//                                    result = PushItem.makeVecBool(Array(array[lhs...rhs]))
//                                case var (array as [String]):
//                                    result = PushItem.makeVecString(Array(array[lhs...rhs]))
//                                default:
//                                    result = PushItem.error("bad \(name)")
//                                }
//                            }
//                            return [Router(stack, result)]
//                        })
//        result[name] = inst
//
//
//        name = PushInstruction(rawValue: "\(stackname)PushAll")!
//        inst = Instruction(
//                        name,
//                        takes: [stack],
//                        fxn: {a in
//                            let (x) = (a[0].vecVal())
//                            var thisResult: [Router] = []
//                            for item in x!.reversed() {
//                                switch item {
//                                case is Int: thisResult.append(Router(itemStack, .int(item as! Int)))
//                                case is Bool: thisResult.append(Router(itemStack, .bool(item as! Bool)))
//                                case is Double: thisResult.append(Router(itemStack, .float(item as! Double)))
//                                case is String: thisResult.append(Router(itemStack, .string(item as! String)))
//                                default:
//                                    thisResult.append(
//                                        Router(.error, PushItem.error("BAD THING IN \(name)")))
//                                }
//                            }
//                            return thisResult})
//
//        result[name] = inst
//

            
        // TODO: vecIntIterate needs to be carefully checked for contingency propagation

        
        //        name = PushInstruction(rawValue: "\(stackname)Iterate")!
        //        inst = Instruction(
        //                        name,
        //                        takes: [stack, .exec],
        //                        fxn: {a in
        //                            var (x, y) = (a[0].vecVal(), a[1])
        //                            var thisResult: [Router] = []
        //                            let count = x!.count
        //                            if count == 0 {
        //                                return thisResult
        //                            } else {
        //                                thisResult.append(Router(.exec, a[1]))
        //
        //                                let chunk = x!.removeFirst()
        //
        //                                // push the first vector element to its correct stack
        //                                switch chunk {
        //                                case is Int: thisResult.append(
        //                                    Router(itemStack, PushItem.makeInt(chunk as! Int)))
        //                                case is Bool: thisResult.append(
        //                                    Router(itemStack, PushItem.makeBool(chunk as! Bool)))
        //                                case is Double: thisResult.append(
        //                                    Router(itemStack, PushItem.makeFloat(chunk as! Double)))
        //                                case is String: thisResult.append(
        //                                    Router(itemStack, PushItem.makeString(chunk as! String)))
        //                                default:
        //                                    thisResult.append(
        //                                        Router(.error,
        //                                               PushItem.error("BAD THING IN \(name)")))
        //                                }
        //                                if count > 1 {
        //                                    // push a copy of this instruction to exec
        //                                    thisResult.append(Router(.exec, PushItem.makeInst(name)))
        //
        //                                    // push the remainder of the vector item to exec
        //                                    switch chunk {
        //                                    case is Int: thisResult.append(Router(.exec,
        //                                                                          PushItem.vecInt(x as! [Int])))
        //                                    case is Bool: thisResult.append(Router(.exec,
        //                                                                           PushItem.vecBool(x as! [Bool])))
        //                                    case is Double: thisResult.append(Router(.exec,
        //                                                                             PushItem.vecFloat(x as! [Double])))
        //                                    case is String: thisResult.append(Router(.exec,
        //                                                                             PushItem.vecString(x as! [String])))
        //                                    default:
        //                                        thisResult.append(
        //                                            Router(.error, PushItem.error("BAD THING IN \(name)")))
        //                                    }
        //
        //                                    // push a copy of the top exec item to exwc
        //                                    thisResult.append(Router(.exec, y))
        //                                }
        //                            }
        //                            return thisResult
        //                        })
        //
        //        result[name] = inst

        
    ]
}

