//
//  DoubleFormatter.swift
//  RoboticArm
//
//  Created by Kevin Coble on 5/25/20.
//  Copyright © 2020 Kevin Coble. All rights reserved.
//

import Foundation

public class DoubleFormatter: Formatter {

    override public func string(for obj: Any?) -> String? {
        var retVal: String?
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        if let float = obj as? Double {
            if (abs(float) >= 1.0E9 || abs(float) <= 1.0E-6)
                    { formatter.numberStyle = .scientific }
            retVal = formatter.string(from: NSNumber(value: float))
        } else {
            retVal = nil
        }

        return retVal
    }

    override public func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {

        var retVal = true

        if let dbl = Double(string), let objok = obj {
            objok.pointee = dbl as AnyObject?
            retVal = true
        } else {
            retVal = false
        }

        return retVal

    }
}
