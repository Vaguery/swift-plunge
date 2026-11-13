//
//  Printed Form Tests.swift
//  PlungeTests
//
//  The rule for `pretty()`: from an item's printed text alone, you can tell its
//  type and its value. Numbers, text, vectors (`[ ]`) and code blocks (`( )`)
//  have short forms; everything else prints as `«type …»`; and every item has an
//  explicit `«type …»` form for when the short one isn't enough (STYLE.md).
//

@testable import Plunge
import Testing

@Suite
struct PrintedFormTests {

    static func counting(_ from: Int, _ to: Int, cursor: Int = 0, body: CodeItem? = nil) -> IteratorItem {
        IteratorItem(kind: .counting(stride: 1), origin: IntItem(from), destination: IntItem(to), body: body,
                     emits: true, cursor: cursor)
    }

    static func walk(_ kind: IteratorKind, _ origin: any Item) -> IteratorItem {
        IteratorItem(kind: kind, origin: origin, body: nil, emits: true)
    }

    /// Items chosen to be easy to confuse: the same digits as different types,
    /// the four empty vectors, a bare and a derived function with one body,
    /// iterators of every walking kind over one string, and containers holding
    /// each other.
    static let confusable: [any Item] = [
        IntItem(5), DoubleItem(5), StringItem("5"), CharItem("5"), VecIntItem([5]), VecDoubleItem([5]),
        VecStringItem(["5"]), CodeItem([IntItem(5)]), CodeItem([StringItem("5")]),
        BoolItem(true), StringItem("true"), VecBoolItem([true]), InstructionItem(.intAdd), StringItem(".intAdd"),
        VecIntItem([]), VecDoubleItem([]), VecBoolItem([]), VecStringItem([]), CodeItem([]), StringItem(""),
        StringItem("a\"b"), StringItem("a"), VecStringItem(["a", "b"]), VecStringItem(["a\", \"b"]),
        StringItem("line\nbreak"), StringItem("line\\nbreak"), CharItem("'"), CharItem("\n"), CharItem("n"),
        BindingItem(key: 3, bound: IntItem(7)), CodeItem([IntItem(3), IntItem(7)]),
        BindingItem(key: 3, bound: StringItem("7")),
        FunctionItem(bare: InstructionItem(.intAdd)),
        FunctionItem(body: [InstructionItem(.intAdd)],
                     holes: [.init(stack: .int, positions: [0]), .init(stack: .int, positions: [0])], output: .int),
        CodeItem([InstructionItem(.intAdd)]),
        counting(0, 5), counting(0, 5, cursor: 2), counting(0, 5, body: CodeItem([])),
        walk(.elements(into: nil), StringItem("a b")), walk(.letters, StringItem("a b")),
        walk(.words, StringItem("a b")), walk(.elements(into: .exec), CodeItem([IntItem(1)])),
        walk(.elements(into: nil), CodeItem([IntItem(1)])), walk(.points(.boxed), CodeItem([IntItem(1)])),
        walk(.points(.whole), CodeItem([IntItem(1)])), walk(.points(.unwrapped), CodeItem([IntItem(1)])),
        ErrorItem("5"), ErrorItem("5", kind: .overflow), ErrorItem("5", kind: .overflow, source: .intAdd),
        ErrorItem("5", kind: .overflow, source: .intSubtract), ErrorItem("5", kind: .divideByZero, source: .intQuot),
        ErrorItem(missingArgumentsFor: .intAdd, on: .int),
        StandInItem(standingInFor: IntItem(4), source: .intStackDepth, reason: .observed),
        StandInItem(standingInFor: IntItem(4), source: .intStackDepth, reason: .elided),
        StandInItem(standingInFor: IntItem(4), source: .intStackDepth, reason: .minted),
        StandInItem(standingInFor: IntItem(4), source: nil, reason: .observed)
    ]

    /// The rule: two items that are not equal never print alike.
    @Test func `unequal items never print alike`() {
        let items = Self.confusable
        for (i, a) in items.enumerated() {
            for b in items[(i + 1)...] where !a.isEqual(to: b) {
                #expect(a.pretty() != b.pretty(),
                        "\(type(of: a)) and \(type(of: b)) both print as \(a.pretty())")
            }
        }
    }

    @Test func `the short forms`() {
        #expect(IntItem(88).pretty() == "88")
        #expect(DoubleItem(2.5).pretty() == "2.5")
        #expect(BoolItem(true).pretty() == "true")
        #expect(CharItem("x").pretty() == "'x'")
        #expect(StringItem("foo").pretty() == "\"foo\"")
        #expect(VecIntItem([1, 2, 3]).pretty() == "[1, 2, 3]")
        #expect(CodeItem([IntItem(1), InstructionItem(.intAdd)]).pretty() == "( 1 .intAdd )")
        #expect(InstructionItem(.intAdd).pretty() == ".intAdd")
    }

    @Test func `an empty vector names its type`() {
        #expect(VecIntItem([]).pretty() == "«vecInt []»")
        #expect(VecDoubleItem([]).pretty() == "«vecDbl []»")
        #expect(VecBoolItem([]).pretty() == "«vecBool []»")
        #expect(VecStringItem([]).pretty() == "«vecStr []»")
    }

    @Test func `strings and chars escape quotes and non-printing characters`() {
        #expect(StringItem("say \"hi\"").pretty() == #""say \"hi\"""#)
        #expect(StringItem("a\\b").pretty() == #""a\\b""#)
        #expect(StringItem("a\nb\tc\rd").pretty() == #""a\nb\tc\rd""#)
        #expect(StringItem("it's").pretty() == #""it's""#, "a single quote needs no escape in a string")
        #expect(CharItem("'").pretty() == #"'\''"#)
        #expect(CharItem("\"").pretty() == #"'"'"#, "a double quote needs no escape in a char")
        #expect(CharItem("\\").pretty() == #"'\\'"#)
        #expect(CharItem("\n").pretty() == #"'\n'"#)
        #expect(CharItem("\t").pretty() == #"'\t'"#)
        #expect(VecStringItem(["a\"b", "c\nd"]).pretty() == #"["a\"b", "c\nd"]"#)
    }

    /// Nothing invisible is left raw, so printed text reads back exactly.
    @Test func `characters that might not show are escaped`() {
        #expect(StringItem("a\u{A0}b").pretty() == #""a\u{00A0}b""#, "no-break space")
        #expect(StringItem("a\u{2028}b").pretty() == #""a\u{2028}b""#, "line separator")
        #expect(StringItem("a\u{200B}b").pretty() == #""a\u{200B}b""#, "zero-width space")
        #expect(StringItem("\u{FEFF}a").pretty() == #""\u{FEFF}a""#, "byte-order mark")
        #expect(CharItem("\u{3000}").pretty() == #"'\u{3000}'"#, "ideographic space")
        #expect(VecStringItem(["\u{85}"]).pretty() == #"["\u{0085}"]"#, "next line")
        #expect(StringItem("a b").pretty() == #""a b""#, "the plain space stays")
        #expect(StringItem("é ñ 日本 😉").pretty() == #""é ñ 日本 😉""#, "visible characters stay")
    }

    @Test func `a signature uses the short tags`() {
        #expect(FunctionItem(bare: InstructionItem(.stringLength)).pretty()
                == "«fn bare (str) -> int: $0 .stringLength»")
        #expect(FunctionItem(bare: InstructionItem(.doubleAdd)).pretty()
                == "«fn bare (dbl, dbl) -> dbl: $0 $1 .doubleAdd»")
    }

    @Test func `the labeled forms`() {
        #expect(BindingItem(key: 3, bound: StringItem("x")).pretty() == "«bind: 3 -> \"x\"»")
        #expect(FunctionItem(bare: InstructionItem(.intAdd)).pretty()
                == "«fn bare (int, int) -> int: $0 $1 .intAdd»")
        #expect(FunctionItem(body: [IntItem(2), InstructionItem(.intAdd)],
                             holes: [.init(stack: .int, positions: [0])], output: .int).pretty()
                == "«fn (int) -> int: $0 2 .intAdd»")
        #expect(FunctionItem(body: [InstructionItem(.intDup), InstructionItem(.intMultiply)],
                             holes: [.init(stack: .int, positions: [0])], output: .int).pretty()
                == "«fn (int) -> int: $0 .intDup .intMultiply»")
        #expect(StandInItem(standingInFor: IntItem(4), source: .intStackDepth, reason: .observed).pretty()
                == "«observed .intStackDepth: 4»")
        #expect(StandInItem(standingInFor: IntItem(0), source: .execDoTimes, reason: .minted).pretty()
                == "«minted .execDoTimes: 0»")
        #expect(StandInItem(standingInFor: IntItem(4537), source: .intAdd, reason: .elided).pretty()
                == "«elided .intAdd: 4537»")
    }

    @Test func `an iterator names its kind`() {
        #expect(Self.counting(0, 5, cursor: 2, body: CodeItem([BoolItem(true)])).pretty()
                == "«iter 0 to 5 by 1 at 2: ( true )»")
        #expect(Self.walk(.elements(into: nil), VecIntItem([1, 2, 3])).pretty() == "«iter over [1, 2, 3] at 0»")
        #expect(Self.walk(.elements(into: nil), StringItem("a b")).pretty() == "«iter over \"a b\" at 0»")
        #expect(Self.walk(.letters, StringItem("a b")).pretty() == "«iter letters of \"a b\" at 0»")
        #expect(Self.walk(.words, StringItem("a b")).pretty() == "«iter words of \"a b\" at 0»")
        #expect(Self.walk(.points(.boxed), CodeItem([IntItem(1)])).pretty() == "«iter boxed points of ( 1 ) at 0»")
        #expect(Self.walk(.elements(into: .exec), CodeItem([IntItem(1)])).pretty()
                == "«iter over ( 1 ) into exec at 0»")
    }

    /// An error prints its kind and the instruction that raised it, and nothing
    /// else: the sentence in `value` is for people, and stays out of the form.
    @Test func `an error prints its kind and its instruction`() {
        #expect(ErrorItem("Overflow in .intAdd: 1 + 2", kind: .overflow, source: .intAdd).pretty()
                == "«err overflow: .intAdd»")
        #expect(ErrorItem(missingArgumentsFor: .intAdd, on: .int).pretty() == "«err missingArgument: .intAdd»")
        #expect(ErrorItem(".int is full", kind: .sizeRefusal).pretty() == "«err sizeRefusal»",
                "an error the interpreter raised itself names no instruction")
        #expect(ErrorItem("anything at all").pretty() == "«err other»")
    }

    /// Equality follows the printed form, so the rule above holds for errors:
    /// two overflows in `.intAdd` are one error, whatever the numbers were.
    @Test func `errors are equal when kind and instruction match`() {
        let one = ErrorItem("Overflow in .intAdd: 1 + 2", kind: .overflow, source: .intAdd)
        let other = ErrorItem("Overflow in .intAdd: 3 + 4", kind: .overflow, source: .intAdd)
        #expect(one == other)
        #expect(one.value != other.value, "the sentences are kept")
        #expect(one != ErrorItem("Overflow in .intAdd: 1 + 2", kind: .overflow, source: .intSubtract))
        #expect(one != ErrorItem("Overflow in .intAdd: 1 + 2", kind: .undefined, source: .intAdd))
        #expect(ErrorItem(missingArgumentsFor: .intAdd, on: .int)
                == ErrorItem("x", kind: .missingArgument, source: .intAdd))
    }

    /// No refusal an instruction raises is left without an instruction or a kind.
    @Test func `a refusal from an instruction names it`() {
        for program: [any Item] in [
            [IntItem(1), IntItem(0), InstructionItem(.intQuot)],
            [IntItem(.max), IntItem(1), InstructionItem(.intAdd)],
            [DoubleItem(-1), InstructionItem(.doubleSqrt)],
            [DoubleItem(1), DoubleItem(0), InstructionItem(.doubleDivide)],
            [VecIntItem([]), InstructionItem(.vecIntFirst)],
            [InstructionItem(.intAdd)]
        ] {
            let inty = Interpreter()
            inty.load(program: program)
            inty.run()
            let error = inty.stacks[.error]!.first as? ErrorItem
            let instruction = (program.last as? InstructionItem)?.value
            #expect(error?.source == instruction, "\(program.map { $0.pretty() })")
            #expect(error?.kind != .other, "\(program.map { $0.pretty() })")
        }
    }

    /// Every item can be written with its type spelled out; the forms that are
    /// already labeled stay as they are.
    @Test func `every item has an explicit form`() {
        #expect(IntItem(88).explicitPretty() == "«int 88»")
        #expect(DoubleItem(2.5).explicitPretty() == "«dbl 2.5»")
        #expect(BoolItem(true).explicitPretty() == "«bool true»")
        #expect(CharItem("\n").explicitPretty() == #"«char '\n'»"#)
        #expect(StringItem("foo").explicitPretty() == "«str \"foo\"»")
        #expect(VecIntItem([1, 2, 3]).explicitPretty() == "«vecInt [1, 2, 3]»")
        #expect(VecIntItem([]).explicitPretty() == "«vecInt []»")
        #expect(VecStringItem(["a"]).explicitPretty() == "«vecStr [\"a\"]»")
        #expect(CodeItem([IntItem(1), InstructionItem(.intAdd)]).explicitPretty() == "«code ( 1 .intAdd )»")
        #expect(InstructionItem(.intAdd).explicitPretty() == "«inst .intAdd»")
        #expect(BindingItem(key: 3, bound: IntItem(7)).explicitPretty() == "«bind: 3 -> 7»")
        #expect(ErrorItem("x", kind: .overflow, source: .intAdd).explicitPretty() == "«err overflow: .intAdd»")
        for item in Self.confusable {
            let explicit = item.explicitPretty()
            #expect(explicit.hasPrefix("«") && explicit.hasSuffix("»"), "\(explicit)")
        }
    }
}
