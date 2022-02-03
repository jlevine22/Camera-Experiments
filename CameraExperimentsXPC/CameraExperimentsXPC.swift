//
//  CameraExperimentsXPC.swift
//  Camera Experiments
//
//  Created by Joshua Levine on 1/30/22.
//

import Foundation
import CoreImage

@objc class CameraExperimentsXPC: NSObject, CameraExperimentsXPCProtocol { 
    var red = 25
    var green = 25
    var blue = 25
    
    var currentFrame: IOSurface?

    func getFrame(withReply reply: @escaping(IOSurface?) -> Void) {
        reply(currentFrame)
    }
    
    func setFrame(_ frame: IOSurface) {
        self.currentFrame = frame
    }
    
    func getRGB(withReply reply: @escaping([Int]) -> Void) {
        red += Int.random(in: -2...2)
        green += Int.random(in: -2...2)
        blue += Int.random(in: -2...2)
        reply([red, green, blue])
    }
}
