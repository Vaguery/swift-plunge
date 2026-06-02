////
////  GeneratedInstructions.swift
////  Propeller in Swift
////
////  Created by William Tozier on 6/2/26.
////
//
//import DequeModule
//
//extension Interpreter {
//
//    static var vectorInstructions: [PushInstruction: Instruction] {
//        let theseStacks : [PushStack] = [ .vecInt, .vecBool, .vecFloat, .vecString ]
//        var result: [PushInstruction: Instruction] = [:]
//        
//        for s in theseStacks {
//            result.merge(vectorDefinitions(for: s), uniquingKeysWith: { (first, _) in first })
//        }
//        
//        
//        
//        return result
//    }
//    
//    static func vectorDefinitions(for stack:PushStack) -> [PushInstruction : Instruction] {
//        let stackname = stack.rawValue
//        let stack = PushStack(rawValue: stackname)!
//        let itemStack = componentStack(stack)
//        var name : PushInstruction
//        var inst : Instruction
//        var result : [PushInstruction : Instruction] = [:]
//        
//        func componentStack(_ from:PushStack) -> PushStack {
//            return switch from {
//            case PushStack.vecInt: PushStack.int
//            case PushStack.vecBool: PushStack.bool
//            case PushStack.vecFloat: PushStack.float
//            case PushStack.vecString: PushStack.string
//            default: .error
//            }
//        }
//
//        
//        
//        func newVecItem<T> (from contents: [T]) -> PushItem {
//            let result = switch contents {
//            case is [Int]:
//                PushItem.makeVecInt(contents as! [Int])
//            case is [Double]:
//                PushItem.makeVecFloat(contents as! [Double])
//            case is [Bool]:
//                PushItem.makeVecBool(contents as! [Bool])
//            case is [String]:
//                PushItem.makeVecString(contents as! [String])
//            default:
//                PushItem.error("FAILED")
//            }
//            return result
//        }
//        
//        func dropLast<T>(_ a: [T]) -> [T] {
//            Array(a.dropLast(1))
//        }
//        
//        name = PushInstruction(rawValue: "\(stackname)ButLast")!
//        inst = Instruction(
//                        name,
//                        takes: [stack],
//                        fxn: {a in
//                            let oldVal = a[0].vecVal()
//                            let newVal = dropLast(oldVal!)
//                            let result = newVecItem(from: newVal)
//                            return [Router(stack,result)]
//                        })
//        result[name] = inst
//                    
//        name = PushInstruction(rawValue: "\(stackname)Concat")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, stack],
//                        fxn: {a in
//                            let (x,y) = (a[0].vecVal(), a[1].vecVal())
//                            let result = newVecItem(from: Array(y! + x!))
//                            return [Router(stack,result)]
//                        })
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(stackname)EmptyVector")!
//        inst = Instruction(
//                        name,
//                        takes: [stack],
//                        fxn: {a in
//                            let (x) = (a[0].vecVal())
//                            let result = PushItem.bool(x!.isEmpty)
//                            return [Router(.bool,result)]
//                        })
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(stackname)Length")!
//        inst = Instruction(
//                        name,
//                        takes: [stack],
//                        fxn: {a in
//                            let (x) = (a[0].vecVal())
//                            let result = PushItem.int(x!.count)
//                            return [Router(.int,result)]
//                        })
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(stackname)Rest")!
//        inst = Instruction(
//                        name,
//                        takes: [stack],
//                        fxn: {a in
//                            let (x) = (a[0].vecVal())
//                            let result = newVecItem(from: Array(x!.dropFirst(1)))
//                            return [Router(stack,result)]
//                        })
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(stackname)Reverse")!
//        inst = Instruction(
//                        name,
//                        takes: [stack],
//                        fxn: {a in
//                            let (x) = (a[0].vecVal())
//                            let result = newVecItem(from: Array(x!.reversed()))
//                            return [Router(stack,result)]
//                        })
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(stackname)Take")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, .int],
//                        fxn: {a in
//                            let (x, y) = (a[0].vecVal(), a[1].iVal())
//                            let range = x!.count
//                            let idx = range - (min(range, max(y!,0)))
//                            let result = newVecItem(from: Array(x!.dropLast(idx)))
//                            return [Router(stack,result)]
//                        })
//        
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(stackname)Drop")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, .int],
//                        fxn: {a in
//                            let (x, y) = (a[0].vecVal(), a[1].iVal())
//                            let range = x!.count
//                            let idx = (min(range, max(y!,0)))
//                            let result = newVecItem(from: Array(x!.dropFirst(idx)))
//                            return [Router(stack,result)]
//                        })
//        
//        result[name] = inst
//        
//        name = PushInstruction(rawValue: "\(stackname)Conj")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, itemStack],
//                        fxn: {a in
//                            let (x, y) = (a[0].vecVal(), a[1].vectorItemGetter())
//                            let resultVec = x! + [y!]
//                            let result = newVecItem(from: resultVec)
//                            return [Router(stack,result)]
//                        })
//        
//        result[name] = inst
//        
//                
//        name = PushInstruction(rawValue: "\(stackname)Contains")!
//        inst = Instruction(
//                        name,
//                        takes: [stack, itemStack],
//                        fxn: {a in
//                            let (x, y) = (a[0].vecVal(), a[1].vectorItemGetter())
//                            let result: Bool
//                            switch (x, y) {
//                            case let (array as [Int], item as Int):
//                                result = array.contains(where: { $0 == item })
//                            case let (array as [Double], item as Double):
//                                result = array.contains(where: { $0 == item })
//                            case let (array as [Bool], item as Bool):
//                                result = array.contains(where: { $0 == item })
//                            case let (array as [String], item as String):
//                                result = array.contains(where: { $0 == item })
//                            default:
//                                result = false
//                            }
//                            return [Router(.bool,PushItem.makeBool(result))]
//                        })
//        
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(stackname)First")!
//        inst = Instruction(
//                        name,
//                        takes: [stack],
//                        fxn: {a in
//                            let (x) = (a[0].vecVal())
//                            if let y = x?.first {
//                                let result = switch y {
//                                case is Int: PushItem.makeInt(y as! Int)
//                                case is Bool: PushItem.makeBool(y as! Bool)
//                                case is Double: PushItem.makeFloat(y as! Double)
//                                case is String: PushItem.makeString(y as! String)
//                                default: PushItem.error("BAD TYPE")
//                                }
//                                return [Router(itemStack,result)]
//                            } else {
//                                return []
//                            }
//                        })
//        
//        result[name] = inst
//        
//        name = PushInstruction(rawValue: "\(stackname)Last")!
//        inst = Instruction(
//                        name,
//                        takes: [stack],
//                        fxn: {a in
//                            let (x) = (a[0].vecVal())
//                            if let y = x?.last {
//                                let result = switch y {
//                                case is Int: PushItem.makeInt(y as! Int)
//                                case is Bool: PushItem.makeBool(y as! Bool)
//                                case is Double: PushItem.makeFloat(y as! Double)
//                                case is String: PushItem.makeString(y as! String)
//                                default: PushItem.error("BAD TYPE")
//                                }
//                                return [Router(itemStack,result)]
//                            } else {
//                                return []
//                            }
//                        })
//        
//        result[name] = inst
//        
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
//
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
//
//            
//        return result
//    }
//}
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//extension Interpreter {
//    static var combinatorInstructions: [PushInstruction: Instruction] {
//        let theseStacks : [PushStack] = [ .bool, .int, .float, .char, .string, .code, .exec, .vecInt, .vecBool, .vecFloat, .vecString ]
//        
//        var result: [PushInstruction: Instruction] = [:]
//        
//        for s in theseStacks {
//            result.merge(combinators(for: s), uniquingKeysWith: { (first, _) in first })
//        }
//        
//        return result
//    }
//    
//    
//    static func combinators(for stack:PushStack) -> [PushInstruction : Instruction] {
//        let type = stack.rawValue
//        var name : PushInstruction
//        var inst : Instruction
//        var result : [PushInstruction : Instruction] = [:]
//        
//        name = PushInstruction(rawValue: "\(type)Dup")!
//        inst = Instruction(
//            name,
//            takes: [stack],
//            fxn: {a in
//                return [Router(stack, a[0]), Router(stack, a[0])]
//            })
//        result[name] = inst
//        
//        name = PushInstruction(rawValue: "\(type)Eq")!
//        inst = Instruction(
//            name,
//            takes: [stack, stack],
//            fxn: {a in
//                let same = (a[0] == a[1])
//                let hist = "( \(a[0].hist()) \(a[1].hist()) \(name) )"
//                return [Router(.bool, PushItem.makeBool(same, h: hist))]
//            })
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(type)Swap")!
//        inst = Instruction(
//            name,
//            takes: [stack, stack],
//            fxn: {a in
//                return [Router(stack, a[0]), Router(stack, a[1])]
//            })
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(type)Pop")!
//        inst = Instruction(
//            name,
//            takes: [stack],
//            fxn: {_ in return []})
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(type)StackDepth")!
//        inst = DirectInstruction(
//            name,
//            takes: [],
//            modifier: { (interpreter, collectedItems) in
//                let c = interpreter.stacks[stack]!.count
//                return [Router(.int, PushItem.makeInt(c, h: "\(name)()"))]
//            })
//        result[name] = inst
//        
//        name = PushInstruction(rawValue: "\(type)DupTimes")!
//        inst = DirectInstruction(
//            name,
//            takes: [.int],
//            modifier: { (interpreter, collectedItems) in
//                let number = max(collectedItems[0].iVal()! ,0)
//                if let item = interpreter.stacks[stack]!.first {
//                    interpreter.stacks[stack]!.prepend(contentsOf: repeatElement(item, count: number))
//                    return []
//                } else {
//                    return [Router(.error, .makeError("« WARNING \(name) on empty stack »"))]
//                }
//            })
//        result[name] = inst
//        
//        name = PushInstruction(rawValue: "\(type)DupItems")!
//        inst = DirectInstruction(
//            name,
//            takes: [.int],
//            modifier: { (interpreter, collectedItems) in
//                let range = interpreter.stacks[stack]!.count - 1
//                let number = min( range, max(collectedItems[0].iVal()! ,0))
//                if interpreter.stacks[stack]!.isEmpty == true {
//                    return []
//                } else {
//                    let duplicates = interpreter.stacks[stack]!.prefix(number)
//                    interpreter.stacks[stack]!.prepend(contentsOf: duplicates)
//                    return []
//                }
//            })
//        result[name] = inst
//        
//        name = PushInstruction(rawValue: "\(type)Empty")!
//        inst = DirectInstruction(
//            name,
//            takes: [],
//            modifier: { (interpreter, collectedItems) in
//                let empty = interpreter.stacks[stack]!.isEmpty
//                return [Router(.bool, PushItem.makeBool(empty, h: "\(name)()"))]
//            })
//        result[name] = inst
//        
//        name = PushInstruction(rawValue: "\(type)Flush")!
//        inst = DirectInstruction(
//            name,
//            takes: [],
//            modifier: { (interpreter, collectedItems) in
//                interpreter.stacks[stack]!.removeAll()
//                return []
//            })
//        result[name] = inst
//        
//        name = PushInstruction(rawValue: "\(type)Rot")!
//        inst = Instruction(
//            name,
//            takes: [stack, stack, stack],
//            fxn: {a in
//                let (x,y,z) = (a[0], a[1], a[2])
//                return [Router(stack, y), Router(stack, x), Router(stack,z)]
//            })
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(type)Yank")!
//        inst = DirectInstruction(
//            name,
//            takes: [.int],
//            modifier: { (interpreter, collectedItems) in
//                let idxItem = collectedItems[0]
//                let range = interpreter.stacks[stack]!.count - 1
//                let idx = max(0,min(idxItem.iVal()!,range))
//                
//                guard range > 0 else {
//                    return [Router(.error, .makeError("« WARNING \(name) on empty stack »"))]
//                }
//                let item = interpreter.stacks[stack]!.remove(at: idx)
//                let itemHist = item.hist()
//                let idxHist = idxItem.hist()
//                let newItem = item.updateHistory("( \(itemHist) .\(name)( \(idxHist) )")
//                return [Router(stack, newItem)]
//            })
//        result[name] = inst
//        
//        name = PushInstruction(rawValue: "\(type)Shove")!
//        inst = DirectInstruction(
//            name,
//            takes: [.int],
//            modifier: { (interpreter, collectedItems) in
//                guard let item = interpreter.stacks[stack]!.popFirst() else {
//                    return [Router(.error, .makeError("« WARNING \(name) on empty stack »"))]
//                }
//                
//                let idxItem = collectedItems[0]
//                let range = interpreter.stacks[stack]!.count - 1
//                let idx = max(0,min(idxItem.iVal()!,range))
//                let itemHist = item.hist()
//                let idxHist = idxItem.hist()
//                let newItem = item.updateHistory("( \(itemHist) .\(name)( \(idxHist) )")
//                interpreter.stacks[stack]!.insert(newItem, at: idx)
//                return []
//            })
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(type)YankDup")!
//        inst = DirectInstruction(
//            name,
//            takes: [.int],
//            modifier: { (interpreter, collectedItems) in
//                let idxItem = collectedItems[0]
//                let range = interpreter.stacks[stack]!.count - 1
//                let idx = max(0,min(idxItem.iVal()!,range))
//                
//                guard range > 0 else {
//                    return [Router(.error, .makeError("« WARNING \(name) on empty stack »"))]
//                }
//                let copy = interpreter.stacks[stack]![idx]
//                let itemHist = copy.hist()
//                let idxHist = idxItem.hist()
//                let newItem = copy.updateHistory("( \(itemHist) .(name)(\(idxHist))")
//                return [Router(stack, newItem)]
//            })
//        result[name] = inst
//        
//        
//        name = PushInstruction(rawValue: "\(type)DeepDup")!
//        inst = DirectInstruction(
//            name,
//            takes: [.int],
//            modifier: { (interpreter, collectedItems) in
//                let idxItem = collectedItems[0]
//                let range = interpreter.stacks[stack]!.count - 1
//                let idx = range - max(0,min(idxItem.iVal()!,range))
//                // from the "bottom"
//                
//                guard range > 0 else {
//                    return [Router(.error, .makeError("« WARNING \(name) on empty stack »"))]
//                }
//                let copy = interpreter.stacks[stack]![idx]
//                let itemHist = copy.hist()
//                let idxHist = idxItem.hist()
//                let newItem = copy.updateHistory("( \(itemHist) .(name)(\(idxHist))")
//                return [Router(stack, newItem)]
//            })
//        result[name] = inst
//        return result
//        
//        name = PushInstruction(rawValue: "\(type)DeepDup")!
//        inst = DirectInstruction(
//            name,
//            takes: [.int],
//            modifier: { (interpreter, collectedItems) in
//                let idxItem = collectedItems[0]
//                let range = interpreter.stacks[stack]!.count - 1
//                let idx = range - max(0,min(idxItem.iVal()!,range))
//                // from the "bottom"
//                
//                guard range > 0 else {
//                    return [Router(.error, .makeError("« WARNING \(name) on empty stack »"))]
//                }
//                let copy = interpreter.stacks[stack]![idx]
//                let itemHist = copy.hist()
//                let idxHist = idxItem.hist()
//                let newItem = copy.updateHistory("( \(itemHist) .(name)(\(idxHist))")
//                return [Router(stack, newItem)]
//            })
//        result[name] = inst
//        return result
//    }
//}
//    
//    
//
//
//
