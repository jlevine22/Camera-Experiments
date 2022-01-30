//
//  MetalView.swift
//  Camera Experiments
//
//  Created by Joshua Levine on 1/29/22.
//

import Foundation
import AppKit
import Combine
import SwiftUI
import MetalKit
import AVFoundation
import CoreGraphics
import CoreImage

struct MetalView: NSViewRepresentable {
    var ciImage: CIImage
    
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.delegate = context.coordinator
        view.device = context.coordinator.device
        view.framebufferOnly = false
        return view
    }
    
    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.image = ciImage
        view.setNeedsDisplay(view.bounds)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

extension MetalView {
    class Coordinator: NSObject, MTKViewDelegate {
        private(set) var device: MTLDevice!
        private var context: CIContext!
        private var queue: MTLCommandQueue!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var image: CIImage?
        
        override init() {
            super.init()
            guard let device = MTLCreateSystemDefaultDevice() else { return }
            self.device = device
            self.queue = device.makeCommandQueue()
            self.context = CIContext(mtlDevice: device)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            
        }
        
        func draw(in view: MTKView) {
            guard let image = image else { return }
            let drawable = view.currentDrawable!
            let buffer = queue.makeCommandBuffer()!
            
            let widthScale = view.drawableSize.width / image.extent.width
            let heightScale = view.drawableSize.height / image.extent.height
            let scale = min(widthScale, heightScale)
            let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            
            let originX = max(view.drawableSize.width - scaledImage.extent.size.width, 0) / 2
            let originY = max(view.drawableSize.height - scaledImage.extent.size.height, 0) / 2
            let centeredImage = scaledImage.transformed(by: CGAffineTransform(translationX: originX, y: originY))
            
            let destination = CIRenderDestination(
                width: Int(view.drawableSize.width),
                height: Int(view.drawableSize.height),
                pixelFormat: view.colorPixelFormat,
                commandBuffer: nil) {
                    drawable.texture
                }
            
            let _ = try! self.context.startTask(toRender: centeredImage, to: destination)
            
            buffer.present(drawable)
            buffer.commit()
        }
    }
}
