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
                 .padding()
                Picker(selection: $viewData.baudRateSelection, label: Text("Baud Rate")
                     , content: {
                         Text("9600").tag(0)
                         Text("38400").tag(1)
                         Text("115200").tag(2)
                  })
                 .padding()
            }
            .frame(width: 240.0, height: nil, alignment: Alignment.top)
            VStack {
                Text("Visualizer")
                SceneView(scene: viewData.visualizationScene, viewData: viewData).frame(width: 600, height: 600, alignment: Alignment.center)
            }
            VStack {
                Text("Controls")
                DOFControllerView(label: "Swivel", value: $viewData.userDOFAngle1, minValue: -95.25, maxValue: 95.25)
                DOFControllerView(label: "Shoulder", value: $viewData.userDOFAngle2, minValue: -99.75, maxValue: 99.75)
                DOFControllerView(label: "Elbow", value: $viewData.userDOFAngle3, minValue: -101.0, maxValue: 80.0)
                DOFControllerView(label: "Wrist", value: $viewData.userDOFAngle4, minValue: -90.0, maxValue: 90.0)
                DOFControllerView(label: "Gripper", value: $viewData.userDOFAngle5, minValue: -90.0, maxValue: 90.0)
                if (viewData.hasWristRotate) {
                    DOFControllerView(label: "Wrist Rotate", value: $viewData.userDOFAngle6, minValue: -90.0, maxValue: 90.0)
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
