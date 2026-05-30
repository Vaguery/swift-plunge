//
//  Router.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import Foundation

struct Router {
    let stack: PushStack
    let item: any Pushable
    init(_ stack: PushStack, _ item: any Pushable) {
        self.stack = stack
        self.item = item
    }
}
