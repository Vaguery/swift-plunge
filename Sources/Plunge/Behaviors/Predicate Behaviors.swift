//
//  Predicate Behaviors.swift
//  Plunge
//
//  Searches and cuts by a predicate (2026-11-12): the topmost function on
//  `.function` with a hole of the element's type and a bool result (filter's
//  fit), applied to elements in order.
//
//  - **Searches read and leave** the collection: `OccurrencesWhere` (how many),
//    `ContainsWhere` (any), `AllWhere` (every; true for none), `IndexOfWhere`
//    and `LastIndexOfWhere` (where; `notFound` when none), `FindWhere` (the
//    element itself, taken out as `vecIntNth` takes it; `notFound` when none).
//  - **Cuts take it**: `TakeWhile` and `DropWhile` (the longest prefix that
//    holds, and the rest), and `Partition` (those that hold below, the others on
//    top, two results with selecting cruxes).
//
//  An application with no result counts as false, as filter's does. A search
//  stops at the element that decides it, so it charges only the steps it ran.
//

nonisolated extension Interpreter {

    /// Whether `application` holds for `item`.
    static func holds(_ application: Application, _ item: any Item,
                      _ context: ReadContext) throws(ApplicationFailure) -> Bool {
        (try call(application, [item], context) as? BoolItem)?.value == true
    }

    /// The index of the first (`last`: the last) element that holds, nil for none.
    static func firstHolding(_ application: Application, _ items: [any Item], last: Bool,
                             _ context: ReadContext) throws(ApplicationFailure) -> Int? {
        for index in last ? Array(items.indices.reversed()) : Array(items.indices)
        where try holds(application, items[index], context) {
            return index
        }
        return nil
    }

    // MARK: - Searches

    enum Search {
        case occurrences, contains, all, indexOf, lastIndexOf, find

        var suffix: String {
            switch self {
            case .occurrences: "OccurrencesWhere"
            case .contains: "ContainsWhere"
            case .all: "AllWhere"
            case .indexOf: "IndexOfWhere"
            case .lastIndexOf: "LastIndexOfWhere"
            case .find: "FindWhere"
            }
        }

        func result(_ element: PushStack) -> PushStack {
            switch self {
            case .occurrences, .indexOf, .lastIndexOf: .int
            case .contains, .all: .bool
            case .find: element
            }
        }

        func summary(_ collection: PushStack) -> String {
            let what = switch self {
            case .occurrences: "Counts the elements of a \(collection.noun) for which"
            case .contains: "Tells whether some element of a \(collection.noun) is one for which"
            case .all: "Tells whether every element of a \(collection.noun) (true for none) is one for which"
            case .indexOf: "Pushes the index of the first element of a \(collection.noun) for which"
            case .lastIndexOf: "Pushes the index of the last element of a \(collection.noun) for which"
            case .find: "Pushes the first element of a \(collection.noun) for which"
            }
            let absent = self == .indexOf || self == .lastIndexOf || self == .find ? " refuses when there is none, "
                + "or" : " refuses"
            return what + " the topmost bool-valued function on `.function` that fits gives true, leaving the "
                + "\(collection.noun);" + absent + " when none fits, filler runs short or steps run out."
        }
    }

    static func searchBehavior(_ search: Search, over collection: PushStack) -> Behavior {
        let instruction = PushInstruction(rawValue: collection.rawValue + search.suffix)!
        let element = elementStack[collection]!
        let resultStack = search.result(element)
        return functionBehavior(instruction, .filter, over: collection, reading: true,
                                produces: .results([resultStack]), summary: search.summary(collection)) { a, context in
            let app: Application
            switch application(.filter, a, context) {
            case .failure(let why): return refusal(instruction, why, context)
            case .success(let ready): app = ready
            }
            let view = elements(of: a[0], context.recording)
            let call = {
                context.recording(app.recorded(instruction, collections: [a[0]], alsoRead: [collection],
                                               producing: resultStack))
            }
            do throws(ApplicationFailure) {
                return try Searching(search: search, instruction: instruction, app: app, view: view,
                                     element: element, call: call).result(context)
            } catch {
                return refusal(instruction, error.reason, context)
            }
        }
    }

    /// One search over one collection.
    struct Searching {
        let search: Search
        let instruction: PushInstruction
        let app: Application
        let view: Elements
        let element: PushStack
        let call: () -> [any Item]

        /// The search's result, or its refusal when nothing holds.
        func result(_ context: ReadContext) throws(ApplicationFailure) -> [Router] {
            let notFound = Refusal("no element holds", kind: .notFound)
            switch search {
            case .occurrences:
                var count = 0
                for item in view.items where try holds(app, item, context) { count += 1 }
                return [Router(.int, IntItem(count, call: call()))]
            case .contains:
                let found = try firstHolding(app, view.items, last: false, context) != nil
                return [Router(.bool, BoolItem(found, call: call()))]
            case .all:
                var every = true
                for item in view.items where try !holds(app, item, context) { every = false; break }
                return [Router(.bool, BoolItem(every, call: call()))]
            case .indexOf, .lastIndexOf:
                guard let index = try firstHolding(app, view.items, last: search == .lastIndexOf, context) else {
                    return refusal(instruction, notFound, context)
                }
                return [Router(.int, IntItem(index, call: call()))]
            case .find:
                guard let index = try firstHolding(app, view.items, last: false, context) else {
                    return refusal(instruction, notFound, context)
                }
                return [Router(element, view.traced(index) ?? rebuilt(view.items[index], call: call()))]
            }
        }
    }

    // MARK: - Cuts

    enum Cut {
        case takeWhile, dropWhile, partition

        var suffix: String {
            switch self {
            case .takeWhile: "TakeWhile"
            case .dropWhile: "DropWhile"
            case .partition: "Partition"
            }
        }

        func summary(_ collection: PushStack) -> String {
            let what = switch self {
            case .takeWhile: "Keeps the longest prefix of a \(collection.noun) whose elements"
            case .dropWhile: "Drops the longest prefix of a \(collection.noun) whose elements"
            case .partition: "Splits a \(collection.noun) into the elements that (below) and do not (on top)"
            }
            return what + " the topmost bool-valued function on `.function` that fits holds for, in order; refuses "
                + "when none fits, filler runs short or steps run out."
        }
    }

    static func cutBehavior(_ cut: Cut, over collection: PushStack) -> Behavior {
        let instruction = PushInstruction(rawValue: collection.rawValue + cut.suffix)!
        let produces: Produces = cut == .partition ? .results([collection, collection]) : .results([collection])
        return functionBehavior(instruction, .filter, over: collection, produces: produces,
                                summary: cut.summary(collection)) { a, context in
            let app: Application
            switch application(.filter, a, context) {
            case .failure(let why): return refusal(instruction, why, context)
            case .success(let ready): app = ready
            }
            let view = elements(of: a[0], context.recording)
            var passing: [Bool] = []
            do throws(ApplicationFailure) {
                for item in view.items {
                    let passes = try holds(app, item, context)
                    passing.append(passes)
                    if !passes && cut != .partition { break }
                }
            } catch {
                return refusal(instruction, error.reason, context)
            }
            let all = Array(view.items.indices)
            switch cut {
            case .takeWhile, .dropWhile:
                let prefix = passing.prefix { $0 }.count
                let kept = cut == .takeWhile ? Array(all.prefix(prefix)) : Array(all.dropFirst(prefix))
                return [Router(collection, view.rebuild(kept, context.recording(
                    app.recorded(instruction, a[0], producing: collection))))]
            case .partition:
                let source = app.read + [a[0], app.function, InstructionItem(instruction)]
                let parts = [all.filter { passing[$0] }, all.filter { !passing[$0] }]
                return parts.enumerated().map { produced, kept in
                    Router(collection, view.rebuild(kept, context.recording(
                        Behavior.reading(sorted: app.counts, producing: collection,
                                         from: Behavior.selecting(produced, of: 2, on: collection, from: source)))))
                }
            }
        }
    }

    // MARK: - The family

    /// The collections every function form covers.
    static let functionCollections: [PushStack] = [.vecBool, .vecInt, .vecDouble, .vecString, .string]

    static let functionCollectionBehaviors: [PushInstruction: Behavior] = {
        var family: [PushInstruction: Behavior] = [:]
        func add(_ behavior: Behavior) { family[behavior.name] = behavior }
        for collection in functionCollections {
            let prefix = collection.rawValue
            add(zipBehavior(PushInstruction(rawValue: prefix + "Zip")!, over: collection))
            add(scanBehavior(PushInstruction(rawValue: prefix + "Scan")!, over: collection))
            add(sortByBehavior(PushInstruction(rawValue: prefix + "SortBy")!, over: collection))
            add(extremeByBehavior(PushInstruction(rawValue: prefix + "MinBy")!, over: collection, greatest: false))
            add(extremeByBehavior(PushInstruction(rawValue: prefix + "MaxBy")!, over: collection, greatest: true))
            for search in [Search.occurrences, .contains, .all, .indexOf, .lastIndexOf, .find] {
                add(searchBehavior(search, over: collection))
            }
            for cut in [Cut.takeWhile, .dropWhile, .partition] { add(cutBehavior(cut, over: collection)) }
        }
        return family
    }()
}
