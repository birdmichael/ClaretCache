//
//  Sentinel.swift
//  ClaretCacheDemo
//
//  Created by BirdMichael on 2019/7/30.
//  Copyright © 2019 com.ClaretCache. All rights reserved.
//

#if canImport(UIKit)
import UIKit.UIApplication
#endif

/// Sentinel is a thread safe incrementing counter.
///
///  It may be used in some **multi-threaded** situation.
class Sentinel {

    /// Returns the current value of the counter.
    private(set) var value: Int32 = 0

    /// Increase the value atomically.
    /// @return The new value.
    @discardableResult
    public func increase() -> Int32 {
        return OSAtomicIncrement32(&value)
    }
}
