////
////  PlushyAcceptanceTests.swift
////  PropellerWithStructs
////
////  Created by William Tozier on 6/3/26.
////
//
//
//import Testing
//import DequeModule
//@testable import Propeller_in_Swift
//
//
//struct PlushyAcceptanceTests {
//    
//    @Test func simpleOpenCloseWorks()  {
//        var plushy1:[Any] = [1, 2.3, PushInstruction.intAdd, PlushyControl.open, 4, PlushyControl.open, 5.6, false]
//        #expect(PushItem.makeCode(Plushy.plushy2push(&plushy1)).asString() ==
//                "( 1 2.3 :intAdd ( 4 ( 5.6 false ) ) )")
//        
//        var plushy2:[Any] = [1, 2.3, PushInstruction.intAdd, PlushyControl.open, 4, PlushyControl.close, PlushyControl.open, 5.6, false]
//        #expect(PushItem.makeCode(Plushy.plushy2push(&plushy2)).asString() ==
//                "( 1 2.3 :intAdd ( 4 ) ( 5.6 false ) )")
//    }
//    
//    @Test func tableOfInstructionsWorksAsExpected() {
//        
//        var plushy3:[Any] = [PushInstruction.execRot, 1, PlushyControl.close, 2, 3, PlushyControl.close, 4, 5, PlushyControl.close, 6]
//        #expect(PushItem.makeCode(Plushy.plushy2push(&plushy3)).asString() ==
//                "( :execRot ( 1 ) ( 2 3 ) ( 4 5 ) 6 )")
//        
//        var plushy4:[Any] = [PushInstruction.execSwap, 1, PushInstruction.execSwap, PlushyControl.close, 2, 3, PlushyControl.close, 4, 5, PlushyControl.close, 6]
//        #expect(PushItem.makeCode(Plushy.plushy2push(&plushy4)).asString() ==
//                "( :execSwap ( 1 :execSwap ( ) ( 2 3 ) 4 5 ) ( 6 ) )")
//
//    }
//    
//    @Test func readingComplexLiteralsWorksWithInstructionTable() {
//        var plushy5:[Any] = [PushInstruction.execSwap, [1,2], Character("🙃"), PushInstruction.execSwap, [3, 5.6, 7], PlushyControl.close, [false,false,true], ["foo","bar","baz"], PlushyControl.close, 8, 9, PlushyControl.close, 10]
//        
//        #expect(PushItem.makeCode(Plushy.plushy2push(&plushy5)).asString() ==
//                "( :execSwap ( [1, 2] '🙃' :execSwap ( [3.0, 5.6, 7.0] ) ( [false, false, true] [\"foo\", \"bar\", \"baz\"] ) 8 9 ) ( 10 ) )")
//        
//        var plushy6:[Any] = [PushInstruction.intMax, [1,2], Character("🙃"), PushInstruction.charDup, [3, 5.6, 7], PlushyControl.close, [false,false,true], ["foo","bar","baz"], PlushyControl.close, 8, 9, PlushyControl.close, 10]
//        #expect(PushItem.makeCode(Plushy.plushy2push(&plushy6)).asString() ==
//                "( :intMax [1, 2] '🙃' :charDup [3.0, 5.6, 7.0] [false, false, true] [\"foo\", \"bar\", \"baz\"] 8 9 10 )")
//
//    }
//}
//
