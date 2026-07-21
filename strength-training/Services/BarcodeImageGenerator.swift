//
//  BarcodeImageGenerator.swift
//  strength-training
//
//  Core Image barcode / QR generation for the gym pass sheet.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum BarcodeImageGenerator {
    static func image(
        from string: String,
        format: GymMembershipPreferences.Format,
        scale: CGFloat = 12
    ) -> UIImage? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }

        let filter: CIFilter
        switch format {
        case .code128:
            let f = CIFilter.code128BarcodeGenerator()
            f.message = data
            // Quiet space around bars for picky scanners
            f.quietSpace = 7
            filter = f
        case .qr:
            let f = CIFilter.qrCodeGenerator()
            f.message = data
            f.correctionLevel = "M"
            filter = f
        }

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
