//
//  XPCServiceManager.swift
//  Camera Experiments
//
//  Created by Joshua Levine on 1/30/22.
//

import Foundation
import CoreImage
import VideoToolbox

class XPCServiceManager: ObservableObject {
    let connection = NSXPCConnection(machServiceName: "com.joshlevine.CameraExperimentsXPC")
    
    let service: CameraExperimentsXPCProtocol
    
    var _pixelBufferPool: CVPixelBufferPool?
    var _transferSession: VTPixelTransferSession?
    
    init() {
        connection.remoteObjectInterface = NSXPCInterface(with: CameraExperimentsXPCProtocol.self)
        connection.resume()

        service = connection.remoteObjectProxyWithErrorHandler { error in
            print("error", error)
        } as! CameraExperimentsXPCProtocol
    }
    
    func publishFrame(_ frame: CVPixelBuffer) {
        let pixelType = CVPixelBufferGetPixelFormatType(frame)
        guard pixelType == kCVPixelFormatType_32ARGB else {
            print("Invalid pixelType")
            return
        }
        var surfaceRef = CVPixelBufferGetIOSurface(frame) //unsafeBitCast(, to: IOSurface.self)
        if surfaceRef == nil {
            if _pixelBufferPool == nil {
                createPixelBufferPool()
            }
            if _transferSession == nil {
                VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &self._transferSession)
            }
            var output: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _pixelBufferPool!, &output)
            VTPixelTransferSessionTransferImage(_transferSession!, from: frame, to: output!)
            surfaceRef = CVPixelBufferGetIOSurface(output)
        }
        if let surfaceRef = surfaceRef {
            service.setFrame(unsafeBitCast(surfaceRef, to: IOSurface.self))
        }
    }
    
    private func createPixelBufferPool() {
        let attributes: [CFString: Any] = [
            kCVPixelBufferWidthKey: 1280,
            kCVPixelBufferHeightKey: 720,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA
        ]
        CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &self._pixelBufferPool)
    }
    
    
}
