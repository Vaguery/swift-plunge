//
//  Router.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 5/30/26.
//

import Foundation

nonisolated struct Router: Sendable {
    let stack: PushStack
    let item: any Item
    init(_ stack: PushStack, _ item: any Item) {
        self.stack = stack
        self.item = item
    }
}
