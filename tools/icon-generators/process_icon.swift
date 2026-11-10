import AppKit
import CoreGraphics

func processAndFitIcon(inputPath: String, outputPath: String) {
    guard let srcImage = NSImage(contentsOfFile: inputPath) else {
        print("Cannot load \(inputPath)")
        return
    }
    srcImage.size = NSSize(width: 1024, height: 1024)
    guard let cgImage = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("Cannot get CGImage")
        return
    }
    
    // Exact squircle crop
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
    
    // 1. Ambient Drop Shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -22), blur: 36, color: NSColor.black.withAlphaComponent(0.48).cgColor)
    NSColor.black.withAlphaComponent(0.2).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.withAlphaComponent(0.15).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    // 2. Draw cropped high-end render inside squircle
    cg.saveGState()
    squirclePath.addClip()
    
    cg.interpolationQuality = .high
    cg.draw(cropped, in: destRect)
    
    // 3. Subtle rim specular stroke on the squircle boundary for maximum crispness
    let rimPath = NSBezierPath(roundedRect: destRect.insetBy(dx: 1.5, dy: 1.5), xRadius: cornerRadius - 1.5, yRadius: cornerRadius - 1.5)
    rimPath.lineWidth = 3.0
    NSColor.white.withAlphaComponent(0.45).setStroke()
    rimPath.stroke()
    
    cg.restoreGState()
    
    NSGraphicsContext.restoreGraphicsState()
    
    if let pngData = rep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Generated high-end master icon (\(pngData.count) bytes) at \(outputPath)")
    }
}

let args = CommandLine.arguments
if args.count >= 3 {
    processAndFitIcon(inputPath: args[1], outputPath: args[2])
}
