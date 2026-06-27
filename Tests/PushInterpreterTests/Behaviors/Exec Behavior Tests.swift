//
//  Exec Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/15/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct ExecBehaviorTests {

    var inty = Interpreter()
    
    @Test func `execWhile doesn't act if a false is found`() {
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(false), BoolItem(true, isContingent: true), BoolItem(false)])
        inty.stacks[.exec]!.prepend(
            contentsOf: [IntItem(44), IntItem(33), IntItem(22)])
        
        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ false true false ]")

        doThis(.execWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
    }
    
    @Test func `execWhile pushes several items back to .exec when true is found`() {
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(true), BoolItem(true, isContingent: true), BoolItem(false)])
        inty.stacks[.exec]!.prepend(
            contentsOf: [IntItem(44), IntItem(33), IntItem(22)])
        
        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true true false ]")
        
        doThis(.execWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ 44 .execWhile 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .exec).index == 0)
        #expect(topItem(inty, .exec).isContingent == true)
        #expect(inty.stacks[.exec]![1].index == 1)
        #expect(inty.stacks[.exec]![2].index == 2)
    }

    
    @Test func `execDoWhile is a lot like execWhile when a true is found`() {
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(true), BoolItem(true, isContingent: true), BoolItem(false)])
        inty.stacks[.exec]!.prepend(
            contentsOf: [IntItem(44), IntItem(33), IntItem(22)])
        
        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true true false ]")

        doThis(.execDoWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ 44 .execWhile 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .exec).index == 0)
        #expect(topItem(inty, .exec).isContingent == true)
        #expect(inty.stacks[.exec]![1].index == 1)
        #expect(inty.stacks[.exec]![2].index == 2)

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execWhile 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .exec).index == 1)

        inty.step()
        #expect(stackString(inty, .exec) == "[ 44 .execWhile 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .exec).isContingent == true)

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execWhile 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(stackString(inty, .bool) == "[ ]")
    }

    @Test func `execDoWhile acts once even if a false is found`() {
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(false), BoolItem(true, isContingent: true), BoolItem(false)])
        inty.stacks[.exec]!.prepend(
            contentsOf: [IntItem(44), IntItem(33), IntItem(22)])
        
        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ false true false ]")
        
        doThis(.execDoWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .exec).index == 2)
        #expect(topItem(inty, .exec).isContingent == true)
    }
    
    
    @Test func execWhen() {
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(true, isContingent: true), BoolItem(false)])
        inty.stacks[.exec]!.prepend(
            contentsOf: [IntItem(44), IntItem(33), IntItem(22)])
        
        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        
        doThis(.execWhen, to: inty)
        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(topItem(inty, .exec).isContingent == true)
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.execWhen, to: inty)
        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(stackString(inty, .bool) == "[ ]")
    }

    @Test func execIf() {
        inty.stacks[.bool]!.prepend(BoolItem(true, isContingent: false))
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(DoubleItem(3.4))
        
        #expect(stackString(inty, .exec) == "[ 3.4 44 ]")
        
        doThis(.execIf, to: inty)
        #expect(stackString(inty, .exec) == "[ 3.4 ]")
        #expect(topItem(inty, .exec).isContingent == true)

        doThis(.execFlush, to: inty)
        
        inty.stacks[.bool]!.prepend(BoolItem(false, isContingent: false))
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(DoubleItem(3.4))

        doThis(.execIf, to: inty)
        #expect(stackString(inty, .exec) == "[ 44 ]")
        #expect(topItem(inty, .exec).isContingent == true)
    }
    
    @Test func execS() {
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(BoolItem(true, isContingent: true))
        inty.stacks[.exec]!.prepend(DoubleItem(3.4))
        
        #expect(stackString(inty, .exec) == "[ 3.4 true 44 ]")
        
        doThis(.execS, to: inty)
        #expect(stackString(inty, .exec) == "[ 3.4 44 ( true 44 ) ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(inty.stacks[.exec]![2].isContingent == true)
    }
    
    @Test func execK() {
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(BoolItem(true, isContingent: true))
        inty.stacks[.exec]!.prepend(DoubleItem(3.4))
        
        #expect(stackString(inty, .exec) == "[ 3.4 true 44 ]")
        
        doThis(.execK, to: inty)
        #expect(stackString(inty, .exec) == "[ 3.4 44 ]")
    }
    
    @Test func execY() {
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(BoolItem(true, isContingent: true))
        inty.stacks[.exec]!.prepend(IntItem(1))
        
        #expect(stackString(inty, .exec) == "[ 1 true 44 ]")
        
        doThis(.execY, to: inty)
        #expect(stackString(inty, .exec) == "[ 1 ( .execY 1 ) true 44 ]")
        
        inty.step()
        #expect(stackString(inty, .exec) == "[ ( .execY 1 ) true 44 ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
        
        inty.step()
        #expect(stackString(inty, .exec) == "[ .execY 1 true 44 ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
        
        inty.step()
        #expect(stackString(inty, .exec) == "[ 1 ( .execY 1 ) true 44 ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
        
        inty.step()
        #expect(stackString(inty, .exec) == "[ ( .execY 1 ) true 44 ]")
        #expect(stackString(inty, .int) == "[ 1 1 ]")
    }
}
