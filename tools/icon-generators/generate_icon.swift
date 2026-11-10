import AppKit
import CoreGraphics

func makeIcon(from sourceImagePath: String? = nil, outputPath: String) {
    let size = 1024
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("Failed to create bitmap")
        return
    }
    
    let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    
    let cgContext = context!.cgContext
    cgContext.clear(rect)
    
    if let srcPath = sourceImagePath, let srcImage = NSImage(contentsOfFile: srcPath) {
        // Draw the provided image scaled nicely
        srcImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    } else {
        // Native CoreGraphics rendering of modern macOS squircle icon
        let squircleInset: CGFloat = 100
        let squircleRect = rect.insetBy(dx: squircleInset, dy: squircleInset)
        let cornerRadius: CGFloat = 185
        let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        // 1. Ambient Drop Shadow
        cgContext.saveGState()
        cgContext.setShadow(offset: CGSize(width: 0, height: -24), blur: 36, color: NSColor.black.withAlphaComponent(0.35).cgColor)
        NSColor.black.withAlphaComponent(0.1).setFill()
        squirclePath.fill()
        cgContext.restoreGState()
        
        // 2. Base Gradient (Deep Cobalt Blue to Cyan)
        cgContext.saveGState()
        squirclePath.addClip()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradientColors = [
            NSColor(red: 0.10, green: 0.15, blue: 0.35, alpha: 1.0).cgColor,
            NSColor(red: 0.12, green: 0.38, blue: 0.88, alpha: 1.0).cgColor,
            NSColor(red: 0.05, green: 0.70, blue: 0.90, alpha: 1.0).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.55, 1.0]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations) {
            cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: squircleRect.minX, y: squircleRect.maxY),
                end: CGPoint(x: squircleRect.maxX, y: squircleRect.minY),
                options: []
            )
        }
        
        // Subtle top lighting highlight
        let highlightPath = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 2, dy: 2), xRadius: cornerRadius - 2, yRadius: cornerRadius - 2)
        highlightPath.lineWidth = 3.0
        NSColor.white.withAlphaComponent(0.3).setStroke()
        highlightPath.stroke()
        
        cgContext.restoreGState()
        
        // 3. Central Motif: Document with Swap/Routing Arrows
        let centerX = rect.midX
        let centerY = rect.midY
        
        // Document base
        let docWidth: CGFloat = 340
        let docHeight: CGFloat = 440
        let docRect = NSRect(x: centerX - docWidth / 2 - 20, y: centerY - docHeight / 2 + 10, width: docWidth, height: docHeight)
        let docPath = NSBezierPath(roundedRect: docRect, xRadius: 28, yRadius: 28)
        
        cgContext.saveGState()
        cgContext.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        NSColor.white.withAlphaComponent(0.92).setFill()
        docPath.fill()
        cgContext.restoreGState()
        
        // Document lines (abstract text)
        let lineStartX = docRect.minX + 44
        let lineEndX = docRect.maxX - 44
        let lineColors = [NSColor(white: 0.82, alpha: 1.0), NSColor(white: 0.88, alpha: 1.0), NSColor(white: 0.88, alpha: 1.0)]
        for (i, yOff) in [docRect.maxY - 90, docRect.maxY - 135, docRect.maxY - 180].enumerated() {
            let p = NSBezierPath()
            p.move(to: CGPoint(x: lineStartX, y: yOff))
            p.line(to: CGPoint(x: i == 2 ? lineStartX + 120 : lineEndX, y: yOff))
            p.lineWidth = 14
            p.lineCapStyle = .round
            lineColors[i].setStroke()
            p.stroke()
        }
        
        // Dynamic circular badge on bottom right
        let badgeSize: CGFloat = 260
        let badgeRect = NSRect(x: centerX + 10, y: centerY - 180, width: badgeSize, height: badgeSize)
        let badgePath = NSBezierPath(ovalIn: badgeRect)
        
        cgContext.saveGState()
        cgContext.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: NSColor.black.withAlphaComponent(0.35).cgColor)
        NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).setFill()
        badgePath.fill()
        
        let badgeBorder = NSBezierPath(ovalIn: badgeRect.insetBy(dx: 3, dy: 3))
        badgeBorder.lineWidth = 6
        NSColor.white.withAlphaComponent(0.4).setStroke()
        badgeBorder.stroke()
        cgContext.restoreGState()
        
        // Swap arrows inside badge
        if let arrowImage = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 130, weight: .bold)
            if let configured = arrowImage.withSymbolConfiguration(config) {
                let arrowRect = NSRect(x: badgeRect.midX - 70, y: badgeRect.midY - 70, width: 140, height: 140)
                configured.draw(in: arrowRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }
        }
    }
    
    NSGraphicsContext.restoreGraphicsState()
    
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to convert to PNG")
        return
    }
    
    let url = URL(fileURLWithPath: outputPath)
    try? pngData.write(to: url)
    print("Generated base 1024 PNG at \(outputPath)")
}

let args = CommandLine.arguments
let src = args.count > 2 ? args[1] : nil
let dest = args.count > 2 ? args[2] : (args.count > 1 ? args[1] : "/tmp/app_icon_1024.png")
makeIcon(from: src, outputPath: dest)
