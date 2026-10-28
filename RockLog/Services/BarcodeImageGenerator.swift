//
//  BarcodeImageGenerator.swift
//  RockLog
//
//  Core Image for Code 128, QR, PDF417, and Aztec.
//  Code 39 and EAN-13 are drawn from BarcodeModules. A nil image means
//  the pass still shows the number as text.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum BarcodeImageGenerator {
    static func image(
        from string: String,
        symbology: BarcodeSymbology,
        scale: CGFloat = 8
    ) -> UIImage? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if symbology.usesCoreImage {
            return coreImage(trimmed, symbology: symbology, scale: scale)
        }
        let modules: String?
        switch symbology {
        case .code39: modules = BarcodeModules.code39(trimmed)
        case .ean13: modules = BarcodeModules.ean13(trimmed)
        default: modules = nil
        }
        guard let modules else { return nil }
        return draw(modules, scale: scale)
    }

    private static func coreImage(_ string: String, symbology: BarcodeSymbology, scale: CGFloat) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter: CIFilter
        switch symbology {
        case .code128:
            let generator = CIFilter.code128BarcodeGenerator()
            generator.message = data
            generator.quietSpace = 7
            filter = generator
        case .qr:
            let generator = CIFilter.qrCodeGenerator()
            generator.message = data
            generator.correctionLevel = "M"
            filter = generator
        case .pdf417:
            let generator = CIFilter.pdf417BarcodeGenerator()
            generator.message = data
            filter = generator
        case .aztec:
            let generator = CIFilter.aztecCodeGenerator()
            generator.message = data
            filter = generator
        case .code39, .ean13:
            return nil
        }
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func draw(_ modules: String, scale: CGFloat) -> UIImage? {
        let width = CGFloat(modules.count) * scale
        let height = 80 * scale / 8
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.black.setFill()
            for (index, bit) in modules.enumerated() where bit == "1" {
                context.fill(CGRect(x: CGFloat(index) * scale, y: 0, width: scale, height: height))
            }
        }
    }
}
