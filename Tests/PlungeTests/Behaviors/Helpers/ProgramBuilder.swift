//
//  ProgramBuilder.swift
//  PlungeTests
//
//  Created by Bill Tozier on 7/19/26.
//
//  A test-only program builder that parses a flat token stream into a nested
//  `[any Item]` program. It is the good half of the departed `Plushy.plushy2push`
//  — literals, vectors, explicit open/close bracketing, and nested arrays — with
//  the obsolete `extraOpens` special-casing removed. `extraOpens` auto-opened code
//  blocks after certain exec instructions; that shape is now wrong (exec
//  instructions take their branches off `.code`), so a builder for hand-authored
//  test programs must not carry it. The Plushy *genome* itself now lives in the
//  PlungeGP repo (`Genome Reference/`); this is not a genome, just a parser.
//

import Plunge

/// A marker for explicit code-block nesting in a token stream — the open/close
/// braces used to hand-author nested test programs. Replaces the departed
/// `PlushyControl`; carries none of its genome semantics.
enum Brace { case open, close }

/// Parses a flat token stream into a nested `[any Item]` program. `Brace.open` /
/// `.close` bracket a `CodeItem`; a nested `[Any]` also becomes a `CodeItem`;
/// literals and vectors become their Items; instructions become `InstructionItem`s
/// verbatim (no `extraOpens`).
func buildProgram(_ stuff: [Any]) -> [any Item] {
    var working = stuff
    return parseTokens(&working)
}

private func parseTokens(_ stuff: inout [Any], level: Int = 0) -> [any Item] {
    var result: [any Item] = []
    while stuff.isEmpty == false {
        let thing = stuff.remove(at: 0)
        switch thing {
        case let v as Int:            result.append(IntItem(v))
        case let v as IntItem:        result.append(v)
        case let v as Double:         result.append(DoubleItem(v))
        case let v as DoubleItem:     result.append(v)
        case let v as Bool:           result.append(BoolItem(v))
        case let v as BoolItem:       result.append(v)
        case let v as String:         result.append(StringItem(v))
        case let v as StringItem:     result.append(v)
        case let v as Character:      result.append(CharItem(v))
        case let v as CharItem:       result.append(v)
        // Specific vector types before `[Any]`: a `[Int]` also casts to `[Any]`.
        case let v as [Int]:          result.append(VecIntItem(v))
        case let v as VecIntItem:     result.append(v)
        case let v as [Bool]:         result.append(VecBoolItem(v))
        case let v as VecBoolItem:    result.append(v)
        case let v as [Double]:       result.append(VecDoubleItem(v))
        case let v as VecDoubleItem:  result.append(v)
        case let v as [String]:       result.append(VecStringItem(v))
        case let v as VecStringItem:  result.append(v)
        case let v as PushInstruction: result.append(InstructionItem(v))
        case let v as InstructionItem: result.append(v)
        case let v as Brace:
            if v == .open {
                result.append(CodeItem(parseTokens(&stuff, level: level + 1)))
            } else if level > 0 {
                return result
            }
        case let v as CodeItem:       result.append(v)
        case let v as [Any]:
            var copy = v
            result.append(CodeItem(parseTokens(&copy, level: level + 1)))
        default: break
        }
    }
    return result
}
