//
//  MainView.swift
//  RoboticArm
//
//  Created by Kevin Coble on 5/16/20.
//  Copyright © 2020 Kevin Coble. All rights reserved.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewData: ViewData

    var body: some View {
        HStack {
            VStack {
                VStack {
                    Text("Settings")
                    Divider()
                    Text("Robot Configuration")
                    Toggle("Has Wrist Rotate", isOn: $viewData.hasWristRotate)
                    .toggleStyle(DefaultToggleStyle())
                    Toggle("Gripper Servo Facing Up", isOn: $viewData.gripperServoUp)
                    .toggleStyle(DefaultToggleStyle())
                    Divider()
                    Text("Connection")
                    Picker(selection: $viewData.portConnection, label: Text("Port")
                         , content: {
                            ForEach(0 ..< viewData.portList.count) { index in
                                 Text(self.viewData.portList[index])
                                     .tag(index)
                             }
                    })
                     .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    Picker(selection: $viewData.baudRateSelection, label: Text("Baud Rate")
                         , content: {
                             Text("9600").tag(0)
                             Text("38400").tag(1)
                             Text("115200").tag(2)
                      })
                     .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                }
                VStack {
                    Text("Kinematics")
                    Picker(selection: $viewData.kinematicUnits, label:
                        Text("Units")
                        , content: {
                            Text("m").tag(0)
                            Text("cm").tag(1)
                            Text("mm").tag(2)
                    }).pickerStyle(SegmentedPickerStyle())
                    Divider()
                    VStack {
                        Text("Forward Kinematics")
                        Divider()
                        HStack {
                            Text("End Effector X: ")
                            Text("\(viewData.endEffectorX)")
                        }
                        HStack {
                            Text("End Effector Y: ")
                            Text("\(viewData.endEffectorY)")
                        }
                        HStack {
                            Text("End Effector Z: ")
                            Text("\(viewData.endEffectorZ)")
                        }
                    }
                    .border(Color.blue)
                    .padding()
                    Divider()
                    VStack {
                        Text("Inverse Kinematics")
                        Divider()
                        HStack {
                            Text("X: ")
                            TextField("Desired X", value: $viewData.desiredX, formatter: DoubleFormatter())
                        }
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                        HStack {
                            Text("Y: ")
                            TextField("Desired Y", value: $viewData.desiredY, formatter: DoubleFormatter())
                        }
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                        HStack {
                            Text("Z: ")
                            TextField("Desired Z", value: $viewData.desiredZ, formatter: DoubleFormatter())
                        }
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                        Toggle("Vertical Gripper", isOn: $viewData.verticalEndEffector)
                        HStack {
                            Button("Check Position") {
                                self.viewData.CheckPosition()
                            }
                            Button("Go To Position") {
                                self.viewData.goToPosition()
                            }
                             
                        }
                        .padding()
                        Text(viewData.kinematicAlertText)
                             .foregroundColor(Color.red)
                    }
                    .border(Color.blue)
                    .padding()
                }
                .border(Color.blue)
                .padding()
            }
            .frame(width: 320.0, height: nil, alignment: Alignment.top)
            VStack {
                Text("Visualizer")
                SceneView(scene: viewData.visualizationScene, viewData: viewData).frame(width: 600, height: 600, alignment: Alignment.center)
            }
            VStack {
                Text("Controls")
                DOFControllerView(servo: viewData.robotArm.servoList[0], value: $viewData.userDOFAngle1)
                DOFControllerView(servo: viewData.robotArm.servoList[1], value: $viewData.userDOFAngle2)
                DOFControllerView(servo: viewData.robotArm.servoList[2], value: $viewData.userDOFAngle3)
                DOFControllerView(servo: viewData.robotArm.servoList[3], value: $viewData.userDOFAngle4)
                DOFControllerView(servo: viewData.robotArm.servoList[4], value: $viewData.userDOFAngle5)
                if (viewData.hasWristRotate) {
                    DOFControllerView(servo: viewData.robotArm.servoList[05], value: $viewData.userDOFAngle6)
                }
                Button("Center All Servos") {
                    self.viewData.centerAllServos()
                }
                .padding()
            }
            .frame(width: 350.0, height: nil, alignment: Alignment.top)
            .padding()
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
