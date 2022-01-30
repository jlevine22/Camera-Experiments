//
//  FilterGroup.swift
//  Camera Experiments
//
//  Created by Joshua Levine on 1/29/22.
//

import Foundation
import CoreImage

class FilterGroup {
    typealias FilterCreator = (CIImage) -> CIFilter

    private var creators: [FilterCreator] = []
    
    func addFilter(transform: @escaping FilterCreator) {
        creators.append(transform)
    }
    
    func outputImage(startImage: CIImage) -> CIImage? {
        creators.reduce(startImage as CIImage?) { currentImage, creator in
            guard let image = currentImage else { return nil }
            return creator(image).outputImage
        }
    }
}
