import AppKit
import CoreGraphics

func savePNG(_ rep: NSBitmapImageRep, to path: String) {
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path)")
    }
}

func createRoundedPolygonPath(points: [CGPoint], radii: [CGFloat]) -> CGPath {
    let path = CGMutablePath()
    guard points.count >= 3, points.count == radii.count else { return path }
    let n = points.count
    
    let startMid = CGPoint(
        x: (points[n - 1].x + points[0].x) / 2.0,
        y: (points[n - 1].y + points[0].y) / 2.0
    )
    path.move(to: startMid)
    
    for i in 0..<n {
        let p1 = points[i]
        let p2 = points[(i + 1) % n]
        path.addArc(tangent1End: p1, tangent2End: p2, radius: radii[i])
    }
    path.closeSubpath()
    return path
}

func setupMinimalCanvas(size: CGFloat = 1024) -> (NSBitmapImageRep, CGContext, CGColorSpace, NSBezierPath) {
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
    
    let squircleRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: 185, yRadius: 185)
    
    // Soft, clean Apple ambient shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -20), blur: 36, color: NSColor(red: 0.06, green: 0.10, blue: 0.18, alpha: 0.12).cgColor)
    NSColor(white: 0.96, alpha: 0.5).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: NSColor(red: 0.06, green: 0.10, blue: 0.18, alpha: 0.08).cgColor)
    NSColor(white: 0.96, alpha: 0.5).setFill()
    squirclePath.fill()
    cg.restoreGState()
    
    // Clip to squircle
    cg.saveGState()
    squirclePath.addClip()
    
    // Warm ceramic white gradient (#FFFFFF -> #F4F6F9)
    let bgColors = [
        NSColor(white: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.955, green: 0.965, blue: 0.98, alpha: 1.0).cgColor
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(bgGrad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    }
    
    // Crisp 1px border & inner highlight
    let innerHighlight = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 1.5, dy: 1.5), xRadius: 183.5, yRadius: 183.5)
    innerHighlight.lineWidth = 1.5
    NSColor(white: 1.0, alpha: 0.95).setStroke()
    innerHighlight.stroke()
    
    let outerBorder = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 184.5, yRadius: 184.5)
    outerBorder.lineWidth = 1.0
    NSColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 0.09).setStroke()
    outerBorder.stroke()
    
    return (rep, cg, cs, squirclePath)
}

// =========================================================================
// 思路一：【指向之翼 / 几何光标】 (Origami Cursor Wing)
// Unified outer silhouette with razor-sharp diagonal crease split at 45°.
// =========================================================================
func generateConcept1_OrigamiWing(outputPath: String) {
    let (rep, cg, cs, _) = setupMinimalCanvas()
    
    // Symmetrical 45° dart geometry centered optically around (512, 512)
    let apex = CGPoint(x: 700, y: 700)
    let leftWingTip = CGPoint(x: 285, y: 550)
    let centerNotch = CGPoint(x: 455, y: 455)
    let rightWingTip = CGPoint(x: 550, y: 285)
    
    let outerDartPath = createRoundedPolygonPath(
        points: [apex, leftWingTip, centerNotch, rightWingTip],
        radii: [26, 26, 22, 26]
    )
    
    // Draw soft ambient drop shadow for the entire unified dart
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -20), blur: 34, color: NSColor(red: 0.0, green: 0.35, blue: 0.90, alpha: 0.22).cgColor)
    cg.addPath(outerDartPath)
    NSColor.white.setFill()
    cg.fillPath()
    cg.restoreGState()
    
    // Clip strictly inside the unified outer dart silhouette so the apex is 100% seamless
    cg.saveGState()
    cg.addPath(outerDartPath)
    cg.clip()
    
    // 1. Fill lower-right wing (Glacier Sky Blue)
    let rightColors = [
        NSColor(red: 0.22, green: 0.75, blue: 0.98, alpha: 1.0).cgColor, // #38BDF8
        NSColor(red: 0.02, green: 0.54, blue: 0.86, alpha: 1.0).cgColor  // #058AD9
    ] as CFArray
    if let rGrad = CGGradient(colorsSpace: cs, colors: rightColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(rGrad, start: apex, end: rightWingTip, options: [])
    }
    
    // 2. Fill upper-left wing (Deep Apple Royal Blue) along the exact 45° diagonal crease
    let leftHalfPlane = CGMutablePath()
    leftHalfPlane.move(to: CGPoint(x: 100, y: 100))
    leftHalfPlane.addLine(to: CGPoint(x: 900, y: 900))
    leftHalfPlane.addLine(to: CGPoint(x: 100, y: 900))
    leftHalfPlane.closeSubpath()
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 6, height: -6), blur: 16, color: NSColor(red: 0.0, green: 0.15, blue: 0.45, alpha: 0.25).cgColor)
    cg.addPath(leftHalfPlane)
    cg.clip()
    
    let leftColors = [
        NSColor(red: 0.06, green: 0.48, blue: 1.0, alpha: 1.0).cgColor,  // #0F7AFF
        NSColor(red: 0.0, green: 0.33, blue: 0.90, alpha: 1.0).cgColor   // #0054E6
    ] as CFArray
    if let lGrad = CGGradient(colorsSpace: cs, colors: leftColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(lGrad, start: apex, end: leftWingTip, options: [])
    }
    cg.restoreGState()
    
    // Subtle luminous crease highlight along the diagonal fold
    let crease = NSBezierPath()
    crease.move(to: centerNotch)
    crease.line(to: apex)
    crease.lineWidth = 1.5
    NSColor(white: 1.0, alpha: 0.35).setStroke()
    crease.stroke()
    
    cg.restoreGState() // end outerDartPath clip
    cg.restoreGState() // end squircle clip
    NSGraphicsContext.restoreGraphicsState()
    savePNG(rep, to: outputPath)
}

// =========================================================================
// 思路二：【一笔莫比乌斯 D 环】 (Continuous Ribbon D)
// Exact tangent geometry with smooth rounded left corners and interlocking joint.
// =========================================================================
func generateConcept2_RibbonD(outputPath: String) {
    let (rep, cg, cs, _) = setupMinimalCanvas()
    
    let cy: CGFloat = 512
    let strokeW: CGFloat = 84
    let spineX: CGFloat = 355
    let arcCenter = CGPoint(x: 495, y: cy)
    let arcR: CGFloat = 170
    let cornerR: CGFloat = 54
    
    // Segment 1 (Bottom + Right Semicircle Loop - Glacier Azure)
    // Starts mid-left spine -> goes down -> rounds bottom-left -> goes right -> sweeps 180° semicircle -> ends at top tangent
    let seg1 = CGMutablePath()
    seg1.move(to: CGPoint(x: spineX, y: cy + 20))
    seg1.addArc(tangent1End: CGPoint(x: spineX, y: cy - arcR), tangent2End: CGPoint(x: arcCenter.x, y: cy - arcR), radius: cornerR)
    seg1.addLine(to: CGPoint(x: arcCenter.x, y: cy - arcR))
    seg1.addArc(center: arcCenter, radius: arcR, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
    
    let strokedSeg1 = seg1.copy(strokingWithWidth: strokeW, lineCap: .round, lineJoin: .round, miterLimit: 10)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor(red: 0.02, green: 0.40, blue: 0.85, alpha: 0.18).cgColor)
    cg.addPath(strokedSeg1)
    cg.clip()
    let loopColors = [
        NSColor(red: 0.22, green: 0.75, blue: 0.98, alpha: 1.0).cgColor, // #38BDF8
        NSColor(red: 0.02, green: 0.52, blue: 0.92, alpha: 1.0).cgColor  // #0585EB
    ] as CFArray
    let gOpts: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    if let lGrad = CGGradient(colorsSpace: cs, colors: loopColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(lGrad, start: CGPoint(x: arcCenter.x + arcR, y: cy + arcR), end: CGPoint(x: spineX, y: cy - arcR), options: gOpts)
    }
    cg.restoreGState()
    
    // Segment 2 (Top Horizontal + Left Vertical Pillar - Deep Royal Blue)
    // Starts at (arcCenter.x - 10, cy + arcR) -> goes left -> rounds top-left -> goes down spine
    let seg2 = CGMutablePath()
    seg2.move(to: CGPoint(x: arcCenter.x - 10, y: cy + arcR))
    seg2.addArc(tangent1End: CGPoint(x: spineX, y: cy + arcR), tangent2End: CGPoint(x: spineX, y: cy - arcR), radius: cornerR)
    seg2.addLine(to: CGPoint(x: spineX, y: cy - arcR + cornerR))
    
    let strokedSeg2 = seg2.copy(strokingWithWidth: strokeW, lineCap: .round, lineJoin: .round, miterLimit: 10)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 4, height: -6), blur: 16, color: NSColor(red: 0.0, green: 0.15, blue: 0.45, alpha: 0.22).cgColor)
    cg.addPath(strokedSeg2)
    cg.clip()
    let pillarColors = [
        NSColor(red: 0.05, green: 0.46, blue: 1.0, alpha: 1.0).cgColor,  // #0D75FF
        NSColor(red: 0.14, green: 0.28, blue: 0.90, alpha: 1.0).cgColor  // #2447E6
    ] as CFArray
    if let pGrad = CGGradient(colorsSpace: cs, colors: pillarColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(pGrad, start: CGPoint(x: spineX, y: cy + arcR), end: CGPoint(x: spineX, y: cy - arcR), options: gOpts)
    }
    cg.restoreGState()
    
    cg.restoreGState() // end squircle clip
    NSGraphicsContext.restoreGraphicsState()
    savePNG(rep, to: outputPath)
}

// =========================================================================
// 思路三：【默认象限 / 瑞士几何罗盘】 (Swiss Quadrant Focus)
// A precision geometric ring where the top-right 90° default sector detaches
// and elevates at +45° around a crisp core dot. Zero eyeball effect!
// =========================================================================
func generateConcept3_SwissQuadrant(outputPath: String) {
    let (rep, cg, cs, _) = setupMinimalCanvas()
    
    let center = CGPoint(x: 500, y: 500)
    let ringR: CGFloat = 175
    let ringStroke: CGFloat = 68
    
    // 1. Base 210° Inactive Ring Sector (Bottom-Left to Top-Left / Bottom-Right)
    // Angles in radians: from 105° (.pi * 105/180) counter-clockwise to 345° (.pi * 345/180)
    let baseArc = CGMutablePath()
    baseArc.addArc(
        center: center,
        radius: ringR,
        startAngle: 108.0 * .pi / 180.0,
        endAngle: -18.0 * .pi / 180.0,
        clockwise: false
    )
    let strokedBaseArc = baseArc.copy(strokingWithWidth: ringStroke, lineCap: .round, lineJoin: .round, miterLimit: 10)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: NSColor(red: 0.05, green: 0.25, blue: 0.65, alpha: 0.12).cgColor)
    cg.addPath(strokedBaseArc)
    cg.clip()
    let baseColors = [
        NSColor(red: 0.78, green: 0.89, blue: 0.99, alpha: 1.0).cgColor,
        NSColor(red: 0.58, green: 0.78, blue: 0.97, alpha: 1.0).cgColor
    ] as CFArray
    if let bGrad = CGGradient(colorsSpace: cs, colors: baseColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(bGrad, start: CGPoint(x: 300, y: 700), end: CGPoint(x: 700, y: 300), options: [])
    }
    cg.restoreGState()
    
    // 2. Active Top-Right 75° Sector (Shifted +22px along +45° vector — representing Selected Default)
    let activeCenter = CGPoint(x: center.x + 22, y: center.y + 22)
    let activeArc = CGMutablePath()
    activeArc.addArc(
        center: activeCenter,
        radius: ringR,
        startAngle: 16.0 * .pi / 180.0,
        endAngle: 74.0 * .pi / 180.0,
        clockwise: false
    )
    let strokedActiveArc = activeArc.copy(strokingWithWidth: ringStroke, lineCap: .round, lineJoin: .round, miterLimit: 10)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor(red: 0.0, green: 0.35, blue: 0.95, alpha: 0.28).cgColor)
    cg.addPath(strokedActiveArc)
    cg.clip()
    let activeColors = [
        NSColor(red: 0.08, green: 0.52, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.0, green: 0.34, blue: 0.90, alpha: 1.0).cgColor
    ] as CFArray
    if let aGrad = CGGradient(colorsSpace: cs, colors: activeColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(aGrad, start: CGPoint(x: 500, y: 750), end: CGPoint(x: 750, y: 500), options: [])
    }
    cg.restoreGState()
    
    // 3. Central Precision Core Dot (Solid Royal Blue)
    let coreR: CGFloat = 58
    let coreRect = NSRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2)
    let corePath = NSBezierPath(ovalIn: coreRect)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor(red: 0.0, green: 0.30, blue: 0.85, alpha: 0.24).cgColor)
    let coreColors = [
        NSColor(red: 0.05, green: 0.48, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.0, green: 0.32, blue: 0.88, alpha: 1.0).cgColor
    ] as CFArray
    if let cGrad = CGGradient(colorsSpace: cs, colors: coreColors, locations: [0.0, 1.0]) {
        cg.saveGState()
        corePath.addClip()
        cg.drawLinearGradient(cGrad, start: CGPoint(x: coreRect.minX, y: coreRect.maxY), end: CGPoint(x: coreRect.maxX, y: coreRect.minY), options: [])
        cg.restoreGState()
    }
    cg.restoreGState()
    
    cg.restoreGState() // end squircle clip
    NSGraphicsContext.restoreGraphicsState()
    savePNG(rep, to: outputPath)
}

let outDir = "/Users/w_ood/.gemini/antigravity/brain/859e3715-c92b-4df3-8b48-318f982ebef6"
generateConcept1_OrigamiWing(outputPath: "\(outDir)/concept1_wing.png")
generateConcept2_RibbonD(outputPath: "\(outDir)/concept2_ribbon_d.png")
generateConcept3_SwissQuadrant(outputPath: "\(outDir)/concept3_focus.png")
