//
//  Transaction.swift
//  ClaretCacheDemo
//
//  Created by BirdMichael on 2019/7/30.
//  Copyright © 2019 com.ClaretCache. All rights reserved.
//

import Foundation

class Transaction <T> where T: NSObject {

    var target: T?
    var selector: Selector?

    init(transaction target: T,selector: Selector) {
        self.target = target
        self.selector = selector
    }

    func commit() {
        guard target != nil && selector != nil else {
            transactionSetup()
            transactionSet?.insert(self as! Transaction<NSObject>)
            return
        }
    }
}

extension Transaction: Hashable {
    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        return lhs.target == rhs.target && lhs.selector == rhs.selector
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(target)
        hasher.combine(selector)
    }
}

private let onceToken = UUID().uuidString
private var transactionSet: Set<Transaction<NSObject>>?
private func transactionSetup() {
    DispatchQueue.once(token: onceToken) {
        transactionSet = Set()
        /// 获取main RunLoop
        let runloop = CFRunLoopGetCurrent()
        var observer: CFRunLoopObserver?

        //RunLoop循环的回调
        let YYRunLoopObserverCallBack: CFRunLoopObserverCallBack = {_,_,_ in
            guard (transactionSet?.count) ?? 0 > 0 else { return }
            let currentSet = transactionSet
            transactionSet = Set()
            for transaction in currentSet! {
                _ = (transaction.target)?.perform(transaction.selector)
            }
        }

        observer = CFRunLoopObserverCreate(
            kCFAllocatorDefault,
            CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.exit.rawValue,
            true, // repeat
            0xFFFFFF, // after CATransaction(2000000)
            YYRunLoopObserverCallBack,
            nil
        )

        CFRunLoopAddObserver(runloop, observer, .commonModes)
        observer = nil
    }
}
