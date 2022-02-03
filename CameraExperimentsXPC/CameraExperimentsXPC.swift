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
        //NSLog("replied with frame \(currentFrame)")
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
    
    func getPublicIp(withReply reply: @escaping (String) -> Void) {
        let pmset = Process()
        let pipe = Pipe()
        if #available(OSX 13, *) {
            pmset.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        } else {
            pmset.launchPath = "/usr/bin/env"
        }
        
        pmset.arguments = ["dig", "+shor", "myip.opendns.com", "@resolver1.opendns.com"]
        pmset.standardOutput = pipe
        do {
            if #available(OSX 13, *){
                do {
                    try pmset.run()
                } catch {
                    reply("")
                }
            } else {
                pmset.launch()
            }
            pmset.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                reply(output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
}
