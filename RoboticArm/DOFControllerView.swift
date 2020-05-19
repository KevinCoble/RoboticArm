//
//  DOFControllerView.swift
//  RoboticArm
//
//  Created by Kevin Coble on 5/5/20.
//  Copyright © 2020 Kevin Coble. All rights reserved.
//

import SwiftUI

struct DOFControllerView: View {
    var label : String
    @Binding var value : Double
    var minValue : Double
    var maxValue : Double
    
    var body: some View {
        VStack {
            HStack {
                Text(label)
                Text("   ")
                Text("\(value)")
            }
            HStack {
                Text("\(Int(minValue))")
                Slider(value: $value, in: minValue...maxValue)
                Text("\(Int(maxValue))")
            }.padding()
        }.border(Color.blue)
    }
}

struct DOFControllerView_Previews: PreviewProvider {
    @State static var value = 0.0
    static var previews: some View {
        DOFControllerView(label: "Example", value: $value, minValue: -90.0, maxValue: 90.0)
    }
}
