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
    var xpc: CameraExperimentsXPCProtocol {
        serviceManager.service
    }
    
    private lazy var context = CIContext()

    private var subscriptions = Set<AnyCancellable>()
    
    @Published var pixelBuffer: CVPixelBuffer?
    @Published var ciImage: CIImage?
    @Published var red: Double = 0.01
    @Published var green: Double = 0.01
    @Published var blue: Double = 0.01
    @Published var blurRadius: Double = 4
    @Published var threshold: Double = 0.5
    @Published var inverted: Bool = false

    override init() {
        super.init()

        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest.qualityLevel = .balanced
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
        
        setupCaptureSession()
    }
    
    deinit {
        session?.stopRunning()
    }
    
    func setupCaptureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            fatalError("Error getting AVCaptureDevice.")
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            fatalError("Error getting AVCaptureDeviceInput")
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.session = AVCaptureSession()
            self.session?.sessionPreset = .high
            self.session?.addInput(input)
            
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: .main)
            
            self.session?.addOutput(output)
            output.connections.first?.videoOrientation = .portrait
            self.session?.startRunning()
        }
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
        
        serviceManager.service.getRGB(withReply: { rgb in
            DispatchQueue.main.async { [weak self] in
                self?.red = Double(rgb[0])/255
                self?.green = Double(rgb[1])/255
                self?.blue = Double(rgb[2])/255
            }
        })
        
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
