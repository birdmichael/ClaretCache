//
//  DispatchQueue+Extention.swift
//  ClaretCacheDemo
//
//  Created by BirdMichael on 2019/7/30.
//  Copyright © 2019 com.ClaretCache. All rights reserved.
//

import Foundation

extension DispatchQueue {

    private static var _onceTracker = [String]()

    public class func once(token: String, block: () -> Void) {
        objc_sync_enter(self); defer { objc_sync_exit(self) }

        if _onceTracker.contains(token) {
            return
        }
        _onceTracker.append(token)
        block()
    }
}
