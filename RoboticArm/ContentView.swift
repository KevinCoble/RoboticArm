//
//  ContentView.swift
//  RoboticArm
//
//  Created by Kevin Coble on 5/3/20.
//  Copyright © 2020 Kevin Coble. All rights reserved.
//

import SwiftUI

var viewData = ViewData()

struct ContentView: View {

    var body: some View {
        MainView()
        .environmentObject(viewData)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
