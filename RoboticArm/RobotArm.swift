//
//  RobotArm.swift
//  RoboticArm
//
//  Created by Kevin Coble on 5/7/20.
//  Copyright © 2020 Kevin Coble. All rights reserved.
//

import Foundation
import SceneKit

class RobotArm
{
    //  Servo list
    let servoList : [Servo]
    
    //  Dimensions for arm
    let baseBottomRadius = 0.05
    let baseTopRadius = 0.0475
    let baseHeight = 0.0425
    let baseToSwivelPlateGap = 0.0023
    let swivelPlateThickness = 0.004
    let swivelPlateToShoulderPivot = 0.025
    let distanceBetweenShoulderAndElbow = 0.146
    let distanceBetweenElbowAndWrist = 0.185
    let wristElevationAboveForeArm = 0.0045
    let wristRotateOffsetFromCenter = 0.0062
    let wristToWristRotate = 0.0574
    let wristToGripper = 0.0574 - (0.0626 - 0.0410)
    let padThickness = 0.0027
    let gripperPlateThickness : CGFloat = 0.00225       //  Should match value from makeGripper for finger movement positioning
    let fingerMovementRange = 0.016


    var swivelAngle = 0.0
    var shoulderAngle = 0.0
    var elbowAngle = 0.0
    var wristAngle = 0.0
    var wristRotateAngle = 0.0
    var gripperAngle = 0.0

    var plateNode : SCNNode?
    var upperArmNode : SCNNode?
    var foreArmNode : SCNNode?
    var wristNode : SCNNode?
    var gripperNode : SCNNode?
    var rightFingerNode : SCNNode?
    var leftFingerNode : SCNNode?
    
    //  Kinematics
    var dhParameters : [DenavitHartenberg] = []
    var endEffectorHTM = matrix_identity_double4x4
    
    init() {
        //  Create the servo list
        var list : [Servo] = []
        let servo0 = Servo(jointName: "Base", jointType: "HS-485HB", minimumAngleDegrees: -90.0, maximumAngleDegrees: 90.0, rotationSpeed: 0.18)
        servo0.setCalibrationAngles(centerPulseAngleDegrees: 0.0, shortPulseAngleDegrees: -90.0, longPulseAngleDegrees: 90.0)
        list.append(servo0)
        let servo1 = Servo(jointName: "Shoulder", jointType: "HS-805BB", minimumAngleDegrees: -90.0, maximumAngleDegrees: 90.0, rotationSpeed: 0.14)
        servo1.setCalibrationAngles(centerPulseAngleDegrees: 6.0, shortPulseAngleDegrees: -90, longPulseAngleDegrees: 90.0)
        list.append(servo1)
        let servo2 = Servo(jointName: "Elbow", jointType: "HS-755HB", minimumAngleDegrees: -90.0, maximumAngleDegrees: 70.0, rotationSpeed: 0.23)
        servo2.setCalibrationAngles(centerPulseAngleDegrees: 0.0, shortPulseAngleDegrees: -90.0, longPulseAngleDegrees: 90)
        list.append(servo2)
        let servo3 = Servo(jointName: "Wrist", jointType: "HS-645MG", minimumAngleDegrees: -90.0, maximumAngleDegrees: 90.0, rotationSpeed: 0.20)
        servo3.setCalibrationAngles(centerPulseAngleDegrees: 2.0, shortPulseAngleDegrees: -90, longPulseAngleDegrees: 90.0)
        list.append(servo3)
        let servo4 = Servo(jointName: "Gripper", jointType: "HS-422", minimumAngleDegrees: -90.0, maximumAngleDegrees: 90.0, rotationSpeed: 0.16)
        list.append(servo4)
        let servo5 = Servo(jointName: "Wrist Rotate", jointType: "HS-225MG", minimumAngleDegrees: -90.0, maximumAngleDegrees: 90.0, rotationSpeed: 0.11)
        servo5.setCalibrationAngles(centerPulseAngleDegrees: 0.0, shortPulseAngleDegrees: -90.0, longPulseAngleDegrees: 90.0)
        list.append(servo5)

        servoList = list
    }

    func make3DModel(wristRotate : Bool, gripperServoUp : Bool) -> SCNNode
    {
        //  Add the base at 0,0,0
        let baseGeometry = SCNCone(topRadius: CGFloat(baseTopRadius), bottomRadius: CGFloat(baseBottomRadius), height: CGFloat(baseHeight))
        let baseNode = SCNNode(geometry: baseGeometry)
        baseNode.position = SCNVector3(x: 0.0, y: 0.0, z: CGFloat(baseHeight * 0.5))
        baseGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        baseNode.rotation = SCNVector4Make(1.0, 0.0, 0.0, CGFloat.pi * 0.5)
        
        //  Add the mounting tabs
        let mountGeometry = makeMountTabGeometry()
        for i in 0..<4 {
            let mountNode = SCNNode(geometry: mountGeometry)
            mountNode.scale = SCNVector3(x: 0.1, y: 0.1, z: 1.0)        //  For some reason the SCNShape doesn't work correctly with small numbers, so we are making it 10 times the size and scaling
            mountNode.rotation = SCNVector4Make(1.0, 0.0, 0.0, CGFloat.pi * 0.5)
            let attachNode = SCNNode()
            attachNode.addChildNode(mountNode)
            var angle = CGFloat.pi * (0.25 + CGFloat(i) * 0.5)
            attachNode.rotation = SCNVector4Make(0.0, 1.0, 0.0, angle)
            if ((i % 2) != 0) { angle += CGFloat.pi}
            attachNode.position = SCNVector3(x: cos(angle) * CGFloat(baseBottomRadius - 0.001), y: CGFloat(baseHeight -  0.0027) * -0.5, z: sin(angle) * CGFloat(baseBottomRadius - 0.001))
            baseNode.addChildNode(attachNode)
            
            //  Add a screw
            let screwGeometery = SCNSphere(radius: 0.0025)
            screwGeometery.firstMaterial?.diffuse.contents = NSColor(white: 0.9, alpha: 1.0)
            let screwNode = SCNNode(geometry: screwGeometery)
            screwNode.scale = SCNVector3(x: 1.0, y: 0.5, z: 1.0)
            screwNode.position = SCNVector3(x: 0.0, y: 0.002, z: 0.009)
            attachNode.addChildNode(screwNode)
        }

        //  Add the swivel plate
        let plateGeometry = SCNCylinder(radius: CGFloat(baseTopRadius), height: CGFloat(swivelPlateThickness))
        plateNode = SCNNode(geometry: plateGeometry)
        plateGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        plateNode!.position = SCNVector3(x: 0.0, y: CGFloat(baseHeight * 0.5 + baseToSwivelPlateGap + swivelPlateThickness * 0.5), z: 0.0)
        baseNode.addChildNode(plateNode!)
        
        //  Add a block for a HS-805BB servo simulation
        let servoGeometry = SCNBox(width: 0.057, height: 0.03, length: 0.066, chamferRadius: 0.002)
        let servoNode = SCNNode(geometry: servoGeometry)
        servoGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
        servoNode.position = SCNVector3(x: -0.0028, y: 0.0225, z: 0.02)
        plateNode!.addChildNode(servoNode)
        
        //  Add a nylon wheel to the servo
        var wheelGeometry = SCNCylinder(radius: 0.005, height: 0.01)
        var wheelNode = SCNNode(geometry: wheelGeometry)
        wheelGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
        wheelNode.rotation = SCNVector4Make(0.0, 0.0, 1.0, CGFloat.pi * 0.5)
        wheelNode.position = SCNVector3(x: -0.027, y: 0.0, z: -0.02)
        servoNode.addChildNode(wheelNode)

        wheelGeometry = SCNCylinder(radius: 0.02, height: 0.005)
        wheelNode = SCNNode(geometry: wheelGeometry)
        wheelGeometry.firstMaterial?.diffuse.contents = NSColor(white: 1.0, alpha: 1.0)
        wheelNode.rotation = SCNVector4Make(0.0, 0.0, 1.0, CGFloat.pi * 0.5)
        wheelNode.position = SCNVector3(x: -0.033, y: 0.0, z: -0.02)
        servoNode.addChildNode(wheelNode)
        
        //  Add shoulder bracket plate
        let bracketGeometry = SCNBox(width: 0.0016, height: 0.0362, length: 0.0651, chamferRadius: 0.0)
        let bracketNode = SCNNode(geometry: bracketGeometry)
        bracketGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        bracketNode.position = SCNVector3(x: 0.034, y: CGFloat(0.0362 + swivelPlateThickness) * 0.5, z: 0.02)
        plateNode!.addChildNode(bracketNode)

        //  Add the upper arm
        upperArmNode = makeUpperArm()
        upperArmNode!.position = SCNVector3(x: 0.0, y: CGFloat(swivelPlateToShoulderPivot), z: 0.0)
        plateNode!.addChildNode(upperArmNode!)

        //  Add the forearm
        foreArmNode = makeForeArm()
        foreArmNode!.position = SCNVector3(x: 0.0, y: CGFloat(distanceBetweenShoulderAndElbow), z: 0.0)
        upperArmNode!.addChildNode(foreArmNode!)
        
        //  Add the wrist
        wristNode = makeWrist(wristRotate: wristRotate)
        wristNode!.rotation = SCNVector4Make(1.0, 0.0, 0.0, CGFloat.pi)
        wristNode!.position = SCNVector3(x: 0.0, y: CGFloat(wristElevationAboveForeArm), z: CGFloat(-distanceBetweenElbowAndWrist))
        foreArmNode!.addChildNode(wristNode!)
        
        //  Add the gripper
        gripperNode = makeGripper(wristRotate: wristRotate, gripperServoUp: gripperServoUp)
        if (wristRotate) {
            gripperNode!.position = SCNVector3(x: CGFloat(wristRotateOffsetFromCenter), y: 0.0, z: CGFloat(wristToWristRotate))
        }
        else {
            gripperNode!.position = SCNVector3(x: 0.0, y: 0.0, z: CGFloat(wristToGripper))
        }
        wristNode!.addChildNode(gripperNode!)

        return baseNode
    }
    
    
    func makeMountTabGeometry() -> SCNGeometry
    {
        let attachWidth : CGFloat = 0.132
        let outsideWidth : CGFloat = 0.075
        let length : CGFloat = 0.13    //  Extended a bit to account for curve of base
        let extrusion : CGFloat = 0.0027

        // A bezier path
        let bezierPath = NSBezierPath()
        bezierPath.move(to: NSPoint(x: 0, y: 0))   //  Attach center
        bezierPath.line(to: NSPoint(x: -attachWidth * 0.5, y: 0.0)) //  attach left (looking from base)
        bezierPath.line(to: NSPoint(x: -outsideWidth * 0.5, y: length)) //  outside left
        bezierPath.line(to: NSPoint(x: outsideWidth * 0.5, y: length)) //  outside right
        bezierPath.line(to: NSPoint(x: attachWidth * 0.5, y: 0.0)) //  attach right
        bezierPath.line(to: NSPoint(x: 0, y: 0))   //  Attach center

        bezierPath.close()

        // Add shape
        let shape = SCNShape(path: bezierPath, extrusionDepth: extrusion)
        shape.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        
        return shape
    }
    
    func makeUpperArm() -> SCNNode
    {
        //  Define the size constants
        let thickness = 0.0016
        let bottomToPivot = 0.0157   //  Distance from bottom of shoulder part to pivot height (center of hole)
        let bottomWidth = 0.0776       //  Distance between shoulder part tines
        let bottomHeightToDiagonal = 0.07465
        let bottomDiagonalSize = 0.015
        let topDiagonalSize = 0.01
        let topHeightFromDiagonal = 0.076
        let extrusion : CGFloat = 0.0246
        
        
        // A bezier path
        let bezierPath = NSBezierPath()
        let startX = bottomWidth * -0.5
        let startY = -bottomToPivot
        bezierPath.move(to: NSPoint(x: startX, y: startY))   //  Bottom left point
        let bottomYbeforeDiagonal = startY + bottomHeightToDiagonal
        bezierPath.line(to: NSPoint(x: startX, y: bottomYbeforeDiagonal)) //  Left side before larger diagonal
        let xAfterLargerDiagonal = startX + bottomDiagonalSize
        let yAfterLargerDiagonal = bottomYbeforeDiagonal + bottomDiagonalSize
        bezierPath.line(to: NSPoint(x: xAfterLargerDiagonal, y: yAfterLargerDiagonal)) //  Left side after larger diagonal
        let xAfterTopDiagonal = xAfterLargerDiagonal - topDiagonalSize
        let yAfterTopDiagonal = yAfterLargerDiagonal + topDiagonalSize
        bezierPath.line(to: NSPoint(x: xAfterTopDiagonal, y: yAfterTopDiagonal)) //  Left side after smaller diagonal
        let yTop = yAfterTopDiagonal + topHeightFromDiagonal
        bezierPath.line(to: NSPoint(x: xAfterTopDiagonal, y: yTop)) //  Top-Left point
        let xInsideTopLeft = xAfterTopDiagonal + thickness
        bezierPath.line(to: NSPoint(x: xInsideTopLeft, y: yTop)) //  Top-Left inside point
        let yInsideBeforeTopDiagonal = yTop - (topHeightFromDiagonal - thickness)
        bezierPath.line(to: NSPoint(x: xInsideTopLeft, y: yInsideBeforeTopDiagonal)) //  Inside left above smaller diagonal
        let xInsideAfterTopDiagonal = xInsideTopLeft + topDiagonalSize
        let yInsideAfterTopDiagonal = yInsideBeforeTopDiagonal - topDiagonalSize
        bezierPath.line(to: NSPoint(x: xInsideAfterTopDiagonal, y: yInsideAfterTopDiagonal)) //  Inside left after smaller diagonal
        bezierPath.line(to: NSPoint(x: -xInsideAfterTopDiagonal, y: yInsideAfterTopDiagonal)) //  Inside right below smaller diagonal
        bezierPath.line(to: NSPoint(x: -xInsideTopLeft, y: yInsideBeforeTopDiagonal)) //  Inside right after smaller diagonal
        bezierPath.line(to: NSPoint(x: -xInsideTopLeft, y: yTop)) //  Inside top-right
        bezierPath.line(to: NSPoint(x: -xAfterTopDiagonal, y: yTop)) //  Outside top-right
        bezierPath.line(to: NSPoint(x: -xAfterTopDiagonal, y: yAfterTopDiagonal)) //  Outside right before smaller diagonal
        bezierPath.line(to: NSPoint(x: -xAfterLargerDiagonal, y: yAfterLargerDiagonal)) //  Outside right after smaller diagonal
        bezierPath.line(to: NSPoint(x: -startX, y: bottomYbeforeDiagonal)) //  Outside right after larger diagonal
        bezierPath.line(to: NSPoint(x: -startX, y: startY))                 //  Outside bottom-right
        let insideXBottomRight = -startX - thickness
        bezierPath.line(to: NSPoint(x: insideXBottomRight, y: startY))                 //  Inside bottom-right
        bezierPath.line(to: NSPoint(x: insideXBottomRight, y: bottomYbeforeDiagonal))        //  Inside right before larger diagonal
        let xInsideRightAfterLargerDiagonal = insideXBottomRight - bottomDiagonalSize
        bezierPath.line(to: NSPoint(x: xInsideRightAfterLargerDiagonal, y: yAfterLargerDiagonal))        //  Inside right after larger diagonal
        let xInsideAfterLargerDiagonal = xAfterLargerDiagonal + thickness
        bezierPath.line(to: NSPoint(x: xInsideAfterLargerDiagonal, y: yAfterLargerDiagonal))        //  Inside left before larger diagonal
        let xInsideBottom = startX + thickness
        bezierPath.line(to: NSPoint(x: xInsideBottom, y: bottomYbeforeDiagonal))        //  Inside left after larger diagonal
        bezierPath.line(to: NSPoint(x: xInsideBottom, y: startY))        //  Inside bottom left

        bezierPath.close()

        // Create shape
        let shape = SCNShape(path: bezierPath, extrusionDepth: extrusion)
        shape.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        let shapeNode = SCNNode(geometry: shape)
        
        //  Add the friction pads
        let padGeometry = SCNCylinder(radius: 0.0121, height: 0.0076)
        var padNode = SCNNode(geometry: padGeometry)
        padGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
        padNode.rotation = SCNVector4Make(0.0, 0.0, 1.0, CGFloat.pi * 0.5)
        padNode.position = SCNVector3(x: CGFloat(bottomWidth - thickness) * 0.5, y: 0.0, z: 0.0)
        shapeNode.addChildNode(padNode)
        padNode = SCNNode(geometry: padGeometry)
        padGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
        padNode.rotation = SCNVector4Make(0.0, 0.0, 1.0, CGFloat.pi * 0.5)
        padNode.position = SCNVector3(x: CGFloat(bottomWidth - thickness) * 0.5 - CGFloat(bottomDiagonalSize - topDiagonalSize), y: CGFloat(distanceBetweenShoulderAndElbow), z: 0.0)
        shapeNode.addChildNode(padNode)

        //  Return the shape
        return shapeNode
    }
    
    
    func makeForeArm() -> SCNNode
    {
        //  Define the size constants
        let thickness : CGFloat = 0.0016
        let elbowBracketLength : CGFloat = 0.06
        let elbowBracketHeight : CGFloat = 0.0341
        let elbowBracketWidth : CGFloat = 0.0434
        let elbowServoLength : CGFloat = 0.0589
        let elbowServoHeight : CGFloat = 0.0289
        let elbowServoWidth : CGFloat = 0.0491
        let servoWheelWidth : CGFloat = 0.002
        let servoWheelRadius : CGFloat = 0.0121
        let angleBracketDescent : CGFloat = 0.0121
        let angleBracketAscent : CGFloat = 0.0153
        let angleBracketLength : CGFloat = 0.036
        let angleBracketThickness : CGFloat = 0.0025
        let angleBracketLWidth : CGFloat = 0.0246
        let elbowToRodCenterOffset : CGFloat = 0.0063
        let rodConnectionRadius : CGFloat = 0.0119
        let rodConnectionWidth : CGFloat = 0.0017
        let foreArmTubeRadius : CGFloat = 0.00635
        let foreArmTubeLength : CGFloat = 0.1146
        let wristBracketLength : CGFloat = 0.0571
        let wristBracketHeight : CGFloat = 0.0248
        let wristBracketWidth : CGFloat = 0.035
        let wristServoLength : CGFloat = 0.0402
        let wristServoHeight : CGFloat = 0.0344
        let wristServoWidth : CGFloat = 0.0195

        //  Create a forearm node - centered at the elbow
        let foreArmNode = SCNNode()
        
        //  Create the elbow bracket
        var bracketGeometry = SCNBox(width: thickness, height: elbowBracketHeight, length: elbowBracketLength, chamferRadius: 0.0)
        var bracketNode = SCNNode(geometry: bracketGeometry)
        bracketGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        bracketNode.position = SCNVector3(x: 0.0285, y: 0.002, z: 0.0157)
        foreArmNode.addChildNode(bracketNode)
        bracketGeometry = SCNBox(width: elbowBracketWidth, height: thickness, length: elbowBracketLength, chamferRadius: 0.0)
        var bracketNode2 = SCNNode(geometry: bracketGeometry)
        bracketGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        bracketNode2.position = SCNVector3(x: elbowBracketWidth * -0.5, y: 0.0165, z: 0.00)
        bracketNode.addChildNode(bracketNode2)
        
        //  Create the elbow servo
        var servoGeometry = SCNBox(width: elbowServoWidth, height: elbowServoHeight, length: elbowServoLength, chamferRadius: 0.0)
        var servoNode = SCNNode(geometry: servoGeometry)
        servoGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
        servoNode.position = SCNVector3(x: 0.0, y: 0.00275, z: 0.0157)
        foreArmNode.addChildNode(servoNode)
        
        //  Create the elbow servo wheel
        var wheelGeometry = SCNCylinder(radius: servoWheelRadius, height: servoWheelWidth)
        var wheelNode = SCNNode(geometry: wheelGeometry)
        wheelGeometry.firstMaterial?.diffuse.contents = NSColor(white: 1.0, alpha: 1.0)
        wheelNode.rotation = SCNVector4Make(0.0, 0.0, 1.0, CGFloat.pi * 0.5)
        wheelNode.position = SCNVector3(x: -0.0325, y: 0.0, z: 0.0)
        foreArmNode.addChildNode(wheelNode)
        wheelGeometry = SCNCylinder(radius: 0.0035, height: 0.008)
        wheelNode = SCNNode(geometry: wheelGeometry)
        wheelGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
        wheelNode.rotation = SCNVector4Make(0.0, 0.0, 1.0, CGFloat.pi * 0.5)
        wheelNode.position = SCNVector3(x: -0.028, y: 0.0, z: 0.0)
        foreArmNode.addChildNode(wheelNode)
        
        //  Create the geometry for the angle bracket that holds the rod
        let bezierPath = NSBezierPath()
        bezierPath.move(to: NSPoint(x: 0.0, y: 0.0))   //  connection point on rod, centered
        bezierPath.line(to: NSPoint(x: 0.0, y: -angleBracketDescent)) //  Bottom left
        bezierPath.line(to: NSPoint(x: angleBracketThickness, y: -angleBracketDescent)) //  Inside Bottom left
        bezierPath.line(to: NSPoint(x: angleBracketThickness, y: angleBracketAscent - angleBracketThickness)) //  Inside corner
        bezierPath.line(to: NSPoint(x: angleBracketLength, y: angleBracketAscent - angleBracketThickness)) //  Right side underneath
        bezierPath.line(to: NSPoint(x: angleBracketLength, y: angleBracketAscent))      //  Right side top
        bezierPath.line(to: NSPoint(x: 0.0, y: angleBracketAscent))      //  Left side top
        bezierPath.line(to: NSPoint(x: 0.0, y: 0.0))      //  Back to origint
        bezierPath.close()
        let angleBracketGeometry = SCNShape(path: bezierPath, extrusionDepth: angleBracketLWidth)
        angleBracketGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        
        //  Create the elbow side angle bracket
        var angleBracketNode = SCNNode(geometry: angleBracketGeometry)
        angleBracketNode.rotation = SCNVector4Make(0.0, 1.0, 0.0, CGFloat.pi * -0.5)
        angleBracketNode.position = SCNVector3(x: 0.0, y: elbowToRodCenterOffset, z: -0.02465)
        foreArmNode.addChildNode(angleBracketNode)

        //  Rod connection plate, elbow side
        let plateGeometry = SCNCylinder(radius: rodConnectionRadius, height: rodConnectionWidth)
        var plateNode = SCNNode(geometry: plateGeometry)
        plateGeometry.firstMaterial?.diffuse.contents = NSColor(white: 1.0, alpha: 1.0)
        plateNode.rotation = SCNVector4Make(1.0, 0.0, 0.0, CGFloat.pi * 0.5)
        plateNode.position = SCNVector3(x: 0.0, y: elbowToRodCenterOffset, z: -0.0255)
        foreArmNode.addChildNode(plateNode)

        //  Rod
        let rodGeometry = SCNCylinder(radius: foreArmTubeRadius, height: foreArmTubeLength)
        let rodNode = SCNNode(geometry: rodGeometry)
        rodGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.7, alpha: 1.0)
        rodNode.rotation = SCNVector4Make(1.0, 0.0, 0.0, CGFloat.pi * 0.5)
        rodNode.position = SCNVector3(x: 0.0, y: elbowToRodCenterOffset, z: -(foreArmTubeLength + rodConnectionWidth) * 0.5 - 0.0255 )
        foreArmNode.addChildNode(rodNode)

        //  Rod connection plate, wrist side
        plateNode = SCNNode(geometry: plateGeometry)
        plateNode.rotation = SCNVector4Make(1.0, 0.0, 0.0, CGFloat.pi * 0.5)
        plateNode.position = SCNVector3(x: 0.0, y: elbowToRodCenterOffset, z: -0.0255 - foreArmTubeLength - (rodConnectionWidth * 0.5))
        foreArmNode.addChildNode(plateNode)
        
        //  Create the elbow side angle bracket
        angleBracketNode = SCNNode(geometry: angleBracketGeometry)
        angleBracketNode.rotation = SCNVector4Make(0.0, 1.0, 0.0, CGFloat.pi * 0.5)
        angleBracketNode.position = SCNVector3(x: 0.0, y: elbowToRodCenterOffset, z: -0.0255 - foreArmTubeLength - rodConnectionWidth)
        foreArmNode.addChildNode(angleBracketNode)
        
        //  Create the wrist bracket
        bracketGeometry = SCNBox(width: wristBracketLength, height: thickness, length: wristBracketWidth, chamferRadius: 0.0)
        bracketNode = SCNNode(geometry: bracketGeometry)
        bracketGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        bracketNode.position = SCNVector3(x: 0.0314, y: 0.012, z: (wristBracketWidth - angleBracketLWidth) * 0.5)
        angleBracketNode.addChildNode(bracketNode)
        bracketGeometry = SCNBox(width: wristBracketLength, height: wristBracketHeight, length: thickness, chamferRadius: 0.0)
        bracketNode2 = SCNNode(geometry: bracketGeometry)
        bracketGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        bracketNode2.position = SCNVector3(x: 0.0, y: wristBracketHeight * -0.5, z: (wristBracketWidth - thickness) * 0.5)
        bracketNode.addChildNode(bracketNode2)
        
        //  Create the wrist servo
        servoGeometry = SCNBox(width: wristServoHeight, height: wristServoWidth, length: wristServoLength, chamferRadius: 0.0)
        servoNode = SCNNode(geometry: servoGeometry)
        servoGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
        servoNode.position = SCNVector3(x: 0.0, y: 0.0065, z: -0.1786)
        foreArmNode.addChildNode(servoNode)
        
        //  Create the wrist servo wheel
        wheelGeometry = SCNCylinder(radius: servoWheelRadius, height: servoWheelWidth)
        wheelNode = SCNNode(geometry: wheelGeometry)
        wheelGeometry.firstMaterial?.diffuse.contents = NSColor(white: 1.0, alpha: 1.0)
        wheelNode.rotation = SCNVector4Make(0.0, 0.0, 1.0, CGFloat.pi * 0.5)
        wheelNode.position = SCNVector3(x: -0.0242, y: CGFloat(wristElevationAboveForeArm), z: -CGFloat(distanceBetweenElbowAndWrist))
        foreArmNode.addChildNode(wheelNode)
        wheelGeometry = SCNCylinder(radius: 0.0035, height: 0.008)
        wheelNode = SCNNode(geometry: wheelGeometry)
        wheelGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
        wheelNode.rotation = SCNVector4Make(0.0, 0.0, 1.0, CGFloat.pi * 0.5)
        wheelNode.position = SCNVector3(x: -0.02, y: CGFloat(wristElevationAboveForeArm), z: -CGFloat(distanceBetweenElbowAndWrist))
        foreArmNode.addChildNode(wheelNode)

        return foreArmNode
    }
    
    func makeWrist(wristRotate: Bool) -> SCNNode
    {
        //  Define the size constants
        let thickness : CGFloat = 0.0016
        let wristBracketLength : CGFloat = 0.0626
        let wristBracketLengthNoRotate : CGFloat = 0.0410
        let wristBracketHeight : CGFloat = 0.0245
        let wristBracketWidth : CGFloat = 0.053
        let wristOffsetFromJoint: CGFloat = 0.0118        //  Length extension from pivot point
        let wristRotateServoLength : CGFloat = 0.0325
        let wristRotateServoHeight : CGFloat = 0.0315
        let wristRotateServoWidth : CGFloat = 0.01677

        //  Create a wrist node - centered at the wrist joint
        let wristNode = SCNNode()
        
        //  Left side of wrist bracket
        var bracketLength = wristBracketLength
        if (!wristRotate) { bracketLength = wristBracketLengthNoRotate }
        var bracketGeometry = SCNBox(width: thickness, height: wristBracketHeight, length: bracketLength, chamferRadius: 0.0)
        var bracketNode = SCNNode(geometry: bracketGeometry)
        bracketGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        bracketNode.position = SCNVector3(x: (wristBracketWidth - thickness) * -0.5, y: 0.0, z: (bracketLength * 0.5) - wristOffsetFromJoint)
        wristNode.addChildNode(bracketNode)
        
        //  Right side of wrist bracket
        bracketNode = SCNNode(geometry: bracketGeometry)
        bracketNode.position = SCNVector3(x: (wristBracketWidth - thickness) * 0.5, y: 0.0, z: (bracketLength * 0.5) - wristOffsetFromJoint)
        wristNode.addChildNode(bracketNode)
        
        //  Bottom of wrist bracket
        bracketGeometry = SCNBox(width: wristBracketWidth, height: wristBracketHeight, length: thickness, chamferRadius: 0.0)
        bracketNode = SCNNode(geometry: bracketGeometry)
        bracketGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        bracketNode.position = SCNVector3(x: 0.0, y: 0.0, z: bracketLength - wristOffsetFromJoint)
        wristNode.addChildNode(bracketNode)

        //  Add an axle (is a bearing in arm)
        let axleGeometry = SCNCylinder(radius: 0.0038, height: 0.008)
        axleGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.9, alpha: 1.0)
        let axleNode = SCNNode(geometry: axleGeometry)
        axleNode.rotation = SCNVector4Make(0.0, 0.0, 1.0, CGFloat.pi * 0.5)
        axleNode.position = SCNVector3(x: wristBracketWidth * 0.5 - 0.002, y: 0.0, z: 0.0)
        wristNode.addChildNode(axleNode)
        
        //  Create the wrist rotate servo
        if (wristRotate) {
            let servoGeometry = SCNBox(width: wristRotateServoLength, height: wristRotateServoWidth, length: wristRotateServoHeight, chamferRadius: 0.0)
            let servoNode = SCNNode(geometry: servoGeometry)
            servoGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
            servoNode.position = SCNVector3(x: -0.00075, y: 0.0, z: bracketLength - wristOffsetFromJoint - wristRotateServoHeight * 0.5 + 0.008)
            wristNode.addChildNode(servoNode)
        }

        return wristNode
    }
    
    func makeGripper(wristRotate: Bool, gripperServoUp : Bool) -> SCNNode
    {
        let axleRadius : CGFloat = 0.00512
        let axleLength : CGFloat = 0.007
        let plateLength : CGFloat = 0.064
        let plateWidth : CGFloat = 0.01335
        let plateThickness : CGFloat = 0.00225
        let trayWidth : CGFloat = 0.0248
        let gripperServoLength : CGFloat = 0.0406
        let gripperServoHeight : CGFloat = 0.02775
        let gripperServoWidth : CGFloat = 0.0198
        
        let gripperFingerLength : CGFloat = 0.0311
        let gripperFingerTipWidth : CGFloat = 0.00333
        let gripperFingerBaseWidth : CGFloat = 0.0116
        let gripperFingerBaseLength : CGFloat = 0.0102
        let gripperFingerHeight : CGFloat = 0.0195
        let padLength : CGFloat = 0.0262

        //  Create a gripper node - centered at the rotate joint
        let gripperNode = SCNNode()
        
        //  Create the plate node plate
        let plateGeometry = SCNBox(width: plateLength, height: plateThickness, length: plateWidth, chamferRadius: 0.0)
        let plateNode = SCNNode(geometry: plateGeometry)
        plateGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        if (!gripperServoUp) {
            plateNode.rotation = SCNVector4Make(0.0, 1.0, 0.0, CGFloat.pi)
        }

        //  Add a rotate axle (is servo axle)
        if (wristRotate) {
            let axleNode : SCNNode
            let axleGeometry = SCNCylinder(radius: axleRadius, height: axleLength)
            axleGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
            axleNode = SCNNode(geometry: axleGeometry)
            axleNode.rotation = SCNVector4Make(1.0, 0.0, 0.0, CGFloat.pi * 0.5)
            axleNode.position = SCNVector3(x: 0.0, y: 0.0, z: axleLength * 0.5)
            gripperNode.addChildNode(axleNode)

            //  Add plate
            plateNode.position = SCNVector3(x: 0.0, y: (axleLength + plateThickness) * 0.5, z: 0.0)
            axleNode.addChildNode(plateNode)
        }
        
        //  No rotate - attach plate directly to wrist
        else {
            //  Add plate
            let connectNode = SCNNode()     //  Connection node that can be rotated for connection purposes, without being affected by the wrist rotate rotation
            connectNode.rotation = SCNVector4Make(1.0, 0.0, 0.0, CGFloat.pi * 0.5)
            plateNode.position = SCNVector3(x: 0.0, y: -0.0048, z: 0.0)
            connectNode.addChildNode(plateNode)
            gripperNode.addChildNode(connectNode)
        }
        
        //  Add tray bottom
        var trayGeometry = SCNBox(width: plateLength, height: trayWidth, length: plateThickness, chamferRadius: 0.0)
        var trayNode = SCNNode(geometry: trayGeometry)
        trayGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        trayNode.position = SCNVector3(x: 0.0, y: (trayWidth - plateThickness) * 0.5, z: -(plateWidth - plateThickness) * 0.5)
        plateNode.addChildNode(trayNode)

        //  Add tray back (another plate)
        trayGeometry = SCNBox(width: plateLength, height: plateThickness, length: plateWidth, chamferRadius: 0.0)
        trayNode = SCNNode(geometry: trayGeometry)
        trayGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        trayNode.position = SCNVector3(x: 0.0, y: (trayWidth - plateThickness), z: 0.0)
        plateNode.addChildNode(trayNode)
        
        //  Create the gripper servo
        let servoGeometry = SCNBox(width: gripperServoLength, height: gripperServoWidth, length: gripperServoHeight, chamferRadius: 0.0)
        let servoNode = SCNNode(geometry: servoGeometry)
        servoGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
        servoNode.position = SCNVector3(x: 0.0, y: (gripperServoWidth + plateThickness) * 0.5, z: (gripperServoHeight - plateWidth + plateThickness) * 0.5)
        plateNode.addChildNode(servoNode)

        //  Create the gripper finger shape
        let bezierPath = NSBezierPath()
        bezierPath.move(to: NSPoint(x: 0.0, y: 0.0))   //  inside corner, near tray
        bezierPath.line(to: NSPoint(x: 0.0, y: gripperFingerLength)) //  inside tip
        bezierPath.line(to: NSPoint(x: gripperFingerTipWidth, y: gripperFingerLength)) //  inside tip
        bezierPath.line(to: NSPoint(x: gripperFingerBaseWidth, y: gripperFingerBaseLength)) //  outside inflection
        bezierPath.line(to: NSPoint(x: gripperFingerBaseWidth, y: 0.0)) //  outside base
        bezierPath.line(to: NSPoint(x: 0.0, y: 0))
        bezierPath.close()
        let gripperFingerGeometry = SCNShape(path: bezierPath, extrusionDepth: gripperFingerHeight)
        gripperFingerGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1.0)
        
        //  Create right finger
        rightFingerNode = SCNNode(geometry: gripperFingerGeometry)
        rightFingerNode!.position = SCNVector3(x: CGFloat(padThickness), y: plateThickness * -0.5, z: 0.0)
        trayNode.addChildNode(rightFingerNode!)
        
        //  Add a pad to the right finger
        let padGeometry = SCNBox(width: CGFloat(padThickness), height: padLength, length: gripperFingerHeight, chamferRadius: 0.0)
        padGeometry.firstMaterial?.diffuse.contents = NSColor(white: 0.45, alpha: 1.0)
        var padNode = SCNNode(geometry: padGeometry)
        padNode.position = SCNVector3(x: CGFloat(padThickness * -0.5), y: gripperFingerLength - (padLength * 0.5), z: 0.0)
        rightFingerNode!.addChildNode(padNode)

        //  Create left finger
        leftFingerNode = SCNNode(geometry: gripperFingerGeometry)
        leftFingerNode!.rotation = SCNVector4Make(0.0, 1.0, 0.0, CGFloat.pi)
        leftFingerNode!.position = SCNVector3(x: CGFloat(-padThickness), y: plateThickness * -0.5, z: 0.0)
        trayNode.addChildNode(leftFingerNode!)
        
        //  Add a pad to the left finger
        padNode = SCNNode(geometry: padGeometry)
        padNode.position = SCNVector3(x: CGFloat(padThickness * -0.5), y: gripperFingerLength - (padLength * 0.5), z: 0.0)
        leftFingerNode!.addChildNode(padNode)

        return gripperNode
    }

    func setArmPositions(elapsedTime : Double, DOFValues : [Double])
    {
        //  Initialize max difference
        var maxDifference = 0.0

        //  Adjust the swivel
        var swivelDifference = DOFValues[0] - swivelAngle
        var timeToReachAngle = abs(swivelDifference) / servoList[0].rotateRate        //  In seconds
        if (timeToReachAngle > elapsedTime) {
            swivelDifference *= elapsedTime / timeToReachAngle
        }
        if (abs(swivelDifference) > maxDifference) { maxDifference = abs(swivelDifference) }
        
        //  Adjust the shoulder
        var shoulderDifference = DOFValues[1] - shoulderAngle
        timeToReachAngle = abs(shoulderDifference) / servoList[1].rotateRate        //  In seconds
        if (timeToReachAngle > elapsedTime) {
            shoulderDifference *= elapsedTime / timeToReachAngle
        }
        if (abs(shoulderDifference) > maxDifference) { maxDifference = abs(shoulderDifference) }
        
        //  Adjust the elbow
        var elbowDifference = DOFValues[2] - elbowAngle
        timeToReachAngle = abs(elbowDifference) / servoList[2].rotateRate        //  In seconds
        if (timeToReachAngle > elapsedTime) {
            elbowDifference *= elapsedTime / timeToReachAngle
        }
        if (abs(elbowDifference) > maxDifference) { maxDifference = abs(elbowDifference) }
        
        //  Adjust the wrist
        var wristDifference = DOFValues[3] - wristAngle
        timeToReachAngle = abs(wristDifference) / servoList[3].rotateRate        //  In seconds
        if (timeToReachAngle > elapsedTime) {
            wristDifference *= elapsedTime / timeToReachAngle
        }
        if (abs(wristDifference) > maxDifference) { maxDifference = abs(wristDifference) }
        
        //  Adjust the gripper
        var gripperDifference = DOFValues[4] - gripperAngle
        timeToReachAngle = abs(gripperDifference) / servoList[4].rotateRate        //  In seconds
        if (timeToReachAngle > elapsedTime) {
            gripperDifference *= elapsedTime / timeToReachAngle
        }
        if (abs(gripperDifference) > maxDifference) { maxDifference = abs(gripperDifference) }

        //  Adjust the wrist rotator
        var wristRotateDifference = DOFValues[5] - wristRotateAngle
        timeToReachAngle = abs(wristDifference) / servoList[5].rotateRate        //  In seconds
        if (timeToReachAngle > elapsedTime) {
            wristRotateDifference *= elapsedTime / timeToReachAngle
        }
        if (abs(wristRotateDifference) > maxDifference) { maxDifference = abs(wristRotateDifference) }

        //  Calculate the number of kinematic runs to check every 1/10 of a degree or less
        var numIterations = 1
        if (maxDifference > 0.1) {
            numIterations = Int(maxDifference * 10.0) + 1
            let iterationFraction = 1.0 / Double(numIterations)
            swivelDifference *= iterationFraction
            shoulderDifference *= iterationFraction
            elbowDifference *= iterationFraction
            wristDifference *= iterationFraction
            gripperDifference *= iterationFraction
            wristRotateDifference *= iterationFraction
        }
        
        for _ in 0..<numIterations {
            swivelAngle += swivelDifference
            shoulderAngle += shoulderDifference
            elbowAngle += elbowDifference
            wristAngle += wristDifference
            gripperAngle += gripperDifference
            wristRotateAngle += wristRotateDifference

            //  Perform the forward kinematics to get any collisions
            if (forwardKinematics()) {
                //  Go back to the pre-collision angles
                swivelAngle -= swivelDifference
                shoulderAngle -= shoulderDifference
                elbowAngle -= elbowDifference
                wristAngle -= wristDifference
                gripperAngle -= gripperDifference
                wristRotateAngle -= wristRotateDifference
                break
            }
        }

        //  Set the swivel rotation
        let plateRadians = CGFloat(swivelAngle) * CGFloat.pi / -180.0
        plateNode!.rotation = SCNVector4Make(0.0, 1.0, 0.0, plateRadians)
        
        //  Set the shoulder rotation
        let shoulderRadians = CGFloat(-shoulderAngle) * CGFloat.pi / 180.0
        upperArmNode!.rotation = SCNVector4Make(1.0, 0.0, 0.0, shoulderRadians)
        
        //  Set the elbow rotation
        let elbowRadians = CGFloat(-elbowAngle) * CGFloat.pi / 180.0
        foreArmNode!.rotation = SCNVector4Make(1.0, 0.0, 0.0, elbowRadians)
        
        //  Set the wrist rotation
        let wristRadians = CGFloat(-wristAngle) * CGFloat.pi / 180.0 + CGFloat.pi
        wristNode!.rotation = SCNVector4Make(1.0, 0.0, 0.0, wristRadians)
        
        //  Set the gripper finger positions
        let fingerMovement = fingerMovementRange * (gripperAngle + 90.0) / 180.0
        rightFingerNode!.position = SCNVector3(x: CGFloat(fingerMovement + padThickness), y: gripperPlateThickness * -0.5, z: 0.0)
        leftFingerNode!.position = SCNVector3(x: CGFloat(-(fingerMovement + padThickness)), y: gripperPlateThickness * -0.5, z: 0.0)

        //  Set the wrist rotator rotation
        let wristRotatorRadians = CGFloat(-wristRotateAngle) * CGFloat.pi / 180.0
        gripperNode!.rotation = SCNVector4Make(0.0, 0.0, 1.0, wristRotatorRadians)
    }
    
    func setKinematics(wristRotate: Bool)
    {
        /*
        Denavit - Hartenberg Parameters
           θ - angle to rotate frame N-1 around axis Zn-1 to have Xn-1 point in same direction as Xn
           α - angle to rotate frame N-1 around axis Xn to have Zn-1 point in same direction as Zn
           r - distance between center of frame N-1 to center of frame N along axis Xn  (length of common normal)
           d - distance between center of frame N-1 to center of frame N, along axis Zn-1               */

 
        //  Clear the previous parameters
        dhParameters = []
        
        //  Base reference frame is the bottom-center of the base.  Y in forward direction (to the right in the diagram), X to the right, Z up
        
        //  First transform is from the base rotator to the shoulder.
        //  d1 is base to shoulder height - 73 mm
        let p1 = DenavitHartenberg(variableParameter: .θ, θdegrees: 90.0, αdegrees: 90.0, r: 0.0, d: 0.073)
        dhParameters.append(p1)
        
        //  Second transform is from the shoulder to the elbow.
        //  d2 is shoulder to elbow distance - 144 mm
        let p2 = DenavitHartenberg(variableParameter: .θ, θdegrees: -90.0, αdegrees: 0.0, r: -0.144, d: 0.0)
        dhParameters.append(p2)
        
        //  Third transform is from the elbow to the wrist.
        //  d3 is elbow to wrist distance - 184 mm
        let p3 = DenavitHartenberg(variableParameter: .θ, θdegrees: 90.0, αdegrees: 0.0, r: 0.184, d: 0.0)
        dhParameters.append(p3)
        
        //  Fourth transform is from the wrist to the wrist rotator.
        //  d5 is wrist rotator offset distance - 6.8 mm (if there is a wrist rotate)
        if (wristRotate) {
            let p4 = DenavitHartenberg(variableParameter: .θ, θdegrees: -90.0, αdegrees: -90.0, r: 0.0, d: 0.0068)
            dhParameters.append(p4)
        }
        else {
            let p4 = DenavitHartenberg(variableParameter: .θ, θdegrees: -90.0, αdegrees: -90.0, r: 0.0, d: 0.0)
            dhParameters.append(p4)
        }
        
        //  Fifth transform is from the wrist rotator frame (moved back to even with wrist frame to match DH rules) to the center of the gripper.
        //  d4 + d6 is distance from wrist to center of gripper - 106 mm if wrist rotate, 85.5 with no rotate
        if (wristRotate) {
            let p5 = DenavitHartenberg(variableParameter: .θ, θdegrees: -90.0, αdegrees: 90.0, r: 0.0, d: 0.106)
            dhParameters.append(p5)
        }
        else {
            let p5 = DenavitHartenberg(variableParameter: .None, θdegrees: -90.0, αdegrees: 90.0, r: 0.0, d: 0.0855)
            dhParameters.append(p5)
            
        }
    }
    
    func forwardKinematics() -> Bool
    {
        //  Set up the variables
        var variables = [Double](repeating: 0.0, count: 6)
        variables[0] = -swivelAngle         //  Positive must be RHR around Z axis of frame 0
        variables[1] = -shoulderAngle       //  Positive must be RHR around Z axis of frame 1
        variables[2] = -elbowAngle          //  Positive must be RHR around Z axis of frame 2
        variables[3] = -wristAngle          //  Positive must be RHR around Z axis of frame 3
        variables[4] = wristRotateAngle

        //  Run the matrix
        endEffectorHTM = DenavitHartenberg.matrix(parameters : dhParameters, variables : variables, isInDegrees : true)
        
        return (endEffectorHTM[3, 2] < 0.01)     //  Z coordinate of center of end effector below 1 cm
    }
    
    func inverseKinematics(initialDOFValues : [Double], desiredX : Double, desiredY : Double, desiredZ : Double) -> (foundSolution: Bool, setting: [Double])
    {
        /*
         As the wrist rotate (if even included) only affects the orientation of the end effector (gripper), only the first four DOF angles need to be determined
         We will use numerical differences to approximate the derivitives for the Jacobian, as we don't have a proper analytical solution for the HTM,
         Use the derivitives to calculate next DOF angles to start with, and repeat until converged, or max iterations have occurred
         
         Δp ≅ ∂p/∂θ × Δθ   ==>  Δθ = (∂p/∂θ)⁻¹ × Δp    where: p - position,  θ - DOF angles
         
         However, we have a 4x3 matrix for the Jacobian (4 DOF, three position), so we have to use the pseudo inverse instead (A+)
                            (AtA)⁻¹At = A+  (for linearly independent columns) or At(A At)⁻¹ = A+ (for linearly independent rows)
                            where At is the transpose of the matrix, and A+ is the pseudo-inverse
         
         From https://homes.cs.washington.edu/~todorov/courses/cseP590/06_JacobianMethods.pdf
         Where J(0) is the Jacobian, JT(0) is the transpose of the Jacobian, α is learning rate, x is position vector
         Jacobian transpose method Δθ = αJT(θ)Δx
         Jacobian inverse method  Δθ = αJT(θ)(J(θ)JT(θ))-1 Δx = J#Δx            J# is pseudo-inverse of Jacobian
         
         */
        
        //  Convert current DOF to radians for calcs, and if needed pad the DOF values with zeros for gripper/wristRotate
        var currentDOFValues : [Double] = []
        for angle in initialDOFValues {
            currentDOFValues.append(angle * Double.pi / 180.0)
        }
        while (currentDOFValues.count < 6) { currentDOFValues.append(0.0) }
        
        for _ in 0...500 {       //  Max of 500 iterations
            
            //  Get the position of the current angle set using the forward kinematics
            let currentHTM = DenavitHartenberg.matrix(parameters : dhParameters, variables : currentDOFValues, isInDegrees : false)
            
            //  Get the position error vector
            var errorVector : [Double] = []
            errorVector.append(desiredX - currentHTM[3,0])
            errorVector.append(desiredY - currentHTM[3,1])
            errorVector.append(desiredZ - currentHTM[3,2])
            
            //  Get the total error
            let sum = errorVector.reduce(0) { $0 + fabs($1) }
            if (sum < 0.0001) {     //  If within a tenth of a millimeter error, we are converged enough
                //  Convert back to degrees
                return (foundSolution: true, setting: currentDOFValues.map { $0 * 180.0 / Double.pi } )
            }
            
            //  For each of the four DOF angles, add 0.001 radians, and get the change to the HTM
            var Jacobian = matrix_double4x3()
            for index in 0..<4 {
                let save = currentDOFValues[index]
                currentDOFValues[index] += 0.001
                let deltaHTM = DenavitHartenberg.matrix(parameters : dhParameters, variables : currentDOFValues, isInDegrees : false)
                for dim in 0..<3 {
                    Jacobian[index, dim] = (deltaHTM[3, dim] - currentHTM[3, dim]) / 0.001
                }
                currentDOFValues[index] = save
            }
            
            //  Now get the change to the angles by multiplying the pseudo-inverse of the Jacobian by the error vector
            let vector = SIMD3<Double>(errorVector[0], errorVector[1], errorVector[2])
            let Δθ = Jacobian.pseudoInverse() * vector

            //  Update the angles
            for dof in 0..<4 {
                currentDOFValues[dof] += Δθ[dof] * 0.1      //  One-tenth for alpha (learning rate)
            }
        }

        return (foundSolution: false, setting: initialDOFValues)    //  If we failed to converge, return the original position
    }
}

extension matrix_double4x3
{
    func pseudoInverse() -> matrix_double3x4
    {
        //  A+ = At(AAt)⁻¹       where At is the transpose of the matrix, and A+ is the pseudo-inverse
        let transpose = self.transpose
        let product = self * transpose
        let inverse = product.inverse
        return transpose * inverse
    }
}
