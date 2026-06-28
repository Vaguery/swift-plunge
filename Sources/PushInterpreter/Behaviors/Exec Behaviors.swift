//
//  Exec Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule


extension Interpreter {
            
    static let execBehaviors:[PushInstruction : Behavior] =
    [
        
        
        // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L335-L343
        //  "`:exec-do*while` pops the top of the `:exec` stack. It builds and pushes a continuation to the `:exec` stack which is `'([item] :exec-while [item])` (_Note_ the instruction is `:exec-while` in the continuation form)."

        
        .execDoWhile :
            Behavior(
                .execDoWhile,
                takes: [.bool, .exec],
                fxn: {a in
                    var (x, y) = (a[0] as! BoolItem, a[1])
                    
                    var yCopy = y
                    yCopy.isContingent = true
                    yCopy.index = 2
                    yCopy.call = [x, InstructionItem(.execDoWhile), y]
                    
                    var results = [Router(.exec, yCopy)]

                    if x.value {
                       results.append(
                            Router(
                                .exec,
                                InstructionItem(.execWhile,
                                call: [x, InstructionItem(.execDoWhile), y],
                                isContingent: true,
                                index:1 )))
                        var yCopy2 = y
                        yCopy2.isContingent = true
                        yCopy2.index = 0
                        yCopy2.call = [x, InstructionItem(.execDoWhile), y]

                        results.append(Router(.exec, yCopy2))
                    }
                    return results
                }
            ),

        
        
//        // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L13-L32
//

        .execDoCount :
            Behavior(
                .execDoCount,
                takes: [.int, .exec],
                fxn: {a in
                    var (x, y) = (a[0] as! IntItem, a[1])

                    var results = [Router]()
                    let counter = x.value

                    if counter < 1 {
                        results = [
                            Router(.exec, y),
                            Router(.exec, x)
                        ]
                    } else {
                        y.index = 3

                        var newInstruction = InstructionItem(.execDoRange)
                        newInstruction.call = [x, InstructionItem(.execDoCount), y]
                        newInstruction.isContingent = Behavior.netContingency(of: x,y)
                        newInstruction.index = 2

                        x.index = 1

                        var newEndPoint = IntItem(0)
                        newEndPoint.call = [x, InstructionItem(.execDoCount), y]
                        newEndPoint.isContingent = Behavior.netContingency(of: x,y)
                        newEndPoint.index = 0

                        results = [
                            Router(.exec, y),                // index = 3
                            Router(.exec, newInstruction),   // index = 2
                            Router(.exec, x),                // index = 1
                            Router(.exec, newEndPoint)       // index = 0
                        ]
                    }
                    return results
                }),

        
//        // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L183-L203

        .execDoTimes :
            Behavior(
                .execDoTimes,
                takes: [.int, .exec],
                fxn: {a in
                    let (x,y) = (a[0], a[1])
                    let counter = (x as! IntItem).value
                    var yCopy = y
                    yCopy.isContingent = Behavior.netContingency(of: x,y)
                    yCopy.call = [x, InstructionItem(.execDoTimes), y]

                    var results = [Router]()

                    if counter < 1 {
                        yCopy.index = 0
                        results = [Router(.exec, yCopy)]
                    } else {
                        var newCounter = IntItem(counter - 1)
                        newCounter.isContingent = Behavior.netContingency(of: x,y)
                        newCounter.call = [x, InstructionItem(.execDoTimes), y]
                        newCounter.index = 1

                        var newInstruction = InstructionItem(.execDoTimes)
                        newInstruction.isContingent = Behavior.netContingency(of: x,y)
                        newInstruction.call = [x, InstructionItem(.execDoTimes), y]
                        newInstruction.index = 2
                        
                        yCopy.index = 3
                        results.append(
                            Router(.exec, CodeItem( [y, newCounter, newInstruction, yCopy]))
                            )
                    }
                    return results
                }),

        
        
//        // using my own code as an example from: https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L83-L112

            .execDoRange :
                Behavior(
                    .execDoRange,
                    takes: [.int, .int, .exec],
                    fxn: {a in
                        var (x,y,z) = (a[0], a[1], a[2])
                        let end = (x as! IntItem).value
                        let start = (y as! IntItem).value
                        var zCopy = z
                        zCopy.isContingent = Behavior.netContingency(of: x,y,z)
                        zCopy.call = [y, x, InstructionItem(.execDoRange), z]

                        var results = [Router]()

                        if abs(start - end) <= 1 {
                            zCopy.index = 1
                            results = [Router(.exec, zCopy), Router(.exec, y)]
                        } else {
                            let direction = start < end ? 1 : -1
                            var newCounter = IntItem(start + direction)
                            newCounter.isContingent = Behavior.netContingency(of: x,y,z)
                            newCounter.call = [y, x, InstructionItem(.execDoRange), z]
                            newCounter.index = 2

                            var newInstruction = InstructionItem(.execDoRange)
                            newInstruction.isContingent = Behavior.netContingency(of: x,y,z)
                            newInstruction.call = [y, x, InstructionItem(.execDoRange), z]
                            newInstruction.index = 4

                            z.index = 1
                            x.index = 3
                            zCopy.index = 5
                            results = [
                                Router(.exec, zCopy),           // index = 5
                                Router(.exec, newInstruction),  // index = 4
                                Router(.exec, x),               // index = 3
                                Router(.exec, newCounter),      // index = 2
                                Router(.exec, z),               // index = 1
                                Router(.exec, y)                // index = 0
                                ]
                        }
                        return results
                    }),

        
        
        .execIf :
            Behavior(
                .execIf,
                takes: [.bool, .exec, .exec],
                fxn: {a in
                    let (x, y, z) = (a[0] as! BoolItem, a[1], a[2])
                    var result = x.value ? y : z
                    result.isContingent = true
                    result.call = [InstructionItem(.execIf), y, z]
                    return [ Router(.exec, result) ]
                }
            ),
        
        .execK :
            Behavior(
                .execK,
                takes: [.exec, .exec],
                fxn: {a in
                    var (x, y) = (a[0], a[1])
                    x.call = [InstructionItem(.execK), x, y]
                    return [
                        Router(.exec, x)
                    ]
                }
            ),
        
        .execY :
            Behavior(
                .execY,
                takes: [.exec],
                fxn: {a in
                    let (x) = (a[0])
                    var results = [Router]()
                    results.append(
                        Router(
                            .exec,
                            CodeItem(
                                [ InstructionItem(.execY), a[0] ]
                            )
                        )
                    )
                    results.append(
                        Router(.exec, a[0])
                        )
                    return results
                }
            ),
        
        .execS :
            Behavior(
                .execS,
                takes: [.exec, .exec, .exec],
                fxn: {a in
                    var (x,y,z) = (a[0], a[1], a[2])
                    var results = [Router]()
                    
                    results.append(
                        Router(.exec,
                            CodeItem(
                                [a[1], a[2]],
                                call: [InstructionItem(.execS), z, y, x],
                                isContingent: Behavior.netContingency(of: x,y,z),
                                index: 2
                                ))
                        )
                    results.append(Router(.exec,z))
                    results.append(Router(.exec, x))
                    return results
                }
            ),

        .execWhen :
            Behavior(
                .execWhen,
                takes: [.bool, .exec],
                fxn: {a in
                    var (x, y) = (a[0] as! BoolItem, a[1])
                    var results = [Router]()
                    
                    if x.value {
                        y.call = [x, InstructionItem(.execWhen), y]
                        y.isContingent = Behavior.netContingency(of: x, y )
                        results.append(
                            Router(.exec,y)
                            )
                    }
                    return results
                }
            ),
        
        .execWhile :
            Behavior(
                .execWhile,
                takes: [.bool, .exec],
                fxn: {a in
                    var (x, y) = (a[0] as! BoolItem, a[1])
                    
                    var results = [Router]()

                    if x.value {
                        var yCopy = y
                        yCopy.isContingent = true
                        yCopy.index = 2
                        yCopy.call = [x, InstructionItem(.execDoWhile), y]
                        results.append(Router(.exec, yCopy))
                       
                        results.append(
                            Router(
                                .exec,
                                InstructionItem(.execWhile,
                                call: [x, InstructionItem(.execDoWhile), y],
                                isContingent: true,
                                index:1 )))
                        
                        var yCopy2 = y
                        yCopy2.isContingent = true
                        yCopy2.index = 0
                        yCopy2.call = [x, InstructionItem(.execDoWhile), y]

                        results.append(Router(.exec, yCopy2))
                    }
                    return results
                }
            ),

        ]
}
