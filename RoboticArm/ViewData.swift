//
//  ViewData.swift
//  RoboticArm
//
//  Created by Kevin Coble on 11/16/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Foundation
import Combine
import SceneKit


class Observable<T>: ObservableObject, Identifiable {
    let id = UUID()
    let objectWillChange = ObservableObjectPublisher()
    let publisher = PassthroughSubject<T, Never>()
    var value: T {
        willSet { objectWillChange.send() }
        didSet { publisher.send(value) }
    }

    init(_ initValue: T) { self.value = initValue }
}

typealias ObservableInt = Observable<Int>

public final class ViewData: ObservableObject  {
    
    @Published var hasWristRotate : Bool = true
    @Published var gripperServoUp : Bool = true
    @Published var portConnection : Int = 0
    @Published var baudRateSelection : Int = 0
    @Published var portList : [String] = ["None Found"]

    var visualizationView : SCNView?
    
    @Published var visualizationScene = SCNScene()
    public var simulationTime = 0.0
    @Published public var simulationSpeed : Double = 0.0
    
    @Published var userDOFAngle1 = 0.0
    @Published var userDOFAngle2 = 0.0
    @Published var userDOFAngle3 = 0.0
    @Published var userDOFAngle4 = 0.0
    @Published var userDOFAngle5 = 0.0
    @Published var userDOFAngle6 = 0.0
    @Published var userDOFAngle7 = 0.0
    @Published var userDOFAngle8 = 0.0
    @Published var userDOFAngle9 = 0.0
    @Published var userDOFAngle10 = 0.0
    
    @Published var kinematicUnits = 0
    
    @Published var endEffectorX = 0.0
    @Published var endEffectorY = 0.0
    @Published var endEffectorZ = 0.0
    
    @Published var verticalEndEffector = false
    
    @Published var desiredX = 0.0
    @Published var desiredY = 0.0
    @Published var desiredZ = 0.0
    
    //  Kinematic error alert
//    @Published var showKinematicAlert = false     //  Actual alert was being instantiated repeatedly (error in SwiftUI?).  Switched to just text
    @Published var kinematicAlertText = ""



    var robotArm = RobotArm()
    var usb: USBInterface!
    
    //  Combine subscribers
    private var wristRotateChanged: AnyCancellable?
    private var gripperServoUpChanged: AnyCancellable?
    private var portChanged: AnyCancellable?
    private var baudRateChanged: AnyCancellable?
    
    private var DOF1Changed: AnyCancellable?
    private var DOF2Changed: AnyCancellable?
    private var DOF3Changed: AnyCancellable?
    private var DOF4Changed: AnyCancellable?
    private var DOF5Changed: AnyCancellable?
    private var DOF6Changed: AnyCancellable?
    
    private var inMultipleMoveCommand = false

    init()
    {

        //  Create the USB interace
        usb = USBInterface()
        
        //  Get the port names, strip path, and generate a list for the selection control
        portList = []
        for port in usb.serialDeviceList {
            //  Remove everything before the period
            if let index = port.lastIndex(of: ".") {
                let firstAfter = port.index(after: index)
                portList.append(String(port[firstAfter...]))
            }
            else {
                //  No period found.  Try a slash
                if let index = port.lastIndex(of: "/") {
                    let firstAfter = port.index(after: index)
                    portList.append(String(port[firstAfter...]))
                }
                else {
                    //  No slash found either.  Use whole path
                    portList.append(port)
                }
            }
        }
        if (portList.count == 0) {
            portList.append("None Found")
        }
        
        //  Set up the parameter change subscribers
        wristRotateChanged = self.$hasWristRotate
            .sink(receiveCompletion: { print ($0) }, receiveValue: { self.update3DScene(wristRotate : $0, gripperServoUp : self.gripperServoUp) } )
        gripperServoUpChanged = self.$gripperServoUp
            .sink(receiveCompletion: { print ($0) }, receiveValue: { self.update3DScene(wristRotate : self.hasWristRotate, gripperServoUp : $0) } )
        portChanged = self.$portConnection
            .sink(receiveCompletion: { print ($0) }, receiveValue: { self.setSelectedPort($0) } )
        baudRateChanged = self.$baudRateSelection
            .sink(receiveCompletion: { print ($0) }, receiveValue: { self.setBaudRate($0) } )
        
        //  Set up the DOF setting change subscribers
        let q = DispatchQueue(label: "Servo command thread")
        DOF1Changed = self.$userDOFAngle1   //  Base
            .throttle(for: .milliseconds(90), scheduler: q, latest: true)
             .sink(receiveCompletion: { print ($0) }, receiveValue: { self.sendServoPosition(0, $0) } )
        DOF2Changed = self.$userDOFAngle2   //  Shoulder
            .throttle(for: .milliseconds(90), scheduler: q, latest: true)
            .sink(receiveCompletion: { print ($0) }, receiveValue: { self.sendServoPosition(1, $0 * -1) } )
        DOF3Changed = self.$userDOFAngle3   //  Elbow
            .throttle(for: .milliseconds(90), scheduler: q, latest: true)
            .sink(receiveCompletion: { print ($0) }, receiveValue: { self.sendServoPosition(2, $0) } )
        DOF4Changed = self.$userDOFAngle4   //  Wrist
            .throttle(for: .milliseconds(90), scheduler: q, latest: true)
            .sink(receiveCompletion: { print ($0) }, receiveValue: { self.sendServoPosition(3, $0 * -1) } )
        DOF5Changed = self.$userDOFAngle5   //  Gripper
            .throttle(for: .milliseconds(90), scheduler: q, latest: true)
            .sink(receiveCompletion: { print ($0) }, receiveValue: { self.sendServoPosition(4, $0 * -1) } )
        DOF6Changed = self.$userDOFAngle6   //  Wrist Rotate
            .throttle(for: .milliseconds(90), scheduler: q, latest: true)
            .sink(receiveCompletion: { print ($0) }, receiveValue: { self.sendServoPosition(5, $0) } )

        //  Set the initial 3D scene
        update3DScene(wristRotate : hasWristRotate, gripperServoUp : gripperServoUp)
    }
    
    public func update3DScene(wristRotate : Bool, gripperServoUp : Bool)
    {
        //  Stop update
        visualizationView?.rendersContinuously = false
        
        //  Clear anything previous
        visualizationScene.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
        }

        //  Create a camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        visualizationScene.rootNode.addChildNode(cameraNode)
        cameraNode.camera!.zFar = Double(20.0)
        cameraNode.camera!.zNear = Double(0.01)
        cameraNode.position = SCNVector3(x: 0.0, y: -0.5, z: 0.5)
        cameraNode.rotation = SCNVector4Make(1.0, 0.0, 0.0, CGFloat.pi * 0.27)
        
        //  Create a light
        let sunNode = SCNNode()
        sunNode.light = SCNLight()
        sunNode.light!.type = SCNLight.LightType.omni
        sunNode.light!.color = NSColor(white: 1.0, alpha: 1.0)
        sunNode.position = SCNVector3Make(0.0, 0.0, 1000.0)
        visualizationScene.rootNode.addChildNode(sunNode)
        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light!.type = SCNLight.LightType.ambient
        ambientNode.light!.color = NSColor(white: 0.3, alpha: 1.0)
        visualizationScene.rootNode.addChildNode(ambientNode)
        
        //  Add a floor
        let floorGeometry = SCNFloor()
        floorGeometry.reflectivity = 0.1
        floorGeometry.firstMaterial?.diffuse.contents = NSColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0)
        let floorNode = SCNNode(geometry: floorGeometry)
        floorNode.rotation = SCNVector4Make(1.0, 0.0, 0.0, CGFloat.pi * 0.5)
        visualizationScene.rootNode.addChildNode(floorNode)
        
        //  Add a robot arm
        visualizationScene.rootNode.addChildNode(robotArm.make3DModel(wristRotate: wristRotate, gripperServoUp: gripperServoUp))
        
        //  Set the kinematic parameters for the arm
        robotArm.setKinematics(wristRotate: wristRotate)

        //  Set the arm position
        robotArm.setArmPositions(elapsedTime: 0.0, DOFValues: getDOFValues())
        
        //  Restart the update
        visualizationView?.rendersContinuously = true

    }
    
    func updateSimulation(elapsedTime: Double)
    {
        //  Update the 3D model
        robotArm.setArmPositions(elapsedTime: elapsedTime, DOFValues: getDOFValues())
        
        //  Set the end effector output
        DispatchQueue.main.async {
            var multiplier = 1.0
            if (self.kinematicUnits == 1) { multiplier = 100.0 }
            if (self.kinematicUnits == 2) { multiplier = 1000.0 }
            self.endEffectorX = self.robotArm.endEffectorHTM[3,0] * multiplier
            self.endEffectorY = self.robotArm.endEffectorHTM[3,1] * multiplier
            self.endEffectorZ = self.robotArm.endEffectorHTM[3,2] * multiplier
        }
    }
    
    func getDOFValues() -> [Double]
    {
        var DOFValues : [Double] = []
        DOFValues.append(userDOFAngle1)
        DOFValues.append(userDOFAngle2)
        DOFValues.append(userDOFAngle3)
        DOFValues.append(userDOFAngle4)
        DOFValues.append(userDOFAngle5)
        DOFValues.append(userDOFAngle6)
        DOFValues.append(userDOFAngle7)
        DOFValues.append(userDOFAngle8)
        DOFValues.append(userDOFAngle9)
        DOFValues.append(userDOFAngle10)
        return DOFValues
    }
    
    func getDH_DOFValues() -> [Double]      //  Angles for Denavit-Hartenberg
    {
        var DOFValues : [Double] = []
        DOFValues.append(userDOFAngle1 * -1.0)
        DOFValues.append(userDOFAngle2 * -1.0)
        DOFValues.append(userDOFAngle3 * -1.0)
        DOFValues.append(userDOFAngle4 * -1.0)
        DOFValues.append(userDOFAngle5)
        DOFValues.append(userDOFAngle6)
        DOFValues.append(userDOFAngle7)
        DOFValues.append(userDOFAngle8)
        DOFValues.append(userDOFAngle9)
        DOFValues.append(userDOFAngle10)
        return DOFValues
    }

    public func setSelectedPort(_ portIndex : Int)
    {
        //  Close any existing port
        usb.closeSerialPort()
        
        //  If the index is out of range, select none
        if (portIndex < 0 || portIndex >= usb.serialDeviceList.count) {
            usb.selectedSerialDevice = ""
            return
        }
        
        //  Set the selected serial to the full path
        usb.selectedSerialDevice = usb.serialDeviceList[portIndex]
        
        //  Open the serial device
        usb.openSelectedDevice()
    }
    
    public func setBaudRate(_ baudRateIndex : Int)
    {
        if let baudRate = BaudRate(rawValue: baudRateIndex) {
            usb.baudRate = baudRate
            
            //  Close any existing port
            usb.closeSerialPort()
            
            //  Open the serial device with the new baud rate
            usb.openSelectedDevice()
        }
    }
    
    public func sendServoPosition(_ servo : Int, _ angle : Double)
    {
        //  Skip if inside a multiple-move command that is setting values
        if (inMultipleMoveCommand) { return }
        
        //  Convert angle to servo position
        let position = robotArm.servoList[servo].getPulseWidthForAngleDegrees(angle)
        
        //  Create the command
        var servoCommands : [ServoCommand] = []
        servoCommands.append(ServoCommand(servo: servo, position: position, speed: nil))
        
        //  Send the command
        usb.createAndSendCommand(servoCommands, time: nil)
    }
    
    public func centerAllServos() {
        inMultipleMoveCommand = true
        userDOFAngle1 = 0.0
        userDOFAngle2 = 0.0
        userDOFAngle3 = 0.0
        userDOFAngle4 = 0.0
        userDOFAngle5 = 0.0
        if (hasWristRotate) {
            userDOFAngle6 = 0.0
        }
        
        //  Send a command to center them all
        var servoCommands : [ServoCommand] = []
        servoCommands.append(ServoCommand(servo: 0, position: 1500, speed: nil))
        servoCommands.append(ServoCommand(servo: 1, position: 1500, speed: nil))
        servoCommands.append(ServoCommand(servo: 2, position: 1500, speed: nil))
        servoCommands.append(ServoCommand(servo: 3, position: 1500, speed: nil))
        servoCommands.append(ServoCommand(servo: 4, position: 1500, speed: nil))
        if (hasWristRotate) {
            servoCommands.append(ServoCommand(servo: 5, position: 1500, speed: nil))
        }
        usb.createAndSendCommand(servoCommands, time: nil)
        inMultipleMoveCommand = false
    }
    
    func CheckPosition()
    {
        var multiplier = 1.0
        if (self.kinematicUnits == 1) { multiplier = 0.01 }
        if (self.kinematicUnits == 2) { multiplier = 0.001 }
        let x = desiredX * multiplier
        let y = desiredY * multiplier
        let z = desiredZ * multiplier
        
        //  Try to find a solution
        var result : (foundSolution: Bool, setting: [Double])
        if (verticalEndEffector) {
            result = robotArm.inverseKinematicsVertical(initialDOFValues : getDH_DOFValues(), desiredX : x, desiredY : y, desiredZ : z)
        }
        else {
            result = robotArm.inverseKinematics(initialDOFValues : getDOFValues(), desiredX : x, desiredY : y, desiredZ : z)
        }
        if (result.foundSolution) {
            self.kinematicAlertText = "Solution Found"
        }
        else {
            self.kinematicAlertText = "No Solution"
        }
    }
    
    func goToPosition()
    {
        var multiplier = 1.0
        if (self.kinematicUnits == 1) { multiplier = 0.01 }
        if (self.kinematicUnits == 2) { multiplier = 0.001 }
        let x = desiredX * multiplier
        let y = desiredY * multiplier
        let z = desiredZ * multiplier

        //  Try to find a solution
        var result : (foundSolution: Bool, setting: [Double])
        if (verticalEndEffector) {
            result = robotArm.inverseKinematicsVertical(initialDOFValues : getDH_DOFValues(), desiredX : x, desiredY : y, desiredZ : z)
        }
        else {
            result = robotArm.inverseKinematics(initialDOFValues : getDOFValues(), desiredX : x, desiredY : y, desiredZ : z)
        }
        if (result.foundSolution) {
            inMultipleMoveCommand = true
            //  Put the angles into the DOF settings (but convert DH rotation directions to servo directions)
            userDOFAngle1 = -result.setting[0]  //  Positive must be RHR around Z axis of frame 0
            userDOFAngle2 = -result.setting[1]  //  Positive must be RHR around Z axis of frame 1
            userDOFAngle3 = -result.setting[2]  //  Positive must be RHR around Z axis of frame 2
            userDOFAngle4 = -result.setting[3]  //  Positive must be RHR around Z axis of frame 3
            
            //  Get the servo commands
            var servoCommands : [ServoCommand] = []
            servoCommands.append(ServoCommand(servo: 0, position: robotArm.servoList[0].getPulseWidthForAngleDegrees(userDOFAngle1), speed: nil))
            servoCommands.append(ServoCommand(servo: 1, position: robotArm.servoList[1].getPulseWidthForAngleDegrees(userDOFAngle2), speed: nil))
            servoCommands.append(ServoCommand(servo: 2, position: robotArm.servoList[2].getPulseWidthForAngleDegrees(userDOFAngle3), speed: nil))
            servoCommands.append(ServoCommand(servo: 3, position: robotArm.servoList[3].getPulseWidthForAngleDegrees(userDOFAngle4), speed: nil))

            //  Calculate the total distance to travel
            let distance = sqrt(((endEffectorX - x) * (endEffectorX - x)) + ((endEffectorY - y) * (endEffectorY - y)) + ((endEffectorZ - z) * (endEffectorZ - z)))
            
            //  Calculate the time (in millisecondes), using 20 cm/sec for a speed
            let travelTime = Int(distance * 1000.0 / 0.2)

            //  Send the commands
            usb.createAndSendCommand(servoCommands, time: travelTime)

            inMultipleMoveCommand = false
            self.kinematicAlertText = "Command Sent"
        }
        else {
            self.kinematicAlertText = "No Solution"
        }
    }
}
