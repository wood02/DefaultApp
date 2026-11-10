import AppKit
import CoreGraphics

// Helper to save NSBitmapImageRep as PNG
func savePNG(_ rep: NSBitmapImageRep, to path: String) {
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
        print("Successfully saved: \(path)")
    }
}

// Draw Apple Standard Squircle Base
func drawSquircleBase(in cg: CGContext, cs: CGColorSpace) -> NSBezierPath {
    let squircleRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: 185, yRadius: 185)
    
    // Ambient Contact Shadow (Layer 1: Wide diffuse)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -22), blur: 36, color: NSColor(red: 0.1, green: 0.15, blue: 0.28, alpha: 0.16).cgColor)
    NSColor(white: 0.9, alpha: 0.3).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    // Ambient Contact Shadow (Layer 2: Tight ground)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: NSColor(red: 0.1, green: 0.15, blue: 0.28, alpha: 0.10).cgColor)
    NSColor(white: 0.9, alpha: 0.3).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    // Fill Squircle with light ceramic gradient (#FFFFFF to #F3F5F9)
    cg.saveGState()
    squirclePath.addClip()
    
    let bgColors = [
        NSColor(white: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1.0).cgColor
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(grad, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
    }
    
    // Very subtle ultra-clean top rim highlight
    let innerBorder = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 1.5, dy: 1.5), xRadius: 183.5, yRadius: 183.5)
    innerBorder.lineWidth = 1.5
    NSColor(white: 1.0, alpha: 0.9).setStroke()
    innerBorder.stroke()
    
    // Subtle boundary stroke for high contrast on light backgrounds
    let outerStroke = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 184.5, yRadius: 184.5)
    outerStroke.lineWidth = 1.0
    NSColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 0.12).setStroke()
    outerStroke.stroke()
    
    cg.restoreGState() // end clip
    
    return squirclePath
}

// =========================================================================
// DESIGN 1: "The Monogram Loop 'D'" (Modern, Tech-Forward, Linear/Arc Style)
// A bold continuous ribbon forming a stylized geometric 'D' that seamlessly
// loops into a launch arrow / forward router.
// =========================================================================
func generateDesign1_MonogramD(outputPath: String) {
    let size: CGFloat = 1024
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return }
    
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.clear(NSRect(x: 0, y: 0, width: size, height: size))
    let cs = CGColorSpaceCreateDeviceRGB()
    
    let squircle = drawSquircleBase(in: cg, cs: cs)
    
    // Within the squircle:
    cg.saveGState()
    squircle.addClip()
    
    let cx: CGFloat = 512
    let cy: CGFloat = 512
    
    // Minimalist geometric 'D' + dynamic forward aperture
    // Formed by two smooth overlapping capsules / rounded geometric paths
    // Vertical spine + dynamic sweeping arc
    let spineRect = NSRect(x: cx - 180, y: cy - 200, width: 84, height: 400)
    let spinePath = NSBezierPath(roundedRect: spineRect, xRadius: 42, yRadius: 42)
    
    // The Loop of 'D': An outer smooth arc and inner cutout
    let loopRect = NSRect(x: cx - 160, y: cy - 200, width: 340, height: 400)
    let loopPath = NSBezierPath()
    // Start at bottom of spine, curve out to right, curve back to top of spine
    loopPath.move(to: CGPoint(x: cx - 120, y: cy - 200))
    loopPath.appendArc(from: CGPoint(x: cx + 180, y: cy - 200), to: CGPoint(x: cx + 180, y: cy), radius: 200)
    loopPath.appendArc(from: CGPoint(x: cx + 180, y: cy + 200), to: CGPoint(x: cx - 120, y: cy + 200), radius: 200)
    loopPath.line(to: CGPoint(x: cx - 120, y: cy + 200))
    loopPath.line(to: CGPoint(x: cx - 120, y: cy + 120))
    loopPath.appendArc(from: CGPoint(x: cx + 96, y: cy + 120), to: CGPoint(x: cx + 96, y: cy), radius: 120)
    loopPath.appendArc(from: CGPoint(x: cx + 96, y: cy - 120), to: CGPoint(x: cx - 120, y: cy - 120), radius: 120)
    loopPath.close()
    
    // Draw subtle drop shadow under the glyph
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 32, color: NSColor(red: 0.05, green: 0.25, blue: 0.85, alpha: 0.24).cgColor)
    
    // Gradient for the loop: Electric Blue (#0066FF) to Vibrant Purple/Violet (#6366F1)
    let loopGradColors = [
        NSColor(red: 0.0, green: 0.45, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.38, green: 0.28, blue: 0.95, alpha: 1.0).cgColor
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: loopGradColors, locations: [0.0, 1.0]) {
        cg.saveGState()
        loopPath.addClip()
        cg.drawLinearGradient(grad, start: CGPoint(x: cx - 120, y: cy - 200), end: CGPoint(x: cx + 180, y: cy + 200), options: [])
        cg.restoreGState()
    }
    cg.restoreGState() // restore shadow
    
    // Spine: Clean deep obsidian cobalt with its own crisp shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 6, height: 0), blur: 16, color: NSColor(red: 0.0, green: 0.1, blue: 0.3, alpha: 0.22).cgColor)
    
    let spineGradColors = [
        NSColor(red: 0.05, green: 0.35, blue: 0.95, alpha: 1.0).cgColor,
        NSColor(red: 0.0, green: 0.55, blue: 1.0, alpha: 1.0).cgColor
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: spineGradColors, locations: [0.0, 1.0]) {
        cg.saveGState()
        spinePath.addClip()
        cg.drawLinearGradient(grad, start: CGPoint(x: cx - 180, y: cy + 200), end: CGPoint(x: cx - 96, y: cy - 200), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    
    // Central Dynamic Aperture Node (A crisp white floating arrow/diamond at the center)
    // Symbolizes "Routing / Selecting Default"
    let nodeCenter = CGPoint(x: cx + 32, y: cy)
    let nodeRadius: CGFloat = 46
    let nodeRect = NSRect(x: nodeCenter.x - nodeRadius, y: nodeCenter.y - nodeRadius, width: nodeRadius * 2, height: nodeRadius * 2)
    let nodePath = NSBezierPath(ovalIn: nodeRect)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: NSColor.black.withAlphaComponent(0.18).cgColor)
    NSColor.white.setFill()
    nodePath.fill()
    cg.restoreGState()
    
    // Crisp checkmark or forward chevron inside the node
    let chevPath = NSBezierPath()
    chevPath.move(to: CGPoint(x: nodeCenter.x - 12, y: nodeCenter.y + 16))
    chevPath.line(to: CGPoint(x: nodeCenter.x + 10, y: nodeCenter.y))
    chevPath.line(to: CGPoint(x: nodeCenter.x - 12, y: nodeCenter.y - 16))
    chevPath.lineWidth = 7.0
    chevPath.lineCapStyle = .round
    chevPath.lineJoinStyle = .round
    NSColor(red: 0.05, green: 0.45, blue: 0.98, alpha: 1.0).setStroke()
    chevPath.stroke()
    
    cg.restoreGState() // restore squircle clip
    NSGraphicsContext.restoreGraphicsState()
    
    savePNG(rep, to: outputPath)
}

// =========================================================================
// DESIGN 2: "The Modern Dual-Route Switch" (Raycast / Apple Shortcuts Style)
// Two sleek, overlapping rounded lozenges intersecting with clean optical
// transparency and a vibrant dynamic routing badge.
// =========================================================================
func generateDesign2_RoutingSwitch(outputPath: String) {
    let size: CGFloat = 1024
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return }
    
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.clear(NSRect(x: 0, y: 0, width: size, height: size))
    let cs = CGColorSpaceCreateDeviceRGB()
    
    let squircle = drawSquircleBase(in: cg, cs: cs)
    
    cg.saveGState()
    squircle.addClip()
    
    let cx: CGFloat = 512
    let cy: CGFloat = 512
    
    // Two dynamic 45-degree angled rounded rectangles forming an intersection (X / Bridge)
    // Left: Sapphire Blue Pill (45 deg)
    // Right: Electric Coral / Violet Pill (-45 deg)
    let pillW: CGFloat = 120
    let pillH: CGFloat = 380
    
    // First pill: Angled -30 deg
    cg.saveGState()
    cg.translateBy(x: cx, y: cy)
    cg.rotate(by: -30.0 * .pi / 180.0)
    
    let pill1Rect = NSRect(x: -pillW / 2 - 40, y: -pillH / 2, width: pillW, height: pillH)
    let pill1Path = NSBezierPath(roundedRect: pill1Rect, xRadius: pillW / 2, yRadius: pillW / 2)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: NSColor(red: 0.05, green: 0.35, blue: 0.95, alpha: 0.28).cgColor)
    
    let grad1Colors = [
        NSColor(red: 0.05, green: 0.55, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.0, green: 0.35, blue: 0.95, alpha: 1.0).cgColor
    ] as CFArray
    if let grad1 = CGGradient(colorsSpace: cs, colors: grad1Colors, locations: [0.0, 1.0]) {
        cg.saveGState()
        pill1Path.addClip()
        cg.drawLinearGradient(grad1, start: CGPoint(x: pill1Rect.minX, y: pill1Rect.maxY), end: CGPoint(x: pill1Rect.maxX, y: pill1Rect.minY), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    cg.restoreGState()
    
    // Second pill: Angled +30 deg
    cg.saveGState()
    cg.translateBy(x: cx, y: cy)
    cg.rotate(by: 30.0 * .pi / 180.0)
    
    let pill2Rect = NSRect(x: -pillW / 2 + 40, y: -pillH / 2, width: pillW, height: pillH)
    let pill2Path = NSBezierPath(roundedRect: pill2Rect, xRadius: pillW / 2, yRadius: pillW / 2)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: NSColor(red: 0.35, green: 0.2, blue: 0.85, alpha: 0.25).cgColor)
    
    let grad2Colors = [
        NSColor(red: 0.45, green: 0.35, blue: 0.98, alpha: 1.0).cgColor,
        NSColor(red: 0.25, green: 0.20, blue: 0.85, alpha: 1.0).cgColor
    ] as CFArray
    if let grad2 = CGGradient(colorsSpace: cs, colors: grad2Colors, locations: [0.0, 1.0]) {
        cg.saveGState()
        pill2Path.addClip()
        cg.drawLinearGradient(grad2, start: CGPoint(x: pill2Rect.minX, y: pill2Rect.maxY), end: CGPoint(x: pill2Rect.maxX, y: pill2Rect.minY), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    cg.restoreGState()
    
    // Central Convergence Badge: Pristine White Disc with an Apple-style Default Check/Star
    let badgeR: CGFloat = 80
    let badgeRect = NSRect(x: cx - badgeR, y: cy - badgeR, width: badgeR * 2, height: badgeR * 2)
    let badgePath = NSBezierPath(ovalIn: badgeRect)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: NSColor.black.withAlphaComponent(0.18).cgColor)
    NSColor.white.setFill()
    badgePath.fill()
    cg.restoreGState()
    
    // Subtle crisp border
    badgePath.lineWidth = 1.5
    NSColor(white: 0.9, alpha: 0.8).setStroke()
    badgePath.stroke()
    
    // Elegant Launch Arrow symbol inside badge
    let arrowPath = NSBezierPath()
    arrowPath.move(to: CGPoint(x: cx - 26, y: cy - 2))
    arrowPath.line(to: CGPoint(x: cx + 16, y: cy - 2))
    arrowPath.move(to: CGPoint(x: cx + 2, y: cy + 18))
    arrowPath.line(to: CGPoint(x: cx + 20, y: cy - 2))
    arrowPath.line(to: CGPoint(x: cx + 2, y: cy - 22))
    
    arrowPath.lineWidth = 8.0
    arrowPath.lineCapStyle = .round
    arrowPath.lineJoinStyle = .round
    NSColor(red: 0.05, green: 0.48, blue: 0.98, alpha: 1.0).setStroke()
    arrowPath.stroke()
    
    cg.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    
    savePNG(rep, to: outputPath)
}

// =========================================================================
// DESIGN 3: "The Pure Aperture / Minimalist Anchor" (Figma / Things 3 Style)
// Ultra-minimalist, razor-sharp modern icon. A crisp geometric circular
// target with an authoritative, elegant default indicator notch.
// =========================================================================
func generateDesign3_PureAperture(outputPath: String) {
    let size: CGFloat = 1024
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return }
    
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.clear(NSRect(x: 0, y: 0, width: size, height: size))
    let cs = CGColorSpaceCreateDeviceRGB()
    
    let squircle = drawSquircleBase(in: cg, cs: cs)
    
    cg.saveGState()
    squircle.addClip()
    
    let cx: CGFloat = 512
    let cy: CGFloat = 512
    
    // Large outer ring (Sapphire to Electric Cyan)
    let ringOuterR: CGFloat = 220
    let ringInnerR: CGFloat = 145
    
    let ringPath = NSBezierPath()
    ringPath.appendOval(in: NSRect(x: cx - ringOuterR, y: cy - ringOuterR, width: ringOuterR * 2, height: ringOuterR * 2))
    ringPath.appendOval(in: NSRect(x: cx - ringInnerR, y: cy - ringInnerR, width: ringInnerR * 2, height: ringInnerR * 2))
    ringPath.windingRule = .evenOdd
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor(red: 0.05, green: 0.35, blue: 0.95, alpha: 0.22).cgColor)
    
    let ringGradColors = [
        NSColor(red: 0.0, green: 0.55, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.1, green: 0.30, blue: 0.92, alpha: 1.0).cgColor
    ] as CFArray
    if let ringGrad = CGGradient(colorsSpace: cs, colors: ringGradColors, locations: [0.0, 1.0]) {
        cg.saveGState()
        ringPath.addClip()
        cg.drawLinearGradient(ringGrad, start: CGPoint(x: cx - ringOuterR, y: cy + ringOuterR), end: CGPoint(x: cx + ringOuterR, y: cy - ringOuterR), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    
    // Solid Center Core (Target / Bullseye)
    let coreR: CGFloat = 90
    let coreRect = NSRect(x: cx - coreR, y: cy - coreR, width: coreR * 2, height: coreR * 2)
    let corePath = NSBezierPath(ovalIn: coreRect)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor(red: 0.05, green: 0.25, blue: 0.85, alpha: 0.28).cgColor)
    
    let coreGradColors = [
        NSColor(red: 0.05, green: 0.40, blue: 0.98, alpha: 1.0).cgColor,
        NSColor(red: 0.25, green: 0.25, blue: 0.92, alpha: 1.0).cgColor
    ] as CFArray
    if let coreGrad = CGGradient(colorsSpace: cs, colors: coreGradColors, locations: [0.0, 1.0]) {
        cg.saveGState()
        corePath.addClip()
        cg.drawLinearGradient(coreGrad, start: CGPoint(x: coreRect.minX, y: coreRect.maxY), end: CGPoint(x: coreRect.maxX, y: coreRect.minY), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    
    // Pure White Default Pointer / Checkmark inside core
    let checkPath = NSBezierPath()
    checkPath.move(to: CGPoint(x: cx - 28, y: cy + 2))
    checkPath.line(to: CGPoint(x: cx - 8, y: cy - 20))
    checkPath.line(to: CGPoint(x: cx + 32, y: cy + 22))
    checkPath.lineWidth = 14.0
    checkPath.lineCapStyle = .round
    checkPath.lineJoinStyle = .round
    NSColor.white.setStroke()
    checkPath.stroke()
    
    // Ambient geometric satellite dot (top right) - gives that modern tech edge (like Linear / Raycast)
    let dotR: CGFloat = 28
    let dotCenter = CGPoint(x: cx + 185, y: cy + 185)
    let dotRect = NSRect(x: dotCenter.x - dotR, y: dotCenter.y - dotR, width: dotR * 2, height: dotR * 2)
    let dotPath = NSBezierPath(ovalIn: dotRect)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: NSColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 0.35).cgColor)
    NSColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 1.0).setFill()
    dotPath.fill()
    cg.restoreGState()
    
    cg.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    
    savePNG(rep, to: outputPath)
}

let outDir = "/Users/w_ood/.gemini/antigravity/brain/859e3715-c92b-4df3-8b48-318f982ebef6"
generateDesign1_MonogramD(outputPath: "\(outDir)/modern_minimal_d.png")
generateDesign2_RoutingSwitch(outputPath: "\(outDir)/modern_minimal_switch.png")
generateDesign3_PureAperture(outputPath: "\(outDir)/modern_minimal_aperture.png")
print("All 3 modern minimalist vector icons generated successfully!")
