//
//  Interpreter.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import Foundation


struct InterpreterSettings {
    // https://github.com/lspector/propeller/blob/master/src/propeller/push/limits.cljc
    var stepLimit       : Int = 1000
    var stackCapacity   : Int = 1000
    var maxIntegerSize  : Int = 1_000_000
    var maxFloatSize    : Double = 1_000_000.0
    var maxStringLength : Int = 1000
    var maxVectorLength : Int = 1000
    var maxCodePoints   : Int = 1000
    var maxCodeDepth    : Int = 1000
}
