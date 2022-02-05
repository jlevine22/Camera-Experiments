//
//  VideoURLView.swift
//  Camera Experiments
//
//  Created by Joshua Levine on 2/4/22.
//

import SwiftUI

struct VideoURLView: View {
    var loadUrl: (URL) -> Void
    
    @State var input: String = ""
    
    var isValidUrl: Bool {
        URL(string: input) != nil
    }
    
    var body: some View {
        VStack {
            HStack {
                TextField("URL", text: $input).textFieldStyle(.roundedBorder)
                Button("Load") {
                    loadUrl(URL(string: input)!)
                }
                .disabled(!isValidUrl)
            }
            Button("Mt Rose - Northwest Chair") {
                input = "https://5f9f690034fb0.streamlock.net:444/mtrose1/mtrose1.stream/playlist.m3u8"
            }
            Button("Mt Rose - North View") {
                input = "https://5b8462eb3469a.streamlock.net:444/mtrosesummit/mtrosesummit.stream/playlist.m3u8"
            }
        }
    }
}

struct VideoURLView_Previews: PreviewProvider {
    static var previews: some View {
        VideoURLView { _ in }
    }
}
