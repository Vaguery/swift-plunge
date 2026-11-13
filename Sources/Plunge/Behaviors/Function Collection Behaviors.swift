//
//  Function Collection Behaviors.swift
//  Plunge
//
//  Collection operations that take a function (2026-11-12), beyond map, filter
//  and reduce: zip, scan, sort by a key, the least and greatest by a key
//  (here), and the predicate searches and cuts (`Predicate Behaviors.swift`).
//
//  Each takes the topmost function on `.function` that fits its job, through the
//  sieve, and fills it as map does (`prepare`): the elements take the first holes
//  of their type, every other hole is read from the run's stacks and left. Each
//  application runs in a sandbox with its steps charged to the run (`call`).
//  - **zip** `a b f .vecIntZip`: `b` the top vector and `a` the first below it of
//    the same length; f's first two holes of the element type take a[i] and
//    b[i]; the results are collected as map's are. With no result, a[i] passes
//    through.
//  - **scan**: a fold that keeps every running value, from the first element
//    (an empty collection gives an empty one). With no result, the running
//    value carries on.
//  - **key** (`SortBy`, `MinBy`, `MaxBy`): one element hole, and a bool, int,
//    double, string or char to order by, in the language's orders (false before
//    true, NaN above every number). An element with no key refuses.
//
//  Provenance: as map's, the fillers read, the collection(s), the function and
//  the instruction, then the clean-up of what was read. A sort keeps its
//  elements' provenance; the least and greatest are taken out of the collection
//  (`tracedElement`), as `vecIntMax` takes its element.
//

nonisolated extension Interpreter {

    // MARK: - A collection, as the function forms see it

    /// A vector's or a string's elements, and how to rebuild a collection of
    /// some of them.
    struct Elements {
        let stack: PushStack
        let element: PushStack
        /// Each element as an item with no history, to fill a hole.
        let items: [any Item]
        /// The collection of the elements at `kept`, in that order, with their
        /// provenance, recording `call`.
        let rebuild: ([Int], [any Item]) -> any Item
        /// Element `index` as its origin says to take it out (nil for a source's).
        let traced: (Int) -> (any Item)?
    }

    static func elements(of collection: any Item, _ recording: ProvenanceRecording) -> Elements {
        func vector<V: VectorItem>(_ v: V) -> Elements {
            Elements(stack: V.pushStack, element: V.Scalar.pushStack,
                     items: v.value.map { V.Scalar($0, call: []) },
                     rebuild: { kept, call in
                         V(kept.map { v.value[$0] }, call: call,
                           members: recording.pieces({ let o = v.origins(); return kept.map { o[$0] } }()))
                     },
                     traced: { v.tracedElement(at: $0, recording) })
        }
        switch collection {
        case let v as VecBoolItem: return vector(v)
        case let v as VecIntItem: return vector(v)
        case let v as VecDoubleItem: return vector(v)
        case let v as VecStringItem: return vector(v)
        default:
            let text = collection.exactly(StringItem.self)!
            let characters = Array(text.value)
            return Elements(stack: .string, element: .char, items: characters.map { CharItem($0) },
                            rebuild: { kept, call in
                                StringItem(String(kept.map { characters[$0] }), call: call,
                                           members: recording.pieces({ let o = text.origins()
                                                                       return kept.map { o[$0] } }()))
                            },
                            traced: { text.tracedElement(at: $0, recording) })
        }
    }

    /// The function in `arguments.last`, prepared for `family` over the
    /// collection in `arguments[0]`.
    static func application(_ family: Family, _ arguments: [any Item],
                            _ context: ReadContext) -> Result<Application, Refusal> {
        let function = arguments.last!.exactly(FunctionItem.self)!
        let element = elementStack[PushStack.defaultStack(for: arguments[0])!]!
        return prepare(function, family, over: element, context)
    }

    /// Whether key `a` orders before key `b`, in the language's orders.
    static func keyPrecedes(_ a: any Item, _ b: any Item) -> Bool {
        switch (a, b) {
        case let (x as IntItem, y as IntItem): x.value < y.value
        case let (x as DoubleItem, y as DoubleItem): doublePrecedes(x.value, y.value)
        case let (x as StringItem, y as StringItem): x.value < y.value
        case let (x as CharItem, y as CharItem): x.value < y.value
        case let (x as BoolItem, y as BoolItem): boolPrecedes(x.value, y.value)
        default: false
        }
    }

    /// Every element's key, or the refusal for the first with none.
    static func keys(_ application: Application, _ items: [any Item],
                     _ context: ReadContext) -> Result<[any Item], Refusal> {
        var keys: [any Item] = []
        for (index, item) in items.enumerated() {
            do throws(ApplicationFailure) {
                guard let key = try call(application, [item], context) else {
                    return .failure(Refusal("no key for element \(index)", kind: .notFound))
                }
                keys.append(key)
            } catch {
                return .failure(error.refusal)
            }
        }
        return .success(keys)
    }

    // MARK: - Zip

    static func zipBehavior(_ instruction: PushInstruction, over collection: PushStack) -> Behavior {
        functionBehavior(instruction, .zip, over: collection, paired: true, produces: mapResults,
                         summary: "Zips with the topmost function on `.function` that fits: `a b f .\(instruction)` "
                         + "gives f(a[i], b[i]) for each i, a[i] and b[i] in its first two "
                         + "\(elementStack[collection]!) holes, where b is the top \(collection.noun) and a the "
                         + "first one below it of the same length (a miss if there is none); refuses when no "
                         + "function fits, filler runs short, results are mixed or steps run out.") { a, context in
            let (top, partner) = (a[0], a[1])
            let app: Application
            switch application(.zip, a, context) {
            case .failure(let why): return refusal(instruction, why, context)
            case .success(let ready): app = ready
            }
            let (left, right) = (elements(of: partner, context.recording), elements(of: top, context.recording))
            let call = { (stack: PushStack) in
                context.recording(app.recorded(instruction, collections: [partner, top], producing: stack))
            }
            guard !left.items.isEmpty else { return [Router(collection, left.rebuild([], call(collection)))] }
            var results: [any Item] = []
            for index in left.items.indices {
                do throws(ApplicationFailure) {
                    results.append(try Self.call(app, [left.items[index], right.items[index]], context)
                                   ?? left.items[index])
                } catch {
                    return refusal(instruction, error.refusal, context)
                }
            }
            guard let made = collected(results, call: []), let stack = PushStack.defaultStack(for: made),
                  let output = collected(results, call: call(stack)) else {
                return refusal(instruction, Refusal("results are not all one collectable type", kind: .mixedTypes),
                               context)
            }
            return [Router(stack, output)]
        }
    }

    // MARK: - Scan

    static func scanBehavior(_ instruction: PushInstruction, over collection: PushStack) -> Behavior {
        functionBehavior(instruction, .reduce, over: collection, produces: .results([collection]),
                         summary: "Folds the topmost function on `.function` that fits over a \(collection.noun) "
                         + "from the first element, keeping every running value: element i of the result is the "
                         + "fold of elements 0 through i; refuses when none fits, filler runs short or steps run "
                         + "out.") { a, context in
            let app: Application
            switch application(.reduce, a, context) {
            case .failure(let why): return refusal(instruction, why, context)
            case .success(let ready): app = ready
            }
            let view = elements(of: a[0], context.recording)
            let call = context.recording(app.recorded(instruction, a[0], producing: collection))
            guard var running = view.items.first else { return [Router(collection, view.rebuild([], call))] }
            var results = [running]
            for item in view.items.dropFirst() {
                do throws(ApplicationFailure) {
                    running = try Self.call(app, [running, item], context) ?? running
                } catch {
                    return refusal(instruction, error.refusal, context)
                }
                results.append(running)
            }
            guard let output = collected(results, call: call), PushStack.defaultStack(for: output) == collection else {
                return refusal(instruction, Refusal("the running values are not all \(view.element) items",
                                                    kind: .mixedTypes), context)
            }
            return [Router(collection, output)]
        }
    }

    // MARK: - By a key

    static func sortByBehavior(_ instruction: PushInstruction, over collection: PushStack) -> Behavior {
        functionBehavior(instruction, .key, over: collection, produces: .results([collection]),
                         summary: "Sorts a \(collection.noun) stably by the key the topmost function on `.function` "
                         + "that fits gives each element (false before true, NaN last); refuses an element with "
                         + "no key, or when none fits, filler runs short or steps run out.") { a, context in
            let app: Application
            switch application(.key, a, context) {
            case .failure(let why): return refusal(instruction, why, context)
            case .success(let ready): app = ready
            }
            let view = elements(of: a[0], context.recording)
            switch keys(app, view.items, context) {
            case .failure(let why): return refusal(instruction, why, context)
            case .success(let keys):
                let order = sortedPositions(keys, by: keyPrecedes)
                return [Router(collection, view.rebuild(order, context.recording(
                    app.recorded(instruction, a[0], producing: collection))))]
            }
        }
    }

    static func extremeByBehavior(_ instruction: PushInstruction, over collection: PushStack,
                                  greatest: Bool) -> Behavior {
        let element = elementStack[collection]!
        return functionBehavior(instruction, .key, over: collection, reading: true, produces: .results([element]),
                                summary: "Pushes the first element of a \(collection.noun) with the "
                                + "\(greatest ? "greatest" : "least") key the topmost function on `.function` that "
                                + "fits gives it, leaving the \(collection.noun); refuses an empty one, an element "
                                + "with no key, or when none fits, filler runs short or steps run out.") { a, context in
            let app: Application
            switch application(.key, a, context) {
            case .failure(let why): return refusal(instruction, why, context)
            case .success(let ready): app = ready
            }
            let view = elements(of: a[0], context.recording)
            guard !view.items.isEmpty else {
                return refusal(instruction, Refusal("an empty \(collection.noun) has no element",
                                                    kind: .emptyCollection), context)
            }
            switch keys(app, view.items, context) {
            case .failure(let why): return refusal(instruction, why, context)
            case .success(let keys):
                let index = extremePosition(keys, greatest: greatest, by: keyPrecedes)
                let found = view.traced(index) ?? rebuilt(view.items[index], call: context.recording(
                    app.recorded(instruction, collections: [a[0]], alsoRead: [collection], producing: element)))
                return [Router(element, found)]
            }
        }
    }
}
