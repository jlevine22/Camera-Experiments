//
//  ServiceDelegate.swift
//  Camera Experiments
//
//  Created by Joshua Levine on 1/30/22.
//

import Foundation

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    let cameraExperimentsXPC = CameraExperimentsXPC()
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: CameraExperimentsXPCProtocol.self)
        newConnection.exportedObject = cameraExperimentsXPC
        newConnection.resume()
        return true
    }
}
