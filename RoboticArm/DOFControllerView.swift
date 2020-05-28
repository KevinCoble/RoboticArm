//
//  DOFControllerView.swift
//  RoboticArm
//
//  Created by Kevin Coble on 5/5/20.
//  Copyright © 2020 Kevin Coble. All rights reserved.
//

import SwiftUI

struct DOFControllerView: View {
    var servo : Servo
    @Binding var value : Double
    
    var body: some View {
        VStack {
            HStack {
                Text(servo.name)
                Text("   ")
                Text("\(value)")
            }
            HStack {
                Text("\(Int(servo.minAngleDegrees))")
                Slider(value: $value, in: servo.minAngleDegrees...servo.maxAngleDegrees)
                Text("\(Int(servo.maxAngleDegrees))")
            }.padding()
        }.border(Color.blue)
    }
}

struct DOFControllerView_Previews: PreviewProvider {
    @State static var value = 0.0
    static let servo = Servo(jointName: "Test", jointType: "HS-485HB", minimumAngleDegrees: -90.0, maximumAngleDegrees: 90.0, rotationSpeed: 0.18)
    static var previews: some View {
        DOFControllerView(servo: servo, value: $value)
    }
}
