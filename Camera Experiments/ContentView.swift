//
//  ContentView.swift
//  Camera Experiments
//
//  Created by Joshua Levine on 1/23/22.
//

import SwiftUI

struct ContentView: View {
    @StateObject var backgroundReplacer = BackgroundReplacer()
    
    @State var backgroundType: BackgroundType = .color
    
    enum BackgroundType: Int {
        case color
        case url
    }
    
    var background: some View {
        VStack {
            Toggle("Enable Background Replacement", isOn: backgroundReplacer.binding(\.isEnabled))
            
            if backgroundReplacer.isEnabled {
                Picker("", selection: $backgroundType) {
                    Text("Color").tag(BackgroundType.color)
                    Text("URL").tag(BackgroundType.url)
                }
                .pickerStyle(.segmented)
                switch backgroundType {
                case .color:
                    colors
                case .url:
                    VideoURLView(loadUrl: backgroundReplacer.setBackgroundUrl)
                }
            }
        }
        .onChange(of: backgroundType) { newValue in
            if newValue == .color {
                backgroundReplacer.setBackgroundUrl(nil)
            }
        }
    }
    
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
    }
    
    var camera: some View {
        VStack {
            Menu {
                ForEach(backgroundReplacer.devices, id: \.uniqueID) { device in
                    Button(device.localizedName) {
                        backgroundReplacer.selectedDeviceId = device.uniqueID
                    }
                }
            } label: {
                Text(backgroundReplacer.selectedDevice?.localizedName ?? "No device selected.")
            }
            
            HStack {
                Text("Zoom")
                Spacer()
                Text(backgroundReplacer.cameraScale.description)
            }
            Slider(value: backgroundReplacer.binding(\.cameraScale), in: 1...1.5)
                
            
            HStack {
                Text("X Offset")
                Spacer()
                Text(backgroundReplacer.cameraXTranslate.description)
            }
            Slider(value: backgroundReplacer.binding(\.cameraXTranslate), in: -1...1)
            
            HStack {
                Text("Y Offset")
                Spacer()
                Text(backgroundReplacer.cameraYTranslate.description)
            }
            Slider(value: backgroundReplacer.binding(\.cameraYTranslate), in: -1...1)
        }
    }
    
    var masking: some View {
        VStack {
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
    }
    
    var body: some View {
        HStack(alignment: .top) {
            if let image = backgroundReplacer.ciImage {
                MetalView(ciImage: image)
                    .frame(minWidth: 800)
            } else {
                Text("No Image")
            }
            
            VStack(alignment: .leading, spacing: 32) {
                SettingSection(title: "Camera") {
                    camera
                }
                
                SettingSection(title: "Location") {
                    LocationSettingsView(backgroundReplacer: backgroundReplacer)
                }
                
                SettingSection(title: "Background") {
                    background
                }
                
                SettingSection(title: "Mask") {
                    masking
                }
            }
            .frame(width: 250)
            .padding()
        }
        
    }
}

struct SettingSection<Content: View>: View {
    var title: LocalizedStringKey
    var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).bold()
            content().padding().background(.regularMaterial)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
