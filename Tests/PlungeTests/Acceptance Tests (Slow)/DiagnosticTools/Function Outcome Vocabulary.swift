//
//  Function Outcome Vocabulary.swift
//  PlungeTests
//
//  The terms the function outcome probe works in: the three families, the
//  variants being compared, a harvested situation, and the classes an outcome
//  falls into. See `Function Outcome Probe.swift` for what the probe asks.
//

@testable import Plunge

@MainActor
enum FunctionOutcome {

    enum Family: String, CaseIterable { case map, filter, reduce }

    enum Variant: String, CaseIterable {
        case v0 = "V0 input0 (today)"
        case v1 = "V1 any input, by order"
        case v2 = "V2 stack-fed, last push"
        case v3 = "V3 stack-fed, typed top"
        case v4 = "V4 stack-fed over parent stacks"
        case v5 = "V5 whole collection, run once"
        case v6 = "V6 iterate inside sandbox"
        case v7 = "V7 crux-to-function"
        case v8 = "V8 first working block on code"
        case v9 = "V9 typed projection of the block"
        case v10 = "V10 typed context"
        case v11 = "V11 typed projection + context"
        case v12 = "V12 first typed block on code"
        case v13 = "V13 hybrid: stack-fed + holes"
        case v14 = "V14 hybrid + typed lookup + context"
        case v15 = "V15 hybrid + per-family lookup"
        case v16 = "V16 hybrid + per-family, then typed lookup"
        case v17 = "V17 V16, transformers, type from first run"
        case v18 = "V18 function stack from the top block"
        case v19 = "V19 function stack from every block"

        func applies(to family: Family) -> Bool {
            switch self {
            case .v5, .v6: family != .filter
            default: true
            }
        }

        /// The element is run before the block, so it lands on its stack.
        var isStackFed: Bool { [.v2, .v3, .v4, .v9, .v10, .v11, .v13, .v14, .v17].contains(self) }
        /// The result is the top of the element's stack (`.bool` for filter);
        /// for V17's map, of the stack the first element's run chose.
        var hasTypedResult: Bool { [.v3, .v4, .v9, .v10, .v11, .v13, .v14, .v17].contains(self) }
        /// The element type's constants sit under the element.
        var hasTypedContext: Bool { [.v10, .v11, .v14, .v17].contains(self) }
        /// The block's holes are bound too (accumulator, then element).
        var bindsHoles: Bool { [.v13, .v14, .v17].contains(self) }
        /// Only the block's instructions about the element's type are run.
        var isProjected: Bool { [.v9, .v11].contains(self) }
        /// The block is turned into crux functions, which are sieved for one
        /// that fits (`Block Functions.swift`).
        var usesFunctionStack: Bool { [.v18, .v19].contains(self) }
    }

    /// One harvested moment.
    struct Situation {
        var natural: Bool
        var collection: any Item
        var block: CodeItem
        var inputs: [PushInstruction: any Item]
        var constants: [PushInstruction: any Item]
        /// Every stack but `.exec` and `.error`, top first.
        var stacks: [PushStack: [any Item]]
    }

    /// One variant of one family, applied to one situation.
    struct Call {
        let variant: Variant
        let family: Family
        let situation: Situation
    }

    enum Outcome: Equatable {
        case refused(String)
        case emptyInput, tooShort
        case identity, empty, all, first, last, reshaped, rearranged
        case constant, dependent, dependentRetyped
        /// A filter over bools that kept exactly the trues (the element was its
        /// own verdict), or exactly the falses.
        case keptTrues, keptFalses

        var label: String {
            switch self {
            case .refused(let why): "refused: \(why)"
            case .emptyInput: "empty input"
            case .tooShort: "too short to fold"
            case .identity: "identity"
            case .empty: "empty"
            case .all: "all kept"
            case .first: "first element"
            case .last: "last element"
            case .reshaped: "reshaped (length changed)"
            case .rearranged: "rearranged"
            case .constant: "constant"
            case .dependent: "element-dependent"
            case .dependentRetyped: "element-dependent, new type"
            case .keptTrues: "kept the trues (identity)"
            case .keptFalses: "element-dependent: kept the falses"
            }
        }
    }

    struct Refusal: Error {
        let why: String
        init(_ why: String) { self.why = why }
    }

    /// The stacks a map's results can be collected from.
    static let scalarStacks: Set<PushStack> = [.bool, .int, .double, .char, .string]

    /// The collections a function can take.
    static let collectionStacks: [PushStack] = [.vecInt, .vecDouble, .vecBool, .vecString, .string]

    static func instruction(_ family: Family, over stack: PushStack) -> PushInstruction {
        PushInstruction(rawValue: stack.rawValue + family.rawValue.capitalized)!
    }

    /// The 15 function instructions, with the family and collection of each.
    static let functionInstructions: [PushInstruction: (Family, PushStack)] = {
        var result: [PushInstruction: (Family, PushStack)] = [:]
        for stack in collectionStacks {
            for family in Family.allCases { result[instruction(family, over: stack)] = (family, stack) }
        }
        return result
    }()

    /// The instruction that iterates a collection inside a sandbox (V6).
    static func iterate(over stack: PushStack) -> PushInstruction {
        PushInstruction(rawValue: stack.rawValue + "Iterate")!
    }

    /// Every sandbox step taken, so the report can say what each variant costs.
    static var sandboxSteps = 0

    /// The step budget a whole application gets: the app's default `stepLimit`.
    static let budget = 1_000
    /// Longer collections are cut to this many elements, so a situation costs
    /// at most a few thousand sandbox steps per variant.
    static let maxElements = 8


    // MARK: - Elements

    static func elements(of collection: any Item) -> [any Item]? {
        switch collection {
        case let v as VecIntItem: v.value.map { IntItem($0) }
        case let v as VecDoubleItem: v.value.map { DoubleItem($0) }
        case let v as VecBoolItem: v.value.map { BoolItem($0) }
        case let v as VecStringItem: v.value.map { StringItem($0) }
        case let s as StringItem: s.value.map { CharItem($0) }
        default: nil
        }
    }

    /// The collection of `elements`, of the type `like` is (so an empty one keeps its type).
    static func rebuilt(_ elements: [any Item], like collection: any Item) -> (any Item)? {
        if elements.isEmpty {
            switch collection {
            case is VecIntItem: return VecIntItem([])
            case is VecDoubleItem: return VecDoubleItem([])
            case is VecBoolItem: return VecBoolItem([])
            case is VecStringItem: return VecStringItem([])
            case is StringItem: return StringItem("")
            default: return nil
            }
        }
        return Interpreter.collected(elements, call: [])
    }

    /// Another value of the same type, so a result that ignores its elements
    /// shows up as unchanged.
    static func perturbed(_ element: any Item) -> any Item {
        switch element {
        case let i as IntItem: return IntItem(i.value &+ 7)
        case let d as DoubleItem: return DoubleItem(d.value * 1.5 + 0.25)
        case let b as BoolItem: return BoolItem(!b.value)
        case let s as StringItem: return StringItem(String(s.value.reversed()) + "q")
        case let c as CharItem:
            guard c.value != "z", let scalar = c.value.unicodeScalars.first,
                  let next = UnicodeScalar(scalar.value + 1) else { return CharItem("a") }
            return CharItem(Character(next))
        default: return element
        }
    }

    static func render(_ item: any Item) -> String { item.pretty() }
}
