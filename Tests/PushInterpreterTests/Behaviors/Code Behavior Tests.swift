//
//  Code Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/17/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct CodeBehaviorTests {

    let inty = Interpreter()

    @Test func codeAppend() {
        intyCode4(inty)
        
        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( 8.8 4 ) ( '-' ) ( ) ]")
        #expect(topItem(inty, .code).isContingent == false)
        
        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( '-' 8.8 4 ) ( ) ]")
        #expect(topItem(inty, .code).isContingent == true)
        
        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( '-' 8.8 4 ) ]")
        #expect(topItem(inty, .code).isContingent == true)
    }
}
