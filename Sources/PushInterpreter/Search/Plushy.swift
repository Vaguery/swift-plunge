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

public struct Plushy {

    public static func plushy2push(_  stuff: [Any]) -> [any Item] {
        var workingCopy = stuff
        return destructivePlushy2push(&workingCopy)
    }


    private static func destructivePlushy2push(_  stuff: inout [Any], level:Int = 0) -> [any Item] {
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

        func implicitBranch(_ stuff: inout [Any], key: PushInstruction) {
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
                    return
                }
            }

        }

        
        while stuff.isEmpty ==  false {

            let thing = stuff.remove(at: 0)

            switch thing {
            case is Int:
                let parsedThing = IntItem(thing as! Int)
                result.append(parsedThing)
            case is IntItem:
                result.append(thing as! IntItem)

            case is Double:
                let parsedThing = DoubleItem(thing as! Double)
                result.append(parsedThing)
            case is DoubleItem:
                result.append(thing as! DoubleItem)

            case is Bool:
                let parsedThing = BoolItem(thing as! Bool)
                result.append(parsedThing)
            case is BoolItem:
                result.append(thing as! BoolItem)

            case is String:
                let parsedThing = StringItem(thing as! String)
                result.append(parsedThing)
            case is StringItem:
                result.append(thing as! StringItem)

            case is Character:
                let parsedThing = CharItem(thing as! Character)
                result.append(parsedThing)
            case is CharItem:
                result.append(thing as! CharItem)

            case is [Int]:
                let parsedThing = VecIntItem(thing as! [Int])
                result.append(parsedThing)
            case is VecIntItem:
                result.append(thing as! VecIntItem)

            case is [Bool]:
                let parsedThing = VecBoolItem(thing as! [Bool])
                result.append(parsedThing)
            case is VecBoolItem:
                result.append(thing as! VecBoolItem)

            case is [Double]:
                let parsedThing = VecDoubleItem(thing as! [Double])
                result.append(parsedThing)
            case is VecDoubleItem:
                result.append(thing as! VecDoubleItem)

            case is [String]:
                let parsedThing = VecStringItem(thing as! [String])
                result.append(parsedThing)
            case is VecStringItem:
                result.append(thing as! VecStringItem)

            case is PushInstruction:
                let parsedThing = InstructionItem(thing as! PushInstruction)
                result.append(parsedThing)
                let key = parsedThing.value
                implicitBranch(&stuff, key: key)

            case is InstructionItem:
                let parsedThing = thing as! InstructionItem
                result.append(parsedThing)
                implicitBranch(&stuff, key: parsedThing.value)

            case is PlushyControl:
                if thing as! PlushyControl == PlushyControl.open {
                    let parsedThing = destructivePlushy2push(&stuff, level: level + 1)
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
            case is CodeItem:
                result.append(thing as! CodeItem)

            case is [Any]:
                var thingCopy = thing as! [Any]
                let parsedThing = destructivePlushy2push(&thingCopy, level: level + 1)
                result.append(CodeItem(parsedThing))

            default:
                break
            }

        }
        return result
    }
}

