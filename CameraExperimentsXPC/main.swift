//
//  main.swift
//  CameraExperimentsXPC
//
//  Created by Joshua Levine on 1/30/22.
//

import Foundation

let delegate = ServiceDelegate()
let listener = NSXPCListener(machServiceName: "com.joshlevine.CameraExperimentsXPC")
listener.delegate = delegate;
listener.resume()
RunLoop.main.run()
