import AppKit
import CoreGraphics

func makePremiumIcon(outputPath: String) {
    let size: CGFloat = 1024
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
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
    cg.clear(rect)
    
    // 1. Standard Apple HIG macOS Squircle (inset 100, size 824x824, radius 185)
    let squircleRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: 185, yRadius: 185)
    
    // Ambient Drop Shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -22), blur: 38, color: NSColor.black.withAlphaComponent(0.38).cgColor)
    NSColor.black.withAlphaComponent(0.08).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    // Clip to Squircle
    cg.saveGState()
    squirclePath.addClip()
    
    // Background Rich Gradient (Deep Indigo -> Electric Blue -> Cyber Cyan)
    let cs = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(red: 0.08, green: 0.10, blue: 0.28, alpha: 1.0).cgColor,
        NSColor(red: 0.12, green: 0.32, blue: 0.85, alpha: 1.0).cgColor,
        NSColor(red: 0.02, green: 0.65, blue: 0.92, alpha: 1.0).cgColor
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.6, 1.0]
    if let bgGradient = CGGradient(colorsSpace: cs, colors: bgColors, locations: bgLocations) {
        cg.drawLinearGradient(bgGradient, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
    }
    
    // Subtle Radial Glow in Center
    if let radialGlow = CGGradient(
        colorsSpace: cs,
        colors: [NSColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.35).cgColor, NSColor.clear.cgColor] as CFArray,
        locations: [0.0, 1.0]
    ) {
        cg.drawRadialGradient(radialGlow, startCenter: CGPoint(x: 512, y: 550), startRadius: 0, endCenter: CGPoint(x: 512, y: 550), endRadius: 400, options: [])
    }
    
    // Top Inner Highlight / Bevel Rim
    let innerBorder = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 2.5, dy: 2.5), xRadius: 183, yRadius: 183)
    innerBorder.lineWidth = 4.0
    NSColor.white.withAlphaComponent(0.35).setStroke()
    innerBorder.stroke()
    
    cg.restoreGState() // end squircle clip
    
    // 2. Central 3D Frosted Document Card
    let docW: CGFloat = 380
    let docH: CGFloat = 480
    let docX: CGFloat = 512 - docW / 2 - 25
    let docY: CGFloat = 512 - docH / 2 + 35
    let docRect = NSRect(x: docX, y: docY, width: docW, height: docH)
    
    // Document with folded top-right corner
    let foldSize: CGFloat = 90
    let docPath = NSBezierPath()
    let r: CGFloat = 32
    
    // Bottom-left
    docPath.move(to: CGPoint(x: docRect.minX + r, y: docRect.minY))
    docPath.appendArc(from: CGPoint(x: docRect.minX, y: docRect.minY), to: CGPoint(x: docRect.minX, y: docRect.minY + r), radius: r)
    // Top-left
    docPath.line(to: CGPoint(x: docRect.minX, y: docRect.maxY - r))
    docPath.appendArc(from: CGPoint(x: docRect.minX, y: docRect.maxY), to: CGPoint(x: docRect.minX + r, y: docRect.maxY), radius: r)
    // Top to fold start
    docPath.line(to: CGPoint(x: docRect.maxX - foldSize, y: docRect.maxY))
    // Fold edge down
    docPath.line(to: CGPoint(x: docRect.maxX, y: docRect.maxY - foldSize))
    // Right side to bottom-right
    docPath.line(to: CGPoint(x: docRect.maxX, y: docRect.minY + r))
    docPath.appendArc(from: CGPoint(x: docRect.maxX, y: docRect.minY), to: CGPoint(x: docRect.maxX - r, y: docRect.minY), radius: r)
    docPath.close()
    
    // Document Shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -18), blur: 32, color: NSColor.black.withAlphaComponent(0.42).cgColor)
    NSColor(white: 0.98, alpha: 0.96).setFill()
    docPath.fill()
    cg.restoreGState()
    
    // Document Stroke
    docPath.lineWidth = 2.5
    NSColor.white.withAlphaComponent(0.85).setStroke()
    docPath.stroke()
    
    // Fold Corner Geometry
    let foldPath = NSBezierPath()
    foldPath.move(to: CGPoint(x: docRect.maxX - foldSize, y: docRect.maxY))
    foldPath.line(to: CGPoint(x: docRect.maxX - foldSize, y: docRect.maxY - foldSize + 12))
    foldPath.appendArc(
        from: CGPoint(x: docRect.maxX - foldSize, y: docRect.maxY - foldSize),
        to: CGPoint(x: docRect.maxX - foldSize + 12, y: docRect.maxY - foldSize),
        radius: 12
    )
    foldPath.line(to: CGPoint(x: docRect.maxX, y: docRect.maxY - foldSize))
    foldPath.close()
    
    // Fold shadow & color
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: -6, height: -6), blur: 12, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    NSColor(red: 0.88, green: 0.92, blue: 0.98, alpha: 1.0).setFill()
    foldPath.fill()
    cg.restoreGState()
    
    // Abstract colorful app association pills on document
    let pillStartX = docRect.minX + 48
    let pillW = docW - 120
    let pillColors = [
        NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.85),
        NSColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 0.85),
        NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 0.85)
    ]
    let pillWidths: [CGFloat] = [pillW, pillW * 0.75, pillW * 0.5]
    
    for (i, y) in [docRect.maxY - 140, docRect.maxY - 195, docRect.maxY - 250].enumerated() {
        let p = NSBezierPath(roundedRect: NSRect(x: pillStartX, y: y, width: pillWidths[i], height: 22), xRadius: 11, yRadius: 11)
        pillColors[i].setFill()
        p.fill()
    }
    
    // 3. Floating Modern Exchange/Routing Badge
    let badgeSize: CGFloat = 300
    let badgeX: CGFloat = 512 + 25
    let badgeY: CGFloat = 512 - 270
    let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeSize, height: badgeSize)
    let badgePath = NSBezierPath(ovalIn: badgeRect)
    
    // Badge Shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    
    // Badge Gradient (Vivid Cyan to Royal Blue)
    let badgeColors = [
        NSColor(red: 0.05, green: 0.78, blue: 0.98, alpha: 1.0).cgColor,
        NSColor(red: 0.08, green: 0.40, blue: 0.96, alpha: 1.0).cgColor
    ] as CFArray
    if let badgeGrad = CGGradient(colorsSpace: cs, colors: badgeColors, locations: [0.0, 1.0]) {
        cg.saveGState()
        badgePath.addClip()
        cg.drawLinearGradient(badgeGrad, start: CGPoint(x: badgeX, y: badgeY + badgeSize), end: CGPoint(x: badgeX + badgeSize, y: badgeY), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    
    // Badge Inner Glass Rim
    let badgeStroke = NSBezierPath(ovalIn: badgeRect.insetBy(dx: 3, dy: 3))
    badgeStroke.lineWidth = 5
    NSColor.white.withAlphaComponent(0.55).setStroke()
    badgeStroke.stroke()
    
    // Glowing SF Symbol Exchange Arrows in Badge Center
    if let sfImg = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: 155, weight: .bold)
        if let configured = sfImg.withSymbolConfiguration(config) {
            let symbolRect = NSRect(x: badgeRect.midX - 85, y: badgeRect.midY - 85, width: 170, height: 170)
            
            // Subtle glow
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 16, color: NSColor.white.withAlphaComponent(0.7).cgColor)
            NSColor.white.setFill()
            configured.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            cg.restoreGState()
        }
    }
    
    NSGraphicsContext.restoreGraphicsState()
    
    if let pngData = rep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Premium 1024x1024 icon saved to \(outputPath)")
    }
}

makePremiumIcon(outputPath: "/tmp/premium_icon_1024.png")
