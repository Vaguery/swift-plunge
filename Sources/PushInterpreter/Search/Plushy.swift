////
////  Plushy.swift
////  PropellerWithStructs
////
////  Created by William Tozier on 6/3/26.
////
//
//enum PlushyControl {
//    case open
//    case close
//}
//
//struct Plushy {
//    
//    static func anyArray2push(_ stuff:[Any]) -> [PushItem] {
//        var result:[PushItem] = []
//        var leftovers = stuff
//        
//        while !leftovers.isEmpty {
//            let thing = leftovers.remove(at: 0)
//            switch thing {
//            case is Int:
//                let parsedThing = PushItem.int(thing as! Int)
//                result.append(parsedThing)
//            case is Double:
//                let parsedThing = PushItem.float(thing as! Double)
//                result.append(parsedThing)
//            case is Bool:
//                let parsedThing = PushItem.bool(thing as! Bool)
//                result.append(parsedThing)
//            case is String:
//                let parsedThing = PushItem.string(thing as! String)
//                result.append(parsedThing)
//            case is Character:
//                let parsedThing = PushItem.char(thing as! Character)
//                result.append(parsedThing)
//            case is PushInstruction:
//                let parsedThing = PushItem.instruction(thing as! PushInstruction)
//                result.append(parsedThing)
//            case is [Any]:
//                let parsedThing = PushItem.codeblock(anyArray2push(thing as! [Any]))
//                result.append(parsedThing)
//            default:
//                break
//            }
//        }
//        return result
//    }
//    
//    static func plushy2push(_  stuff: inout [Any], level:Int = 0) -> [PushItem] {
//        var result:[PushItem] = []
//        
//        let extraOpens: [PushInstruction: Int] = [.execDup :1, .execDupTimes :1, .execDupItems :0, .execEq :0, .execPop :1, .execRot :3, .execShove :1, .execSwap :2, .execYank :0, .execYankDup :0, .execDeepDup :0, .execPrint :1, .execIf  :2, .execWhen :1, .execWhile :1, .execDoWhile :1, .execDoRange :1, .execDoCount :1, .execDoTimes :1, .execK :2, .execS :3, .execY :1, .stringIterate :1, .vecBoolIterate :1, .vecStringIterate :1, .vecIntIterate :1, .vecFloatIterate :1, ]
//        var pending:[PlushyControl] = []
//        
//        
//        while !stuff.isEmpty {
//            let thing = stuff.remove(at: 0)
//            
//            switch thing {
//            case is Int:
//                let parsedThing = PushItem.makeInt(thing as! Int)
//                result.append(parsedThing)
//            case is Double:
//                let parsedThing = PushItem.makeFloat(thing as! Double)
//                result.append(parsedThing)
//            case is Bool:
//                let parsedThing = PushItem.makeBool(thing as! Bool)
//                result.append(parsedThing)
//            case is String:
//                let parsedThing = PushItem.makeString(thing as! String)
//                result.append(parsedThing)
//            case is Character:
//                let parsedThing = PushItem.makeChar(thing as! Character)
//                result.append(parsedThing)
//            case is [Int]:
//                let parsedThing = PushItem.makeVecInt(thing as! [Int])
//                result.append(parsedThing)
//            case is [Bool]:
//                let parsedThing = PushItem.makeVecBool(thing as! [Bool])
//                result.append(parsedThing)
//            case is [Double]:
//                let parsedThing = PushItem.makeVecFloat(thing as! [Double])
//                result.append(parsedThing)
//            case is [String]:
//                let parsedThing = PushItem.makeVecString(thing as! [String])
//                result.append(parsedThing)
//            case is PushInstruction:
//                let parsedThing = PushItem.instruction(thing as! PushInstruction)
//                result.append(parsedThing)
//                let key = parsedThing.name()!
//                if let opens = extraOpens[key] {
//                    switch opens {
//                    case 1:
//                        stuff.insert(PlushyControl.open, at:0)
//                    case 2:
//                        pending.append(PlushyControl.open)
//                        stuff.insert(PlushyControl.open, at:0)
//                    case 3:
//                        pending.append(PlushyControl.open)
//                        pending.append(PlushyControl.open)
//                        
//                        stuff.insert(PlushyControl.open, at:0)
//                    default:
//                        continue
//                    }
//                }
//            case is PlushyControl:
//                if thing as! PlushyControl == PlushyControl.open {
//                    let parsedThing = plushy2push(&stuff, level: level + 1)
//                    result.append(PushItem.codeblock(parsedThing))
//                    if pending.count > 0 {
//                        pending.remove(at: 0)
//                        stuff.insert(PlushyControl.open, at:0)
//                    }
//                } else {
//                    if level > 0 {
//                        return result
//                    }
//                }
//            default:
//                break
//            }
//        }
//        return result
//    }
//}
