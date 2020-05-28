//
//  Servo.swift
//  RoboticArm
//
//  Created by Kevin Coble on 5/23/20.
//  Copyright © 2020 Kevin Coble. All rights reserved.
//

import Foundation
import GLKit

public class Servo
{
    let name : String       //  Used for DOFController
    let type : String       //  Not used, but could be reference for look-up tables, etc. later
    let minAngle : Double   //  Minimum angle servo can move, based on physical limitations (radians)
    let maxAngle : Double   //  Maximum angle server can move, based on physical limitations (radians)
    let speed : Double      //  Standard time for 60 degree rotation (seconds)
    var angleAt1500μs : Double  //  Angle servo makes with an input of 1500 μs pulses    (radians) (should be zero if aligned perfectly)
    var angleAt500μs : Double   //  Angle servo makes with an input of 500 μs pulses    (radians)
    var angleAt2500μs : Double  //  Angle servo makes with an input of 2500 μs pulses   (radians)

    public init(jointName : String, jointType: String, minimumAngle : Double, maximumAngle : Double, rotationSpeed : Double) {
        name = jointName
        type = jointType
        minAngle = minimumAngle
        maxAngle = maximumAngle
        speed = rotationSpeed
        
        //  Initialize calibration angles to 90 degrees
        angleAt1500μs = 0.0
        angleAt500μs = -Double.pi * 0.5
        angleAt2500μs = Double.pi * 0.5
    }
    
    public init(jointName : String, jointType: String, minimumAngleDegrees : Double, maximumAngleDegrees : Double, rotationSpeed : Double) {
        name = jointName
        type = jointType
        minAngle = Double(GLKMathDegreesToRadians(Float(minimumAngleDegrees)))
        maxAngle = Double(GLKMathDegreesToRadians(Float(maximumAngleDegrees)))
        speed = rotationSpeed
        
        //  Initialize calibration angles to 90 degrees
        angleAt1500μs = 0.0
        angleAt500μs = -Double.pi * 0.5
        angleAt2500μs = Double.pi * 0.5
    }
    
    public var minAngleDegrees : Double {
        get {
            return minAngle * 180.0 / Double.pi
        }
    }
    
    public var maxAngleDegrees : Double {
        get {
            return maxAngle * 180.0 / Double.pi
        }
    }
    
    public var rotateRate : Double {
        get {
            return  60.0 / speed         //  sec/60deg to deg/second
        }
    }

    public func setCalibrationAngles(centerPulseAngle: Double, shortPulseAngle : Double, longPulseAngle : Double) {
        angleAt1500μs = centerPulseAngle
        angleAt500μs = shortPulseAngle
        angleAt2500μs = longPulseAngle
    }
    
    public func setCalibrationAngles(centerPulseAngleDegrees: Double, shortPulseAngleDegrees : Double, longPulseAngleDegrees : Double) {
        angleAt1500μs = Double(GLKMathDegreesToRadians(Float(centerPulseAngleDegrees)))
        angleAt500μs = Double(GLKMathDegreesToRadians(Float(shortPulseAngleDegrees)))
        angleAt2500μs = Double(GLKMathDegreesToRadians(Float(longPulseAngleDegrees)))
    }
    
    public func getPulseWidthForAngle(_ angle : Double) -> Int {
        if (angle == angleAt1500μs) { return 1500 }
        if (angle < angleAt1500μs) {
            let pulse = 1500.0 - 1000.0 * (angle - angleAt1500μs) / (angleAt500μs - angleAt1500μs)
            return Int(pulse)
        }
        else {
            let pulse = 1500.0 + 1000.0 * (angle - angleAt1500μs) / (angleAt2500μs - angleAt1500μs)
            return Int(pulse)
        }
    }
    
    public func getPulseWidthForAngleDegrees(_ angle : Double) -> Int {
        let radians = Double(GLKMathDegreesToRadians(Float(angle)))
        return getPulseWidthForAngle(radians)
    }
}
