//
//  Gripper.swift
//  RoboticArm
//
//  Created by Kevin Coble on 6/14/20.
//  Copyright © 2020 Kevin Coble. All rights reserved.
//

import Foundation

enum GripperState : Equatable {
    case Idle
    case Closing
    case ClosingToPressure(pressure : Double)
    case ClosingToDistance(distance : Double)   //  Distance in meters
    case ClosingToDistanceOrPressure(distance : Double, pressure : Double)   //  Distance in meters
    case Opening
    case OpeningToDistance(distance : Double)   //  Distance in meters
}

class Gripper {
    var state : GripperState = .Idle
    var fingerLocation : Double         //  Distance from center of gripper to edge of each finger
    let fingerMovementRange = 0.016
    var currentPressure = 128.0
    var lastChangeTime = Date()
    let pressureGripRate = 45.0     //  In degrees per second

    init(initalGripperServoSetting : Double)
    {
        fingerLocation = 0.0
        setFingerPosition(gripperServoSetting: initalGripperServoSetting)
    }
    
    func setFingerPosition(gripperServoSetting : Double)
    {
        //  Calculate the finger position
        fingerLocation = fingerMovementRange * (gripperServoSetting + 90.0) / 180.0
    }
    
    func setState(_ newState : GripperState)
    {
        //  Store the new state and the time of the change
        state = newState
        lastChangeTime = Date()
    }
    
    func setPressure(_ newPressure : Double)
    {
        currentPressure = newPressure
    }
    
    func getGripperServoAngle(currentGripperServoAngle : Double) -> Double?
    {
        
        //  Switch based on the state we are trying to achieve
        switch (state) {
        case .Idle:
            //  If idle, we shouldn't update the position
            return nil
        case .Closing:
            //  If closing, up the gripper angle to -90 at full speed
            state = .Idle
            return -90.0
        case .ClosingToPressure(let pressure):
            if (currentPressure < pressure) {
                //  Get the time since the last update.  Limit to 0.1 seconds so we don't overgrip
                var timeDiff = Date().timeIntervalSince(lastChangeTime)
                if (timeDiff > 0.1) { timeDiff = 0.1 }
                lastChangeTime = Date()
                
                //  Move the gripper in for a small rate based on the time period
                let angleDiff = timeDiff * pressureGripRate

                let newAngle = currentGripperServoAngle - angleDiff
                if (newAngle < -90.0) {
                    //  Fully closed
                    state = .Idle
                }
                fingerLocation = fingerMovementRange * (newAngle + 90.0) / 180.0
                return newAngle
            }
            else {
                state = .Idle
                return nil
            }
        case .ClosingToDistance(let distance):   //  Distance in meters
            //  Calculate the angle the servo should be for the distance
            let newServoAngle = distance * 180.0 / fingerMovementRange - 90.0
            state = .Idle
            return newServoAngle
        case .ClosingToDistanceOrPressure(let distance, let pressure):   //  Distance in meters
            if (currentPressure < pressure) {
                let timeDiff = Date().timeIntervalSince(lastChangeTime)
                lastChangeTime = Date()
                let angleDiff = timeDiff * pressureGripRate
                let currentAngle = fingerLocation * 180.0 / fingerMovementRange - 90.0
                var newAngle = currentAngle + angleDiff
                fingerLocation = fingerMovementRange * (newAngle + 90.0) / 180.0
                if (fingerLocation < distance) {
                    //  At close distance limit
                    fingerLocation = distance
                    newAngle = distance * 180.0 / fingerMovementRange - 90.0
                }
                if (newAngle < -90.0) {
                    //  Fully closed
                    state = .Idle
                }
                return newAngle
            }
            else {
                state = .Idle
                return nil
            }
        case .Opening:
            //  If opening, up the gripper angle to 90 at full speed
            state = .Idle
            return 90.0
        case .OpeningToDistance(let distance):   //  Distance in meters
            //  Calculate the angle the servo should be for the distance
            let newServoAngle = distance * 180.0 / fingerMovementRange - 90.0
            state = .Idle
            return newServoAngle
        }
    }
}
