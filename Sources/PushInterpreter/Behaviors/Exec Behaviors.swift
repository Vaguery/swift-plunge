//
//  Exec Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule

extension Interpreter {

    // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L335-L343
    //  "`:exec-do*while` pops the top of the `:exec` stack. It builds and pushes a continuation to the `:exec` stack which is `'([item] :exec-while [item])` (_Note_ the instruction is `:exec-while` in the continuation form)."
    static let execDoWhile_Behavior =
        Behavior(
            .execDoWhile,
            takes: [.bool, .exec],
            fxn: { a in
                var (x, y) = (a[0] as! BoolItem, a[1])

                var yCopy = y
                yCopy.isContingent = x.isContingent
                yCopy.index = 2
                yCopy.call = [x, InstructionItem(.execDoWhile)]

                var results = [Router(.exec, yCopy)]

                if x.value {
                    results.append(
                        Router(
                            .exec,
                            InstructionItem(
                                .execWhile,
                                call: [x, InstructionItem(.execDoWhile)],
                                isContingent: x.isContingent,
                                index: 1
                            )
                        )
                    )
                    var yCopy2 = y
                    yCopy2.isContingent = Behavior.netContingency(of:x,y)
                    yCopy2.index = 0
                    yCopy2.call = [x, InstructionItem(.execDoWhile)]

                    results.append(Router(.exec, yCopy2))
                }
                return results
            }
        )

    // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L13-L32
    //

    static let execDoCount_Behavior =
        Behavior(
            .execDoCount,
            takes: [.int, .exec],
            fxn: { a in
                var (x, y) = (a[0] as! IntItem, a[1])

                var results = [Router]()
                let counter = x.value

                if counter < 1 {
                    results = [
                        Router(.exec, y),
                        Router(.exec, x),
                    ]
                } else {
                    y.index = 3

                    var newInstruction = InstructionItem(.execDoRange)
                    newInstruction.call = [x, InstructionItem(.execDoCount)]
                    newInstruction.isContingent = Behavior.netContingency(
                        of: x,
                        y
                    )
                    newInstruction.index = 2

                    x.index = 1

                    var newEndPoint = IntItem(0)
                    newEndPoint.call = [x, InstructionItem(.execDoCount)]
                    newEndPoint.isContingent = Behavior.netContingency(of: x)
                    newEndPoint.index = 0

                    results = [
                        Router(.exec, y),  // index = 3
                        Router(.exec, newInstruction),  // index = 2
                        Router(.exec, x),  // index = 1
                        Router(.exec, newEndPoint),  // index = 0
                    ]
                }
                return results
            }
        )

    //        // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L183-L203
    static let execDoTimes_Behavior =
        Behavior(
            .execDoTimes,
            takes: [.int, .exec],
            fxn: { a in
                let (intArg, execArg) = (a[0], a[1])
                let counter = (intArg as! IntItem).value
                var yCopy = execArg
                yCopy.isContingent = Behavior.netContingency(of: intArg, execArg)
                yCopy.call = [intArg, InstructionItem(.execDoTimes)]

                var results = [Router]()

                if counter < 1 {
                    yCopy.index = 0
                    results = [Router(.exec, yCopy)]
                } else {
                    var newCounter = IntItem(counter - 1)
                    newCounter.isContingent =
                        Behavior.netContingency(of: intArg, execArg)
                    newCounter.call =
                        [intArg, InstructionItem(.execDoTimes)]
                    newCounter.index = 1

                    var newInstruction = InstructionItem(.execDoTimes)
                    newInstruction.isContingent =
                        Behavior.netContingency( of: intArg, execArg )
                    newInstruction.call =
                        [intArg, InstructionItem(.execDoTimes)]
                    newInstruction.index = 2

                    yCopy.index = 3
                    results.append(
                        Router(
                            .exec,
                            CodeItem([execArg, newCounter, newInstruction, yCopy])
                        )
                    )
                }
                return results
            }
        )

    //        // using my own code as an example from: https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L83-L112
    static let execDoRange_Behavior =
        Behavior(
            .execDoRange,
            takes: [.int, .int, .exec],
            fxn: { a in
                var (x, y, z) = (a[0], a[1], a[2])
                let end = (x as! IntItem).value
                let start = (y as! IntItem).value
                var zCopy = z
                zCopy.isContingent = Behavior.netContingency(of: x, y)
                zCopy.call = [y, x, InstructionItem(.execDoRange)]

                var results = [Router]()

                if abs(start - end) <= 1 {
                    zCopy.index = 1
                    results = [Router(.exec, zCopy), Router(.exec, y)]
                } else {
                    let direction = start < end ? 1 : -1
                    var newCounter = IntItem(start + direction)
                    newCounter.isContingent = Behavior.netContingency(
                        of: x,
                        y
                    )
                    newCounter.call = [y, x, InstructionItem(.execDoRange)]
                    newCounter.index = 2

                    var newInstruction = InstructionItem(.execDoRange)
                    newInstruction.isContingent = Behavior.netContingency(
                        of: x,
                        y
                    )
                    newInstruction.call = [
                        y, x, InstructionItem(.execDoRange)
                    ]
                    newInstruction.index = 4

                    z.index = 1
                    x.index = 3
                    zCopy.index = 5
                    results = [
                        Router(.exec, zCopy),  // index = 5
                        Router(.exec, newInstruction),  // index = 4
                        Router(.exec, x),  // index = 3
                        Router(.exec, newCounter),  // index = 2
                        Router(.exec, z),  // index = 1
                        Router(.exec, y),  // index = 0
                    ]
                }
                return results
            }
        )

    static let execIf_Behavior =
        Behavior(
            .execIf,
            takes: [.bool, .exec, .exec],
            fxn: { a in
                let (x, y, z) = (a[0] as! BoolItem, a[1], a[2])
                var result = x.value ? y : z
                result.isContingent = x.isContingent
                result.call = [x, InstructionItem(.execIf), y, z]
                return [Router(.exec, result)]
            }
        )

    static let execK_Behavior =
        Behavior(
            .execK,
            takes: [.exec, .exec],
            fxn: { a in
                var (x, y) = (a[0], a[1])
                x.call = [InstructionItem(.execK), x, y]
                return [
                    Router(.exec, x)
                ]
            }
        )

    static let execY_Behavior =
        Behavior(
            .execY,
            takes: [.exec],
            fxn: { a in
                let (x) = (a[0])
                var results = [Router]()
                results.append(
                    Router(
                        .exec,
                        CodeItem(
                            [InstructionItem(.execY), a[0]]
                        )
                    )
                )
                results.append(
                    Router(.exec, a[0])
                )
                return results
            }
        )

    static let execS_Behavior =
        Behavior(
            .execS,
            takes: [.exec, .exec, .exec],
            fxn: { a in
                var (x, y, z) = (a[0], a[1], a[2])
                var results = [Router]()

                results.append(
                    Router(
                        .exec,
                        CodeItem(
                            [a[1], a[2]],
                            call: [InstructionItem(.execS), z, y, x],
                            isContingent: Behavior.netContingency(of: x, y, z),
                            index: 2
                        )
                    )
                )
                results.append(Router(.exec, z))
                results.append(Router(.exec, x))
                return results
            }
        )

    static let execWhen_Behavior =
        Behavior(
            .execWhen,
            takes: [.bool, .exec],
            fxn: { a in
                var (x, y) = (a[0] as! BoolItem, a[1])
                var results = [Router]()

                if x.value {
                    y.call = [x, InstructionItem(.execWhen), y]
                    y.isContingent = Behavior.netContingency(of: x, y)
                    results.append(
                        Router(.exec, y)
                    )
                }
                return results
            }
        )

    static let execWhile_Behavior =
        Behavior(
            .execWhile,
            takes: [.bool, .exec],
            fxn: { a in
                var (x, y) = (a[0] as! BoolItem, a[1])

                var results = [Router]()

                if x.value {
                    var yCopy = y
                    yCopy.isContingent = x.isContingent
                    yCopy.index = 2
                    yCopy.call = [x, InstructionItem(.execDoWhile), y]
                    results.append(Router(.exec, yCopy))

                    results.append(
                        Router(
                            .exec,
                            InstructionItem(
                                .execWhile,
                                call: [x, InstructionItem(.execDoWhile), y],
                                isContingent: x.isContingent,
                                index: 1
                            )
                        )
                    )

                    var yCopy2 = y
                    yCopy2.isContingent = x.isContingent
                    yCopy2.index = 0
                    yCopy2.call = [x, InstructionItem(.execDoWhile), y]

                    results.append(Router(.exec, yCopy2))
                }
                return results
            }
        )

    static let execBehaviors:[PushInstruction : Behavior] =
    [
        .execDoCount : execDoCount_Behavior,
        .execDoRange : execDoRange_Behavior,
        .execDoTimes : execDoTimes_Behavior,
        .execDoWhile : execDoWhile_Behavior,
        .execIf : execIf_Behavior,
        .execK : execK_Behavior,
        .execS : execS_Behavior,
        .execWhen : execWhen_Behavior,
        .execWhile : execWhile_Behavior,
        .execY : execY_Behavior,
    ]
}
