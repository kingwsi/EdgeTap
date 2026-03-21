import AppKit
import CoreGraphics

func createSquirclePath(in rect: NSRect) -> NSBezierPath {
    let path = NSBezierPath()
    let radius = rect.width * 0.225
    path.appendRoundedRect(rect, xRadius: radius, yRadius: radius)
    return path
}

func drawIcon(size: CGFloat) -> NSImage {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let image = NSImage(size: rect.size)
    image.lockFocus()

    // 1. Draw base squircle
    let inset: CGFloat = size * 0.08
    let squircleRect = rect.insetBy(dx: inset, dy: inset)
    let squirclePath = createSquirclePath(in: squircleRect)
    
    NSGraphicsContext.current?.saveGraphicsState()
    
    // Add shadow
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
    shadow.shadowOffset = NSSize(width: 0, height: -size*0.02)
    shadow.shadowBlurRadius = size*0.04
    shadow.set()
    
    let gradient = NSGradient(colors: [NSColor(calibratedWhite: 0.24, alpha: 1.0), NSColor(calibratedWhite: 0.12, alpha: 1.0)])!
    gradient.draw(in: squirclePath, angle: -90)
    
    NSGraphicsContext.current?.restoreGraphicsState()
    
    // Draw Squircle border
    NSGraphicsContext.current?.saveGraphicsState()
    NSColor(calibratedWhite: 0.35, alpha: 1.0).setStroke()
    squirclePath.lineWidth = size * 0.004
    squirclePath.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()

    // 2. Draw Trackpad Surface
    let innerPadRect = NSRect(
        x: squircleRect.minX + squircleRect.width * 0.15,
        y: squircleRect.minY + squircleRect.height * 0.25,
        width: squircleRect.width * 0.7,
        height: squircleRect.height * 0.5
    )
    let padPath = NSBezierPath(roundedRect: innerPadRect, xRadius: size*0.04, yRadius: size*0.04)
    
    let innerGradient = NSGradient(colors: [NSColor(calibratedWhite: 0.16, alpha: 1.0), NSColor(calibratedWhite: 0.24, alpha: 1.0)])!
    innerGradient.draw(in: padPath, angle: -90)
    
    NSColor(calibratedWhite: 0.35, alpha: 1.0).setStroke()
    padPath.lineWidth = size * 0.006
    padPath.stroke()
    
    // 3. Draw Highlights
    // Left edge (Blue)
    let leftGlowRect = NSRect(
        x: innerPadRect.minX - size*0.006,
        y: innerPadRect.minY + innerPadRect.height*0.2, 
        width: size*0.012,
        height: innerPadRect.height*0.7
    )
    let leftGlowPath = NSBezierPath(roundedRect: leftGlowRect, xRadius: size*0.006, yRadius: size*0.006)
    
    NSGraphicsContext.current?.saveGraphicsState()
    let blueShadow = NSShadow()
    blueShadow.shadowColor = NSColor.systemBlue.withAlphaComponent(0.8)
    blueShadow.shadowOffset = .zero
    blueShadow.shadowBlurRadius = size*0.02
    blueShadow.set()
    let blueGradient = NSGradient(colors: [NSColor.systemBlue.withAlphaComponent(0.6), NSColor.systemBlue])!
    blueGradient.draw(in: leftGlowPath, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Bottom edge (Green)
    let bottomGlowRect = NSRect(
        x: innerPadRect.minX + innerPadRect.width*0.1,
        y: innerPadRect.minY - size*0.006,
        width: innerPadRect.width*0.8,
        height: size*0.012
    )
    let bottomGlowPath = NSBezierPath(roundedRect: bottomGlowRect, xRadius: size*0.006, yRadius: size*0.006)
    
    NSGraphicsContext.current?.saveGraphicsState()
    let greenShadow = NSShadow()
    greenShadow.shadowColor = NSColor.systemGreen.withAlphaComponent(0.8)
    greenShadow.shadowOffset = .zero
    greenShadow.shadowBlurRadius = size*0.02
    greenShadow.set()
    let greenGradient = NSGradient(colors: [NSColor.systemGreen.withAlphaComponent(0.6), NSColor.systemGreen])!
    greenGradient.draw(in: bottomGlowPath, angle: 0)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Draw little arrow icons
    NSColor.systemBlue.setStroke()
    let upArrow = NSBezierPath()
    let arwX = leftGlowRect.minX - size*0.03
    let arwY = leftGlowRect.midY + size*0.05
    upArrow.move(to: NSPoint(x: arwX, y: arwY - size*0.08))
    upArrow.line(to: NSPoint(x: arwX, y: arwY))
    upArrow.line(to: NSPoint(x: arwX - size*0.02, y: arwY - size*0.02))
    upArrow.move(to: NSPoint(x: arwX, y: arwY))
    upArrow.line(to: NSPoint(x: arwX + size*0.02, y: arwY - size*0.02))
    upArrow.lineWidth = size*0.01
    upArrow.lineCapStyle = .round
    upArrow.lineJoinStyle = .round
    upArrow.stroke()
    
    NSColor.systemGreen.setStroke()
    let rightArrow = NSBezierPath()
    let grwX = bottomGlowRect.midY + size*0.2
    let grwY = bottomGlowRect.minY - size*0.03
    rightArrow.move(to: NSPoint(x: grwX - size*0.08, y: grwY))
    rightArrow.line(to: NSPoint(x: grwX, y: grwY))
    rightArrow.line(to: NSPoint(x: grwX - size*0.02, y: grwY + size*0.02))
    rightArrow.move(to: NSPoint(x: grwX, y: grwY))
    rightArrow.line(to: NSPoint(x: grwX - size*0.02, y: grwY - size*0.02))
    rightArrow.lineWidth = size*0.01
    rightArrow.lineCapStyle = .round
    rightArrow.lineJoinStyle = .round
    rightArrow.stroke()

    image.unlockFocus()
    return image
}

let image = drawIcon(size: 1024)
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render icon")
}

let outPath = "/Users/geek/projects/EdgeTap/Sources/EdgeTapApp/Resources/AppIcon.png"
let url = URL(fileURLWithPath: outPath)
try! pngData.write(to: url)
print("Saved AppIcon.png")
