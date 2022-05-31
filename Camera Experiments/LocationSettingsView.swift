//
//  LocationSettingsView.swift
//  Camera Experiments
//
//  Created by Joshua Levine on 2/5/22.
//

import SwiftUI

struct LocationSettingsView: View {
    @ObservedObject var backgroundReplacer: BackgroundReplacer

    var body: some View {
        VStack {
            TextField("City, State", text: $backgroundReplacer.location, prompt: Text("City, State"))
        }
    }
}

struct LocationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LocationSettingsView(backgroundReplacer: BackgroundReplacer())
    }
}
