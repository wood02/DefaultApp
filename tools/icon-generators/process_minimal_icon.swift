import AppKit
import CoreGraphics

func processMinimalLightIcon(inputPath: String, outputPath: String) {
    guard let srcImage = NSImage(contentsOfFile: inputPath) else {
        print("Cannot load \(inputPath)")
        return
    }
    srcImage.size = NSSize(width: 1024, height: 1024)
    guard let cgImage = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("Cannot get CGImage")
        return
    }
    
    // Crop squircle region
    let cropRect = CGRect(x: 160, y: 160, width: 704, height: 704)
    guard let cropped = cgImage.cropping(to: cropRect) else {
        print("Cannot crop CGImage")
        return
    }
    
    let targetSize: CGFloat = 1024
    let squircleSize: CGFloat = 824
    let inset: CGFloat = (targetSize - squircleSize) / 2 // 100
    let cornerRadius: CGFloat = 185
    
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(targetSize),
        pixelsHigh: Int(targetSize),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return }
    
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.clear(CGRect(x: 0, y: 0, width: targetSize, height: targetSize))
    
    let destRect = CGRect(x: inset, y: inset, width: squircleSize, height: squircleSize)
    let squirclePath = NSBezierPath(roundedRect: destRect, xRadius: cornerRadius, yRadius: cornerRadius)
    
    // 1. Soft, natural macOS contact shadow for light icons
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -18), blur: 34, color: NSColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 0.18).cgColor)
    NSColor(white: 0.95, alpha: 0.25).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 0.10).cgColor)
    NSColor(white: 0.95, alpha: 0.25).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    // 2. Draw cropped high-end render inside squircle
    cg.saveGState()
    squirclePath.addClip()
    
    cg.interpolationQuality = .high
    cg.draw(cropped, in: destRect)
    
    // 3. Apple HIG light-icon rim border (gives subtle definition on light desktop wallpapers)
    let rimPath = NSBezierPath(roundedRect: destRect.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius - 0.5, yRadius: cornerRadius - 0.5)
    rimPath.lineWidth = 1.0
    NSColor(white: 0.85, alpha: 0.6).setStroke()
    rimPath.stroke()
    
    cg.restoreGState()
    
    NSGraphicsContext.restoreGraphicsState()
    
    if let pngData = rep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Generated light master icon (\(pngData.count) bytes) at \(outputPath)")
    }
}

let args = CommandLine.arguments
if args.count >= 3 {
    processMinimalLightIcon(inputPath: args[1], outputPath: args[2])
}
