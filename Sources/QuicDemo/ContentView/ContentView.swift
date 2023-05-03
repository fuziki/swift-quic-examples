//
//  ContentView.swift
//  
//
//  Created by fuziki on 2023/05/02.
//

import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        List {
            ConnectionView()
            DatagramView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
