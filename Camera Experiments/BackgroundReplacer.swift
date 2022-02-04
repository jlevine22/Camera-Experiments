//
//  BackgroundReplacer.swift
//  Camera Experiments
//
//  Created by Joshua Levine on 1/29/22.
//

import Foundation
import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation
import Combine

class BackgroundReplacer: NSObject, ObservableObject {
    private let requestHandler = VNSequenceRequestHandler()
    private var facePoseRequest: VNDetectFaceRectanglesRequest!
    private var segmentationRequest = VNGeneratePersonSegmentationRequest()
    
    public var session: AVCaptureSession?
    
    private lazy var serviceManager = XPCServiceManager()
    
    private lazy var context = CIContext()

    private var subscriptions = Set<AnyCancellable>()

    @Published var ciImage: CIImage?
    @Published var red: Double = 0.01
    @Published var green: Double = 0.01
    @Published var blue: Double = 0.01
    @Published var autoColors: Bool = false
    @Published var blurRadius: Double = 5.5
    @Published var threshold: Double = 0.25
    @Published var inverted: Bool = false
    
    @Published var devices: [AVCaptureDevice] = []
    @Published var selectedDeviceId: String? = nil {
        didSet {
            print(selectedDeviceId)
            session?.beginConfiguration()
            session?.inputs.forEach(session!.removeInput)
            guard let device = selectedDevice else {
                //fatalError("Error getting AVCaptureDevice.")
                return
            }
            print("setting up input with device \(device.localizedName)")
            guard let input = try? AVCaptureDeviceInput(device: device) else {
                fatalError("Error getting AVCaptureDeviceInput")
            }
            
            session?.addInput(input)
            session?.commitConfiguration()
        }
    }
    
    var selectedDevice: AVCaptureDevice? {
        guard let selectedDeviceId = selectedDeviceId else {
            return nil
        }
        return devices.first { $0.uniqueID == selectedDeviceId }
    }

    override init() {
        super.init()

        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest.qualityLevel = .balanced
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
        
        DispatchQueue.main.async { [weak self] in
            self?.setupCaptureSession()
            self?.updateDevices()
        }
    }
    
    deinit {
        session?.stopRunning()
    }
    
    func updateDevices() {
        let deviceTypes = [AVCaptureDevice.DeviceType.builtInWideAngleCamera, .externalUnknown]
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
        devices = discoverySession.devices
        devices.forEach {
            print($0.hashValue, $0.uniqueID)
        }
        if let selectedDeviceId = selectedDeviceId, devices.contains(where: { $0.uniqueID == selectedDeviceId }) == false {
            self.selectedDeviceId = nil
        }
        if selectedDevice == nil {
            selectedDeviceId = devices.first?.uniqueID
        }
    }
    
    func setupCaptureSession() {
        self.session = AVCaptureSession()
        self.session?.sessionPreset = .high
        
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: .main)
        
        self.session?.addOutput(output)
        output.connections.first?.videoOrientation = .portrait
        
        session?.startRunning()
    }
    
    private func processVideoFrame(_ framePixelBuffer: CVPixelBuffer) {
        try? requestHandler.perform([segmentationRequest],
                                    on: framePixelBuffer,
                                    orientation: .right)

        guard let maskPixelBuffer = segmentationRequest.results?.first?.pixelBuffer else { return }

        blend(original: framePixelBuffer, mask: maskPixelBuffer)
    }
    
    private func blend(original framePixelBuffer: CVPixelBuffer,
                       mask maskPixelBuffer: CVPixelBuffer) {

        let originalImage = CIImage(cvPixelBuffer: framePixelBuffer)
        

        // Scale the mask image to fit the bounds of the video frame.
        var maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        maskImage = maskImage.oriented(.left)
        let scaleX = originalImage.extent.width / maskImage.extent.width
        let scaleY = originalImage.extent.height / maskImage.extent.height
        maskImage = maskImage.transformed(by: .init(scaleX: scaleX, y: scaleY))
        
        // Create a colored background image.
        let vectors = [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: red),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: green),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: blue)
        ]
        
        if autoColors {
            serviceManager.service.getRGB(withReply: { rgb in
                DispatchQueue.main.async { [weak self] in
                    self?.red = Double(rgb[0])/255
                    self?.green = Double(rgb[1])/255
                    self?.blue = Double(rgb[2])/255
                }
            })
        }
        
        let backgroundImage = maskImage.applyingFilter("CIColorMatrix",
                                                       parameters: vectors)
        
        let maskFilters = FilterGroup()
        
        maskFilters.addFilter { [blurRadius] input in
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = input
            blur.radius = Float(blurRadius)
            return blur
        }
        
        maskFilters.addFilter { [threshold] input in
            let maskThreshold = CIFilter.colorThreshold()
            maskThreshold.threshold = Float(threshold)
            maskThreshold.inputImage = input
            return maskThreshold
        }
        
        maskFilters.addFilter { input in
            let median = CIFilter.median()
            median.inputImage = input
            return median
        }

        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = inverted ? backgroundImage : originalImage
        blendFilter.backgroundImage = inverted ? originalImage : backgroundImage
        blendFilter.maskImage = maskFilters.outputImage(startImage: maskImage)
        
        let blendedImage = blendFilter.outputImage
        
        guard let image = blendedImage else { return }
        
        var newPixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, 1920, 1080, kCVPixelFormatType_32ARGB, attributes, &newPixelBuffer)
        context.render(image, to: newPixelBuffer!)
        serviceManager.publishFrame(newPixelBuffer!)
        
        DispatchQueue.main.async { [weak self] in
            self?.ciImage = image
        }
    }
    
    func binding<T>(_ keyPath: ReferenceWritableKeyPath<BackgroundReplacer, T>) -> Binding<T> {
        Binding {
            self[keyPath: keyPath]
        } set: { newValue in
            self[keyPath: keyPath] = newValue
        }
    }
}

extension BackgroundReplacer: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Grab the pixelbuffer frame from the camera output
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        DispatchQueue.global().async { [weak self] in
            self?.processVideoFrame(pixelBuffer)
        }
    }
}
