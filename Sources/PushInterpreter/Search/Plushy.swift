////
////  Plushy.swift
////  PropellerWithStructs
////
////  Created by William Tozier on 6/3/26.
////

enum PlushyControl {
    case open
    case close
}

struct Plushy {
        
    static func plushy2push(_  stuff: inout [Any], level:Int = 0) -> [any Item] {
        var result:[any Item] = []
        
        let extraOpens: [PushInstruction: Int] = [
            .execDeepDup : 0,
            .execDoCount : 1,
            .execDoRange : 1,
            .execDoTimes : 1,
            .execDoWhile : 1,
            .execDup : 1,
            .execDupItems : 0,
            .execDupTimes : 1,
            .execEq : 0,
            .execIf : 2,
            .execK : 2,
            .execPop : 1,
            .execPrint : 1,
            .execRot : 3,
            .execS : 3,
            .execShove : 1,
            .execSwap : 2,
            .execWhen : 1,
            .execWhile : 1,
            .execY : 1,
            .execYank : 0,
            .execYankDup : 0,
            .stringIterate : 1,
            .vecBoolIterate : 1,
            .vecDoubleIterate : 1,
            .vecIntIterate : 1,
            .vecStringIterate : 1,
        ]
        var pending:[PlushyControl] = []
        
        
        while !stuff.isEmpty {
            let thing = stuff.remove(at: 0)
            
            switch thing {
            case is Int:
                let parsedThing = IntItem(thing as! Int)
                result.append(parsedThing)
            case is Double:
                let parsedThing = DoubleItem(thing as! Double)
                result.append(parsedThing)
            case is Bool:
                let parsedThing = BoolItem(thing as! Bool)
                result.append(parsedThing)
            case is String:
                let parsedThing = StringItem(thing as! String)
                result.append(parsedThing)
            case is Character:
                let parsedThing = CharItem(thing as! Character)
                result.append(parsedThing)
            case is [Int]:
                let parsedThing = VecIntItem(thing as! [Int])
                result.append(parsedThing)
            case is [Bool]:
                let parsedThing = VecBoolItem(thing as! [Bool])
                result.append(parsedThing)
            case is [Double]:
                let parsedThing = VecDoubleItem(thing as! [Double])
                result.append(parsedThing)
            case is [String]:
                let parsedThing = VecStringItem(thing as! [String])
                result.append(parsedThing)
            case is PushInstruction:
                let parsedThing = InstructionItem(thing as! PushInstruction)
                result.append(parsedThing)
                let key = parsedThing.value
                if let opens = extraOpens[key] {
                    switch opens {
                    case 1:
                        stuff.insert(PlushyControl.open, at:0)
                    case 2:
                        pending.append(PlushyControl.open)
                        stuff.insert(PlushyControl.open, at:0)
                    case 3:
                        pending.append(PlushyControl.open)
                        pending.append(PlushyControl.open)
                        
                        stuff.insert(PlushyControl.open, at:0)
                    default:
                        continue
                    }
                }
            case is PlushyControl:
                if thing as! PlushyControl == PlushyControl.open {
                    let parsedThing = plushy2push(&stuff, level: level + 1)
                    result.append(CodeItem(parsedThing))
                    if pending.count > 0 {
                        pending.remove(at: 0)
                        stuff.insert(PlushyControl.open, at:0)
                    }
                } else {
                    if level > 0 {
                        return result
                    }
                }
            default:
                break
            }
        }
        return result
    }
}
