import AppKit
import CoreGraphics
import Foundation

func makeArtisanIcon(outputPath: String) {
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
    
    let cs = CGColorSpaceCreateDeviceRGB()
    
    // 1. Standard Apple HIG Squircle (824x824 at (100, 100), radius 185)
    let squircleRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: 185, yRadius: 185)
    
    // Ambient Soft Shadow under Squircle
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -24), blur: 40, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    NSColor.black.withAlphaComponent(0.08).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    // Clip inside Squircle
    cg.saveGState()
    squirclePath.addClip()
    
    // Base Surface: Luxurious Deep Obsidian Titanium Gradient (#0B0F19 -> #171E2E -> #232D42)
    let baseColors = [
        NSColor(red: 0.04, green: 0.06, blue: 0.11, alpha: 1.0).cgColor,
        NSColor(red: 0.09, green: 0.12, blue: 0.19, alpha: 1.0).cgColor,
        NSColor(red: 0.14, green: 0.18, blue: 0.28, alpha: 1.0).cgColor
    ] as CFArray
    if let baseGrad = CGGradient(colorsSpace: cs, colors: baseColors, locations: [0.0, 0.5, 1.0]) {
        cg.drawLinearGradient(baseGrad, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
    }
    
    // Deep Subsurface Backlight (Electric Violet & Cyan ambient flares)
    if let cyanGlow = CGGradient(
        colorsSpace: cs,
        colors: [NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.22).cgColor, NSColor.clear.cgColor] as CFArray,
        locations: [0.0, 1.0]
    ) {
        cg.drawRadialGradient(cyanGlow, startCenter: CGPoint(x: 340, y: 640), startRadius: 0, endCenter: CGPoint(x: 340, y: 640), endRadius: 360, options: [])
    }
    
    if let violetGlow = CGGradient(
        colorsSpace: cs,
        colors: [NSColor(red: 0.55, green: 0.20, blue: 1.0, alpha: 0.25).cgColor, NSColor.clear.cgColor] as CFArray,
        locations: [0.0, 1.0]
    ) {
        cg.drawRadialGradient(violetGlow, startCenter: CGPoint(x: 680, y: 380), startRadius: 0, endCenter: CGPoint(x: 680, y: 380), endRadius: 380, options: [])
    }
    
    // Precision Rim Highlight (Top & Left Bevel)
    let innerRim = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
    innerRim.lineWidth = 3.5
    NSColor.white.withAlphaComponent(0.25).setStroke()
    innerRim.stroke()
    
    cg.restoreGState() // end squircle clip
    
    // 2. The Hero Icon Element: The Infinite Route Aperture
    // Two dynamic interwoven torus ribbon arcs in vibrant cyan and magenta-purple
    let cx: CGFloat = 512
    let cy: CGFloat = 512
    
    // Arc 1: Cyan Ribbon (Upper Left to Lower Center)
    let cyanPath = NSBezierPath()
    cyanPath.move(to: CGPoint(x: cx - 180, y: cy + 130))
    cyanPath.curve(
        to: CGPoint(x: cx + 140, y: cy + 180),
        controlPoint1: CGPoint(x: cx - 180, y: cy + 280),
        controlPoint2: CGPoint(x: cx + 40, y: cy + 290)
    )
    cyanPath.curve(
        to: CGPoint(x: cx + 180, y: cy - 30),
        controlPoint1: CGPoint(x: cx + 220, y: cy + 100),
        controlPoint2: CGPoint(x: cx + 230, y: cy + 30)
    )
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.6).cgColor)
    cyanPath.lineWidth = 56
    cyanPath.lineCapStyle = .round
    NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.95).setStroke()
    cyanPath.stroke()
    cg.restoreGState()
    
    // Arc 2: Violet/Magenta Ribbon (Lower Right to Upper Center)
    let violetPath = NSBezierPath()
    violetPath.move(to: CGPoint(x: cx + 180, y: cy - 130))
    violetPath.curve(
        to: CGPoint(x: cx - 140, y: cy - 180),
        controlPoint1: CGPoint(x: cx + 180, y: cy - 280),
        controlPoint2: CGPoint(x: cx - 40, y: cy - 290)
    )
    violetPath.curve(
        to: CGPoint(x: cx - 180, y: cy + 30),
        controlPoint1: CGPoint(x: cx - 220, y: cy - 100),
        controlPoint2: CGPoint(x: cx - 230, y: cy - 30)
    )
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 0.6).cgColor)
    violetPath.lineWidth = 56
    violetPath.lineCapStyle = .round
    NSColor(red: 0.68, green: 0.25, blue: 1.0, alpha: 0.95).setStroke()
    violetPath.stroke()
    cg.restoreGState()
    
    // Core Floating Frosted Glass Card in Center
    let cardW: CGFloat = 260
    let cardH: CGFloat = 330
    let cardRect = NSRect(x: cx - cardW / 2, y: cy - cardH / 2, width: cardW, height: cardH)
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 36, yRadius: 36)
    
    // Card Shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -16), blur: 36, color: NSColor.black.withAlphaComponent(0.55).cgColor)
    NSColor(white: 0.12, alpha: 0.92).setFill()
    cardPath.fill()
    cg.restoreGState()
    
    // Card Frosted Inner Border
    cardPath.lineWidth = 3.0
    NSColor.white.withAlphaComponent(0.35).setStroke()
    cardPath.stroke()
    
    // Card Floating Emblem: Minimalist Precision Arrow-Aperture Node
    if let sfImg = NSImage(systemSymbolName: "arrow.triangle.swap", accessibilityDescription: nil) ??
       NSImage(systemSymbolName: "arrow.2.squarepath", accessibilityDescription: nil) {
        let conf = NSImage.SymbolConfiguration(pointSize: 100, weight: .bold)
        if let icon = sfImg.withSymbolConfiguration(conf) {
            let symbolRect = NSRect(x: cx - 55, y: cy - 55, width: 110, height: 110)
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 16, color: NSColor.white.withAlphaComponent(0.7).cgColor)
            NSColor.white.setFill()
            icon.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            cg.restoreGState()
        }
    }
    
    // Top Micro Diamond Sparkle
    let sparkPath = NSBezierPath()
    let sx = cardRect.maxX - 38
    let sy = cardRect.maxY - 38
    sparkPath.move(to: CGPoint(x: sx, y: sy + 14))
    sparkPath.line(to: CGPoint(x: sx + 14, y: sy))
    sparkPath.line(to: CGPoint(x: sx, y: sy - 14))
    sparkPath.line(to: CGPoint(x: sx - 14, y: sy))
    sparkPath.close()
    
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: 10, color: NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.9).cgColor)
    NSColor(red: 0.4, green: 0.95, blue: 1.0, alpha: 1.0).setFill()
    sparkPath.fill()
    cg.restoreGState()
    
    NSGraphicsContext.restoreGraphicsState()
    
    if let pngData = rep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Artisan icon rendered at \(outputPath)")
    }
}

makeArtisanIcon(outputPath: "/tmp/artisan_icon_1024.png")
