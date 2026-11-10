import AppKit
import CoreGraphics

func makeMinimalLightIcon(outputPath: String) {
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
    
    // 1. Apple Standard Squircle (824x824 at (100, 100), radius 185)
    let squircleRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: 185, yRadius: 185)
    
    // Ambient Soft Contact Shadow (natural, soft, not heavy)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 0.18).cgColor)
    NSColor(white: 0.95, alpha: 0.2).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 0.10).cgColor)
    NSColor(white: 0.95, alpha: 0.2).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    // Clip inside Squircle
    cg.saveGState()
    squirclePath.addClip()
    
    // Base: Pristine Alpine Porcelain White with faint subtle gradient (#FFFFFF to #F1F5F9)
    let bgColors = [
        NSColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0).cgColor
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(bgGrad, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
    }
    
    // Very subtle pastel soft aura in top-left (Sky Blue tint) & bottom-right (Lilac tint)
    if let aura1 = CGGradient(
        colorsSpace: cs,
        colors: [NSColor(red: 0.2, green: 0.65, blue: 1.0, alpha: 0.08).cgColor, NSColor.clear.cgColor] as CFArray,
        locations: [0.0, 1.0]
    ) {
        cg.drawRadialGradient(aura1, startCenter: CGPoint(x: 260, y: 760), startRadius: 0, endCenter: CGPoint(x: 260, y: 760), endRadius: 360, options: [])
    }
    
    if let aura2 = CGGradient(
        colorsSpace: cs,
        colors: [NSColor(red: 0.45, green: 0.40, blue: 0.95, alpha: 0.06).cgColor, NSColor.clear.cgColor] as CFArray,
        locations: [0.0, 1.0]
    ) {
        cg.drawRadialGradient(aura2, startCenter: CGPoint(x: 760, y: 260), startRadius: 0, endCenter: CGPoint(x: 760, y: 260), endRadius: 360, options: [])
    }
    
    // Delicate Inner Border
    let innerBorder = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 1.5, dy: 1.5), xRadius: 183.5, yRadius: 183.5)
    innerBorder.lineWidth = 2.0
    NSColor(white: 1.0, alpha: 0.9).setStroke()
    innerBorder.stroke()
    
    let outerStroke = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 184.5, yRadius: 184.5)
    outerStroke.lineWidth = 1.0
    NSColor(white: 0.82, alpha: 0.5).setStroke()
    outerStroke.stroke()
    
    cg.restoreGState() // end squircle clip
    
    // 2. Central Minimalist Motif: "The Elegant Link / Default Switch"
    // Clean, modern, peaceful geometry:
    // A pure white floating pill card + two interlinked, fluid routing rings
    let cx: CGFloat = 512
    let cy: CGFloat = 512
    
    // Central Floating Capsule Tray (Subtle tactile depth, like Things 3 / Apple Mail)
    let trayW: CGFloat = 520
    let trayH: CGFloat = 360
    let trayRect = NSRect(x: cx - trayW / 2, y: cy - trayH / 2, width: trayW, height: trayH)
    let trayPath = NSBezierPath(roundedRect: trayRect, xRadius: 56, yRadius: 56)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 0.12).cgColor)
    NSColor.white.setFill()
    trayPath.fill()
    cg.restoreGState()
    
    // Tray subtle border
    trayPath.lineWidth = 1.5
    NSColor(white: 0.88, alpha: 0.7).setStroke()
    trayPath.stroke()
    
    // Inside the tray: Two smooth interlinked capsules representing "File" and "Default App"
    // Left capsule: File Indicator (Soft Cerulean / Sky Blue)
    let capW: CGFloat = 170
    let capH: CGFloat = 170
    let leftCapRect = NSRect(x: cx - 180 - capW / 2 + 50, y: cy - capH / 2, width: capW, height: capH)
    let leftCapPath = NSBezierPath(roundedRect: leftCapRect, xRadius: 42, yRadius: 42)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor(red: 0.05, green: 0.45, blue: 0.95, alpha: 0.20).cgColor)
    
    let leftColors = [
        NSColor(red: 0.15, green: 0.65, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.05, green: 0.48, blue: 0.95, alpha: 1.0).cgColor
    ] as CFArray
    if let leftGrad = CGGradient(colorsSpace: cs, colors: leftColors, locations: [0.0, 1.0]) {
        cg.saveGState()
        leftCapPath.addClip()
        cg.drawLinearGradient(leftGrad, start: CGPoint(x: leftCapRect.minX, y: leftCapRect.maxY), end: CGPoint(x: leftCapRect.maxX, y: leftCapRect.minY), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    
    // File icon inside left capsule
    if let docImg = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: nil) {
        let conf = NSImage.SymbolConfiguration(pointSize: 76, weight: .semibold)
        if let icon = docImg.withSymbolConfiguration(conf) {
            let iconRect = NSRect(x: leftCapRect.midX - 38, y: leftCapRect.midY - 42, width: 76, height: 84)
            NSColor.white.setFill()
            icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }
    
    // Right capsule: Application Indicator (Soft Violet / Indigo)
    let rightCapRect = NSRect(x: cx + 180 - capW / 2 - 50, y: cy - capH / 2, width: capW, height: capH)
    let rightCapPath = NSBezierPath(roundedRect: rightCapRect, xRadius: 42, yRadius: 42)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor(red: 0.40, green: 0.30, blue: 0.95, alpha: 0.20).cgColor)
    
    let rightColors = [
        NSColor(red: 0.50, green: 0.45, blue: 0.98, alpha: 1.0).cgColor,
        NSColor(red: 0.38, green: 0.30, blue: 0.90, alpha: 1.0).cgColor
    ] as CFArray
    if let rightGrad = CGGradient(colorsSpace: cs, colors: rightColors, locations: [0.0, 1.0]) {
        cg.saveGState()
        rightCapPath.addClip()
        cg.drawLinearGradient(rightGrad, start: CGPoint(x: rightCapRect.minX, y: rightCapRect.maxY), end: CGPoint(x: rightCapRect.maxX, y: rightCapRect.minY), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    
    // App icon inside right capsule
    if let appImg = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: nil) {
        let conf = NSImage.SymbolConfiguration(pointSize: 72, weight: .semibold)
        if let icon = appImg.withSymbolConfiguration(conf) {
            let iconRect = NSRect(x: rightCapRect.midX - 36, y: rightCapRect.midY - 36, width: 72, height: 72)
            NSColor.white.setFill()
            icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }
    
    // Center Bridge Node: Clean Bidirectional Routing Arrow
    let centerBridgeRect = NSRect(x: cx - 46, y: cy - 46, width: 92, height: 92)
    let centerBridgePath = NSBezierPath(ovalIn: centerBridgeRect)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: NSColor.black.withAlphaComponent(0.14).cgColor)
    NSColor.white.setFill()
    centerBridgePath.fill()
    cg.restoreGState()
    
    centerBridgePath.lineWidth = 1.5
    NSColor(white: 0.88, alpha: 0.8).setStroke()
    centerBridgePath.stroke()
    
    if let arrowImg = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: nil) {
        let conf = NSImage.SymbolConfiguration(pointSize: 42, weight: .bold)
        if let icon = arrowImg.withSymbolConfiguration(conf) {
            let arrowRect = NSRect(x: cx - 24, y: cy - 24, width: 48, height: 48)
            NSColor(red: 0.1, green: 0.5, blue: 0.95, alpha: 1.0).setFill()
            icon.draw(in: arrowRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }
    
    NSGraphicsContext.restoreGraphicsState()
    
    if let pngData = rep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Generated minimal light icon at \(outputPath)")
    }
}

makeMinimalLightIcon(outputPath: "/tmp/minimal_light_icon.png")
