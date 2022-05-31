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
    
    private lazy var player = AVPlayer()
    lazy var videoDataOutput = AVPlayerItemVideoOutput(outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)])
    private var itemObserver: NSKeyValueObservation?
    
    private var item: AVPlayerItem? {
        didSet {
            backgroundPixelBuffer = nil
            itemObserver?.invalidate()
            player.replaceCurrentItem(with: item)
            player.currentItem?.add(videoDataOutput)
            guard item != nil else { return }
            itemObserver = player.currentItem?.observe(\.status, options: [.initial, .new]) { [player] item, _ in
                if item.status == .readyToPlay {
                    player.play()
                }
            }
        }
    }
    
    public var session: AVCaptureSession?
    
    private lazy var serviceManager = XPCServiceManager()
    
    private lazy var context = CIContext()

    private var subscriptions = Set<AnyCancellable>()

    private var backgroundPixelBuffer: CVPixelBuffer?
    
    @Published var location: String = "Sparks, NV"
    @Published var ciImage: CIImage?
    @Published var red: Double = 0.01
    @Published var green: Double = 0.01
    @Published var blue: Double = 0.01
    @Published var autoColors: Bool = false
    @Published var blurRadius: Double = 2.2
    @Published var threshold: Double = 0.42
    @Published var inverted: Bool = false
    @Published var isEnabled = true
    @Published var devices: [AVCaptureDevice] = []
    @Published var selectedDeviceId: String? = nil {
        didSet {
            session?.beginConfiguration()
            session?.inputs.forEach(session!.removeInput)
            guard let device = selectedDevice else {
                //fatalError("Error getting AVCaptureDevice.")
                return
            }
            guard let input = try? AVCaptureDeviceInput(device: device) else {
                fatalError("Error getting AVCaptureDeviceInput")
            }
            
            session?.addInput(input)
            session?.commitConfiguration()
        }
    }
    
    @Published var cameraScale: Double = 1
    @Published var cameraXTranslate: Double = 0
    @Published var cameraYTranslate: Double = 0
    
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
        itemObserver?.invalidate()
    }
    
    func setBackgroundUrl(_ url: URL?) {
        self.item = url == nil ? nil : AVPlayerItem(url: url!)
    }
    
    func updateDevices() {
        let deviceTypes = [AVCaptureDevice.DeviceType.builtInWideAngleCamera, .externalUnknown]
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
        devices = discoverySession.devices
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

        let originalFrame = CIImage(cvPixelBuffer: framePixelBuffer)

        let scaleTransform = CGAffineTransform(scaleX: cameraScale, y: cameraScale)
        var image = originalFrame.transformed(by: scaleTransform)
        let x = (image.extent.width - originalFrame.extent.width) / 2
        let y = (image.extent.height - originalFrame.extent.height) / 2
        let offsetX = x * (1 - cameraXTranslate)
        let offsetY = y * (1 - cameraYTranslate)
        let cropRect = CGRect(
            x: offsetX,
            y: offsetY,
            width: originalFrame.extent.width,
            height: originalFrame.extent.height
        )
        let cropped = image.cropped(to: cropRect)
        let translation = CGAffineTransform(translationX: -cropped.extent.origin.x, y: -cropped.extent.origin.y)
        image = cropped.transformed(by: translation)

        if isEnabled {
            var mask = CIImage(cvPixelBuffer: maskPixelBuffer).oriented(.left)
            let scaleX = originalFrame.extent.width / mask.extent.width
            let scaleY = originalFrame.extent.height / mask.extent.height
            mask = mask.transformed(by: .init(scaleX: scaleX, y: scaleY))
            
            // Apply the extra scaling
            mask = mask.transformed(by: scaleTransform).cropped(to: cropRect).transformed(by: translation)

            image = blend(original: image, mask: mask) ?? image
        }
        image = addLocationText(to: image)
        
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
    
    /// Replaces the background from the original framePixelBuffer using maskPixelBuffer as the mask
    /// 
    private func blend(original originalImage: CIImage,
                       mask: CIImage) -> CIImage? {


        // Scale the mask image to fit the bounds of the video frame.
        var maskImage = mask

        
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
        
        let backgroundImage = backgroundPixelBuffer == nil ?
                                maskImage.applyingFilter("CIColorMatrix", parameters: vectors) :
                                CIImage(cvPixelBuffer: backgroundPixelBuffer!)
        
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
        
        let processedMask = maskFilters.outputImage(startImage: maskImage.clampedToExtent())

        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = inverted ? backgroundImage : originalImage
        blendFilter.backgroundImage = inverted ? originalImage : backgroundImage
        blendFilter.maskImage = processedMask
        
        return blendFilter.outputImage
    }
    
    func addLocationText(to image: CIImage) -> CIImage {
        guard location.isEmpty == false else {
            return image
        }
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(image.extent.width), pixelsHigh: 60, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: .alphaFirst, bytesPerRow: 0, bitsPerPixel: 0)
        let context = NSGraphicsContext(bitmapImageRep: bitmap!)
        context?.cgContext.setFillColor(CGColor.black.copy(alpha: 0.5)!)
        context?.cgContext.fill(CGRect(x: 0, y: 0, width: image.extent.width, height: 60))
        
        let font = NSFont.systemFont(ofSize: 48)
        let string = NSAttributedString(string: location, attributes: [.font: font, .foregroundColor: CGColor.white])
        let path = CGPath(rect: CGRect(x: 24, y: 0, width: image.extent.width - 12, height: 60), transform: nil)
        let frameSetter = CTFramesetterCreateWithAttributedString(string as CFAttributedString)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: string.length), path, nil)
        CTFrameDraw(frame, context!.cgContext)
        
        let composite = CIFilter.sourceOverCompositing()
        composite.inputImage = CIImage(bitmapImageRep: bitmap!)
        composite.backgroundImage = image
        
        return composite.outputImage!
    }
}

extension BackgroundReplacer: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Grab the pixelbuffer frame from the camera output
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let currentTime = player.currentTime()
        let hasNewPixelBuffer = videoDataOutput.hasNewPixelBuffer(forItemTime: currentTime)
        if hasNewPixelBuffer, let pixelBuffer = videoDataOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) {
            self.backgroundPixelBuffer = pixelBuffer
        }
        DispatchQueue.global().async { [weak self] in
            self?.processVideoFrame(pixelBuffer)
        }
    }
}
