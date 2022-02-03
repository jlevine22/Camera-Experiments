//
//  CameraExperimentsXPCProtocol.swift
//  Camera Experiments
//
//  Created by Joshua Levine on 1/30/22.
//

import Foundation
import CoreImage

@objc(CameraExperimentsXPCProtocol) protocol CameraExperimentsXPCProtocol {
    func getRGB(withReply reply: @escaping ([Int]) -> Void)
    func setFrame(_ surface: IOSurface)
    func getFrame(withReply reply: @escaping(IOSurface?) -> Void)
}

@objc(CameraExperimentsFrameReceiverProtocol) protocol CameraExperimentsFrameReceiverProtocol {
    func receiveFrame(_ surface: IOSurface)
}
