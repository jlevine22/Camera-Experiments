//
//  ContentView.swift
//  Camera Experiments
//
//  Created by Joshua Levine on 1/23/22.
//

import SwiftUI

struct ContentView: View {
    @StateObject var backgroundReplacer = BackgroundReplacer()
    
    var colors: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Red")
                Spacer()
                Text(backgroundReplacer.red.description)
            }
            Slider(value: backgroundReplacer.binding(\.red), in: 0...1)
            
            HStack {
                Text("Green")
                Spacer()
                Text(backgroundReplacer.green.description)
            }
            Slider(value: backgroundReplacer.binding(\.green), in: 0...1)
            
            HStack {
                Text("Blue")
                Spacer()
                Text(backgroundReplacer.blue.description)
            }
            Slider(value: backgroundReplacer.binding(\.blue), in: 0...1)
            
            Toggle("Auto Colors", isOn: backgroundReplacer.binding(\.autoColors))
        }
        .padding([.top, .bottom])
    }
    
    var body: some View {
        HStack(alignment: .top) {
            ZStack(alignment: .center) {
                if let image = backgroundReplacer.ciImage {
                    MetalView(ciImage: image)
                } else {
                    Text("No Image")
                }
            }
            
            VStack(alignment: .leading) {
                colors
                
                HStack {
                    Text("Blur Radius")
                    Spacer()
                    Text(backgroundReplacer.blurRadius.description)
                }
                Slider(value: backgroundReplacer.binding(\.blurRadius), in: 0...50)
                
                HStack {
                    Text("Threshold")
                    Spacer()
                    Text(backgroundReplacer.threshold.description)
                }
                Slider(value: backgroundReplacer.binding(\.threshold), in: 0...1)
                
                Toggle("Inverted", isOn: backgroundReplacer.binding(\.inverted))
            }
            .frame(width: 200)
            .padding([.leading, .trailing])
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
