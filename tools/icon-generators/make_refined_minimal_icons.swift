import AppKit
import CoreGraphics

func savePNG(_ rep: NSBitmapImageRep, to path: String) {
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
        print("Generated: \(path)")
    }
}

// Standard Apple macOS Squircle Generator
func setupCanvasAndSquircle(size: CGFloat = 1024) -> (NSBitmapImageRep, CGContext, CGColorSpace, NSBezierPath) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.clear(NSRect(x: 0, y: 0, width: size, height: size))
    let cs = CGColorSpaceCreateDeviceRGB()
    
    // Official Apple App Icon Grid:
    // Canvas: 1024x1024. Squircle: 824x824, centered at (100, 100), corner radius: 185
    let squircleRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: 185, yRadius: 185)
    
    // Dual-stage Apple contact shadow
    // Stage 1: Soft ambient floor shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -24), blur: 40, color: NSColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 0.15).cgColor)
    NSColor(white: 0.9, alpha: 0.25).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    // Stage 2: Crisp contact shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: NSColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 0.10).cgColor)
    NSColor(white: 0.9, alpha: 0.25).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    // Fill with pristine light ceramic canvas (#FFFFFF to #F1F4F9)
    cg.saveGState()
    squirclePath.addClip()
    
    let bgColors = [
        NSColor(white: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.94, green: 0.955, blue: 0.975, alpha: 1.0).cgColor
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(bgGrad, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
    }
    
    // Subtle inner top rim light
    let innerRim = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 1.5, dy: 1.5), xRadius: 183.5, yRadius: 183.5)
    innerRim.lineWidth = 1.5
    NSColor(white: 1.0, alpha: 0.85).setStroke()
    innerRim.stroke()
    
    // 1px hairline perimeter stroke for clear separation on white wallpapers
    let outerStroke = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 184.5, yRadius: 184.5)
    outerStroke.lineWidth = 1.0
    NSColor(red: 0.12, green: 0.16, blue: 0.25, alpha: 0.10).setStroke()
    outerStroke.stroke()
    
    return (rep, cg, cs, squirclePath)
}

// =========================================================================
// OPTION A: "The Modern Monogram 'D'" (极简几何 D 标)
// Pure, iconic tech brandmark. A bold geometric 'D' with a crisp launch chevron
// pointing at +45° inside its negative space.
// =========================================================================
func makeOptionA_MonogramD(outputPath: String) {
    let (rep, cg, cs, squircle) = setupCanvasAndSquircle()
    let cx: CGFloat = 512
    let cy: CGFloat = 512
    
    // Central container / framing
    cg.saveGState()
    squircle.addClip()
    
    // The 'D' outer loop: Smooth rounded rectangular pill + half-circle
    // Spine width: 88, Height: 420, Total Width: 380
    let spineX: CGFloat = cx - 180
    let spineY: CGFloat = cy - 210
    let totalW: CGFloat = 360
    let totalH: CGFloat = 420
    let cornerR: CGFloat = 88
    
    // Outer D path
    let outerD = NSBezierPath()
    outerD.move(to: CGPoint(x: spineX + cornerR, y: spineY))
    outerD.line(to: CGPoint(x: spineX + totalW - cornerR * 1.6, y: spineY))
    // Bottom-right curve
    outerD.appendArc(
        from: CGPoint(x: spineX + totalW, y: spineY),
        to: CGPoint(x: spineX + totalW, y: cy),
        radius: totalH / 2
    )
    // Top-right curve
    outerD.appendArc(
        from: CGPoint(x: spineX + totalW, y: spineY + totalH),
        to: CGPoint(x: spineX + totalW - cornerR * 1.6, y: spineY + totalH),
        radius: totalH / 2
    )
    outerD.line(to: CGPoint(x: spineX + cornerR, y: spineY + totalH))
    // Top-left curve
    outerD.appendArc(
        from: CGPoint(x: spineX, y: spineY + totalH),
        to: CGPoint(x: spineX, y: spineY + totalH - cornerR),
        radius: cornerR
    )
    // Spine left line
    outerD.line(to: CGPoint(x: spineX, y: spineY + cornerR))
    // Bottom-left curve
    outerD.appendArc(
        from: CGPoint(x: spineX, y: spineY),
        to: CGPoint(x: spineX + cornerR, y: spineY),
        radius: cornerR
    )
    outerD.close()
    
    // Inner cutout (the counter of the 'D')
    let innerMargin: CGFloat = 82
    let innerX = spineX + innerMargin
    let innerY = spineY + innerMargin
    let innerW = totalW - innerMargin * 1.65
    let innerH = totalH - innerMargin * 2
    let innerR = cornerR * 0.55
    
    let innerD = NSBezierPath()
    innerD.move(to: CGPoint(x: innerX + innerR, y: innerY))
    innerD.line(to: CGPoint(x: innerX + innerW - innerH / 2, y: innerY))
    innerD.appendArc(
        from: CGPoint(x: innerX + innerW, y: innerY),
        to: CGPoint(x: innerX + innerW, y: cy),
        radius: innerH / 2
    )
    innerD.appendArc(
        from: CGPoint(x: innerX + innerW, y: innerY + innerH),
        to: CGPoint(x: innerX + innerW - innerH / 2, y: innerY + innerH),
        radius: innerH / 2
    )
    innerD.line(to: CGPoint(x: innerX + innerR, y: innerY + innerH))
    innerD.appendArc(
        from: CGPoint(x: innerX, y: innerY + innerH),
        to: CGPoint(x: innerX, y: innerY + innerH - innerR),
        radius: innerR
    )
    innerD.line(to: CGPoint(x: innerX, y: innerY + innerR))
    innerD.appendArc(
        from: CGPoint(x: innerX, y: innerY),
        to: CGPoint(x: innerX + innerR, y: innerY),
        radius: innerR
    )
    innerD.close()
    
    // Combine outer and inner into a single compound path
    let dGlyph = NSBezierPath()
    dGlyph.append(outerD)
    dGlyph.append(innerD)
    dGlyph.windingRule = .evenOdd
    
    // Shadow for D glyph
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -16), blur: 32, color: NSColor(red: 0.05, green: 0.3, blue: 0.85, alpha: 0.28).cgColor)
    
    // Fill D glyph with vibrant Apple Modern Blue gradient (#0066FF to #4F46E5)
    let dColors = [
        NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.31, green: 0.27, blue: 0.90, alpha: 1.0).cgColor
    ] as CFArray
    if let dGrad = CGGradient(colorsSpace: cs, colors: dColors, locations: [0.0, 1.0]) {
        cg.saveGState()
        dGlyph.addClip()
        cg.drawLinearGradient(dGrad, start: CGPoint(x: spineX, y: spineY + totalH), end: CGPoint(x: spineX + totalW, y: spineY), options: [])
        cg.restoreGState()
    }
    cg.restoreGState() // restore shadow
    
    // Dynamic Launch Arrow / Cursor inside the inner counter of D
    // Minimalist 45-degree arrow pointing up-right:
    let arrowCenter = CGPoint(x: cx + 18, y: cy)
    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: arrowCenter.x - 24, y: arrowCenter.y - 24))
    arrow.line(to: CGPoint(x: arrowCenter.x + 24, y: arrowCenter.y + 24))
    
    arrow.move(to: CGPoint(x: arrowCenter.x - 6, y: arrowCenter.y + 24))
    arrow.line(to: CGPoint(x: arrowCenter.x + 24, y: arrowCenter.y + 24))
    arrow.line(to: CGPoint(x: arrowCenter.x + 24, y: arrowCenter.y - 6))
    
    arrow.lineWidth = 14.0
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: NSColor(red: 0.0, green: 0.4, blue: 0.9, alpha: 0.3).cgColor)
    NSColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0).setStroke()
    arrow.stroke()
    cg.restoreGState()
    
    cg.restoreGState() // squircle clip
    NSGraphicsContext.restoreGraphicsState()
    
    savePNG(rep, to: outputPath)
}

// =========================================================================
// OPTION B: "The Modern Default Toggle" (极简现代开关 / 默认设置)
// High-tech utility aesthetic. A pure, oversized iOS/macOS toggle in active
// state with tactile precision and a clean checkmark/arrow.
// =========================================================================
func makeOptionB_ModernToggle(outputPath: String) {
    let (rep, cg, cs, squircle) = setupCanvasAndSquircle()
    let cx: CGFloat = 512
    let cy: CGFloat = 512
    
    cg.saveGState()
    squircle.addClip()
    
    // Toggle Track: Elegant horizontal rounded capsule
    let trackW: CGFloat = 500
    let trackH: CGFloat = 280
    let trackRect = NSRect(x: cx - trackW / 2, y: cy - trackH / 2, width: trackW, height: trackH)
    let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: trackH / 2, yRadius: trackH / 2)
    
    // Inset track shadow (recessed into squircle surface)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: NSColor(red: 0.0, green: 0.25, blue: 0.7, alpha: 0.25).cgColor)
    
    // Active track gradient: Deep Electric Sapphire to Sky Indigo
    let trackColors = [
        NSColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.15, green: 0.35, blue: 0.95, alpha: 1.0).cgColor
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: trackColors, locations: [0.0, 1.0]) {
        cg.saveGState()
        trackPath.addClip()
        cg.drawLinearGradient(grad, start: CGPoint(x: trackRect.minX, y: trackRect.maxY), end: CGPoint(x: trackRect.maxX, y: trackRect.minY), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    
    // Track inner highlight rim
    let trackRim = NSBezierPath(roundedRect: trackRect.insetBy(dx: 1.5, dy: 1.5), xRadius: (trackH - 3) / 2, yRadius: (trackH - 3) / 2)
    trackRim.lineWidth = 1.5
    NSColor(white: 1.0, alpha: 0.35).setStroke()
    trackRim.stroke()
    
    // Slider Puck (Knob) at the active right position
    let knobDiameter: CGFloat = 250
    let knobMargin: CGFloat = (trackH - knobDiameter) / 2
    let knobX = trackRect.maxX - knobDiameter - knobMargin
    let knobY = trackRect.minY + knobMargin
    let knobRect = NSRect(x: knobX, y: knobY, width: knobDiameter, height: knobDiameter)
    let knobPath = NSBezierPath(ovalIn: knobRect)
    
    // Tactile knob shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: -8, height: -12), blur: 24, color: NSColor(red: 0.0, green: 0.1, blue: 0.4, alpha: 0.3).cgColor)
    NSColor.white.setFill()
    knobPath.fill()
    cg.restoreGState()
    
    // Knob subtle top specular
    let knobRim = NSBezierPath(ovalIn: knobRect.insetBy(dx: 1.0, dy: 1.0))
    knobRim.lineWidth = 1.0
    NSColor(white: 1.0, alpha: 0.9).setStroke()
    knobRim.stroke()
    
    // Inside Knob: Clean modern "Checkmark" for default
    let checkCenter = CGPoint(x: knobRect.midX, y: knobRect.midY)
    let check = NSBezierPath()
    check.move(to: CGPoint(x: checkCenter.x - 36, y: checkCenter.y + 2))
    check.line(to: CGPoint(x: checkCenter.x - 10, y: checkCenter.y - 26))
    check.line(to: CGPoint(x: checkCenter.x + 42, y: checkCenter.y + 30))
    check.lineWidth = 15.0
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    
    NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).setStroke()
    check.stroke()
    
    // Subtle left track decorative icon: 3 minimal file routing lines (showing mapped files)
    let lineX = trackRect.minX + 70
    for i in 0..<3 {
        let lineY = cy + CGFloat(i - 1) * 36
        let line = NSBezierPath()
        line.move(to: CGPoint(x: lineX, y: lineY))
        line.line(to: CGPoint(x: lineX + 60, y: lineY))
        line.lineWidth = 8.0
        line.lineCapStyle = .round
        NSColor(white: 1.0, alpha: 0.45).setStroke()
        line.stroke()
    }
    
    cg.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    
    savePNG(rep, to: outputPath)
}

// =========================================================================
// OPTION C: "The Shortcuts Intersect" (现代双轨交汇 / 映射灵动环)
// Two sleek, overlapping, semi-translucent rounded capsules angled at 45°
// creating an optical intersection that symbolizes mapping any file to any app.
// =========================================================================
func makeOptionC_ShortcutsIntersect(outputPath: String) {
    let (rep, cg, cs, squircle) = setupCanvasAndSquircle()
    let cx: CGFloat = 512
    let cy: CGFloat = 512
    
    cg.saveGState()
    squircle.addClip()
    
    let capsuleW: CGFloat = 130
    let capsuleH: CGFloat = 390
    
    // First Capsule: Electric Royal Blue (Rotated -35 deg)
    cg.saveGState()
    cg.translateBy(x: cx - 45, y: cy + 30)
    cg.rotate(by: -35.0 * .pi / 180.0)
    
    let cap1Rect = NSRect(x: -capsuleW / 2, y: -capsuleH / 2, width: capsuleW, height: capsuleH)
    let cap1Path = NSBezierPath(roundedRect: cap1Rect, xRadius: capsuleW / 2, yRadius: capsuleW / 2)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor(red: 0.0, green: 0.3, blue: 0.9, alpha: 0.32).cgColor)
    
    let grad1Colors = [
        NSColor(red: 0.05, green: 0.60, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.0, green: 0.35, blue: 0.95, alpha: 1.0).cgColor
    ] as CFArray
    if let grad1 = CGGradient(colorsSpace: cs, colors: grad1Colors, locations: [0.0, 1.0]) {
        cg.saveGState()
        cap1Path.addClip()
        cg.drawLinearGradient(grad1, start: CGPoint(x: 0, y: capsuleH / 2), end: CGPoint(x: 0, y: -capsuleH / 2), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    cg.restoreGState()
    
    // Second Capsule: Vivid Violet-Indigo (Rotated +35 deg, with blend)
    cg.saveGState()
    cg.translateBy(x: cx + 45, y: cy - 30)
    cg.rotate(by: 35.0 * .pi / 180.0)
    
    let cap2Rect = NSRect(x: -capsuleW / 2, y: -capsuleH / 2, width: capsuleW, height: capsuleH)
    let cap2Path = NSBezierPath(roundedRect: cap2Rect, xRadius: capsuleW / 2, yRadius: capsuleW / 2)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor(red: 0.35, green: 0.15, blue: 0.85, alpha: 0.30).cgColor)
    
    let grad2Colors = [
        NSColor(red: 0.48, green: 0.35, blue: 1.0, alpha: 0.92).cgColor,
        NSColor(red: 0.28, green: 0.18, blue: 0.90, alpha: 0.92).cgColor
    ] as CFArray
    if let grad2 = CGGradient(colorsSpace: cs, colors: grad2Colors, locations: [0.0, 1.0]) {
        cg.saveGState()
        cap2Path.addClip()
        cg.drawLinearGradient(grad2, start: CGPoint(x: 0, y: capsuleH / 2), end: CGPoint(x: 0, y: -capsuleH / 2), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    cg.restoreGState()
    
    // Center Floating Nexus Disc: Pure White with bold Default Diamond
    let nexusR: CGFloat = 85
    let nexusRect = NSRect(x: cx - nexusR, y: cy - nexusR, width: nexusR * 2, height: nexusR * 2)
    let nexusPath = NSBezierPath(ovalIn: nexusRect)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: NSColor(red: 0.05, green: 0.1, blue: 0.25, alpha: 0.22).cgColor)
    NSColor.white.setFill()
    nexusPath.fill()
    cg.restoreGState()
    
    nexusPath.lineWidth = 1.5
    NSColor(white: 0.92, alpha: 0.9).setStroke()
    nexusPath.stroke()
    
    // Central Icon: A dynamic fast-forward / route chevron
    let chevPath = NSBezierPath()
    chevPath.move(to: CGPoint(x: cx - 24, y: cy + 22))
    chevPath.line(to: CGPoint(x: cx - 2, y: cy))
    chevPath.line(to: CGPoint(x: cx - 24, y: cy - 22))
    
    chevPath.move(to: CGPoint(x: cx + 2, y: cy + 22))
    chevPath.line(to: CGPoint(x: cx + 24, y: cy))
    chevPath.line(to: CGPoint(x: cx + 2, y: cy - 22))
    
    chevPath.lineWidth = 8.0
    chevPath.lineCapStyle = .round
    chevPath.lineJoinStyle = .round
    NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).setStroke()
    chevPath.stroke()
    
    cg.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    
    savePNG(rep, to: outputPath)
}

// =========================================================================
// OPTION D: "The Raycast-Style Pure Polygon" (极简几何棱镜 / 核心派)
// Razor-sharp modern minimalism. An iconic 45° faceted geometric prism/gem
// with high-contrast, pure vector gradients.
// =========================================================================
func makeOptionD_MinimalPrism(outputPath: String) {
    let (rep, cg, cs, squircle) = setupCanvasAndSquircle()
    let cx: CGFloat = 512
    let cy: CGFloat = 512
    
    cg.saveGState()
    squircle.addClip()
    
    // Outer rounded diamond (rotated 45 deg)
    let side: CGFloat = 320
    let diamond = NSBezierPath(roundedRect: NSRect(x: -side / 2, y: -side / 2, width: side, height: side), xRadius: 64, yRadius: 64)
    
    cg.saveGState()
    cg.translateBy(x: cx, y: cy)
    cg.rotate(by: 45.0 * .pi / 180.0)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: -10, height: -14), blur: 32, color: NSColor(red: 0.05, green: 0.35, blue: 0.95, alpha: 0.30).cgColor)
    
    let prismColors = [
        NSColor(red: 0.05, green: 0.55, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.0, green: 0.30, blue: 0.90, alpha: 1.0).cgColor
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: prismColors, locations: [0.0, 1.0]) {
        cg.saveGState()
        diamond.addClip()
        cg.drawLinearGradient(grad, start: CGPoint(x: -side / 2, y: side / 2), end: CGPoint(x: side / 2, y: -side / 2), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    
    // Crisp inner faceted fold line
    let fold = NSBezierPath()
    fold.move(to: CGPoint(x: -side / 2, y: -side / 2))
    fold.line(to: CGPoint(x: side / 2, y: side / 2))
    fold.lineWidth = 2.0
    NSColor(white: 1.0, alpha: 0.35).setStroke()
    fold.stroke()
    
    cg.restoreGState()
    
    // Central White Launch Chevron pointing straight up-right (Launch)
    let launchArrow = NSBezierPath()
    launchArrow.move(to: CGPoint(x: cx - 44, y: cy))
    launchArrow.line(to: CGPoint(x: cx + 24, y: cy))
    launchArrow.line(to: CGPoint(x: cx + 24, y: cy - 44))
    
    launchArrow.move(to: CGPoint(x: cx + 24, y: cy))
    launchArrow.line(to: CGPoint(x: cx - 36, y: cy - 60))
    
    // Let's draw an unmistakable, crisp, modern white directional arrow
    let arrowPath = NSBezierPath()
    let aR: CGFloat = 36
    arrowPath.move(to: CGPoint(x: cx - aR, y: cy - aR))
    arrowPath.line(to: CGPoint(x: cx + aR, y: cy + aR))
    
    arrowPath.move(to: CGPoint(x: cx - 6, y: cy + aR))
    arrowPath.line(to: CGPoint(x: cx + aR, y: cy + aR))
    arrowPath.line(to: CGPoint(x: cx + aR, y: cy - 6))
    
    arrowPath.lineWidth = 16.0
    arrowPath.lineCapStyle = .round
    arrowPath.lineJoinStyle = .round
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -3), blur: 8, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    NSColor.white.setStroke()
    arrowPath.stroke()
    cg.restoreGState()
    
    cg.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    
    savePNG(rep, to: outputPath)
}

let outDir = "/Users/w_ood/.gemini/antigravity/brain/859e3715-c92b-4df3-8b48-318f982ebef6"
makeOptionA_MonogramD(outputPath: "\(outDir)/opt_a_monogram.png")
makeOptionB_ModernToggle(outputPath: "\(outDir)/opt_b_toggle.png")
makeOptionC_ShortcutsIntersect(outputPath: "\(outDir)/opt_c_shortcuts.png")
makeOptionD_MinimalPrism(outputPath: "\(outDir)/opt_d_prism.png")
print("All 4 refined modern minimalist icons rendered successfully!")
