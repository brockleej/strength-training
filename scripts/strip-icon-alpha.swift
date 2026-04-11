#!/usr/bin/env swift
/// Strips the alpha channel from PNG files by compositing onto a black background.
/// Icon Composer exports 16-bit RGBA PNGs, but App Store requires no alpha (ITMS-90717).
///
/// Usage:
///   swift scripts/strip-icon-alpha.swift path/to/icon.png [more pngs...]
///
/// Typical workflow after exporting from Icon Composer:
///   swift scripts/strip-icon-alpha.swift \
///     strength-training/Assets.xcassets/AppIcon.appiconset/Icon-iOS-Default.png \
///     strength-training/Assets.xcassets/AppIcon.appiconset/Icon-iOS-Dark.png \
///     strength-training/Assets.xcassets/AppIcon.appiconset/Icon-iOS-Tinted.png

import CoreGraphics
import Foundation
import ImageIO

guard CommandLine.arguments.count > 1 else {
    print("Usage: strip-icon-alpha.swift <png> [<png> ...]")
    exit(1)
}

for arg in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: arg)

    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        print("FAIL: could not load \(arg)")
        continue
    }

    let width = image.width
    let height = image.height

    // noneSkipLast = RGBX (8-bit RGB stored in 32-bit pixels, alpha byte ignored)
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue

    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
    ) else {
        print("FAIL: could not create context for \(arg)")
        continue
    }

    // Black background, then composite the original image on top
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let result = ctx.makeImage() else {
        print("FAIL: could not render \(arg)")
        continue
    }

    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        print("FAIL: could not create destination for \(arg)")
        continue
    }

    CGImageDestinationAddImage(dest, result, nil)
    if CGImageDestinationFinalize(dest) {
        print("  OK: \(arg)")
    } else {
        print("FAIL: could not write \(arg)")
    }
}
