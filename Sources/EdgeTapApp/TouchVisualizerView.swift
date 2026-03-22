import AppKit
import EdgeTapCore

@MainActor
final class TouchVisualizerView: NSView {
    var touches: [TouchContact] = [] {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    var activeSection: Int = 0 {
        didSet {
            needsDisplay = true
        }
    }

    var edgeThreshold: Double = 1.45 {
        didSet {
            needsDisplay = true
        }
    }

    var triggerDelta: Double = 0.12 {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        drawBackground()
        drawActiveZones()
        drawGrid()
        drawTouches()
    }

    private func drawActiveZones() {
        let highlightColor = NSColor.controlAccentColor.withAlphaComponent(0.3)
        let strokeColor = NSColor.controlAccentColor
        
        let xInset = CGFloat(edgeThreshold / 10.0)
        let yInset = xInset * 1.6 // Assume ~1.6:1 aspect ratio for physical consistency
        let cornerX = xInset
        let cornerY = yInset
        
        let visualWidth = bounds.width
        let visualHeight = bounds.height
        
        // --- Draw overall "Active Sensitivity Zone" (the thin border that counts as an edge) ---
        let zoneOverlayPath = NSBezierPath()
        
        // Left
        zoneOverlayPath.append(NSBezierPath(rect: CGRect(x: 0, y: 0, width: xInset * visualWidth, height: visualHeight)))
        // Right
        zoneOverlayPath.append(NSBezierPath(rect: CGRect(x: visualWidth * (1.0 - xInset), y: 0, width: xInset * visualWidth, height: visualHeight)))
        // Top
        zoneOverlayPath.append(NSBezierPath(rect: CGRect(x: 0, y: 0, width: visualWidth, height: yInset * visualHeight)))
        // Bottom
        zoneOverlayPath.append(NSBezierPath(rect: CGRect(x: 0, y: visualHeight * (1.0 - yInset), width: visualWidth, height: yInset * visualHeight)))
        
        NSColor.controlAccentColor.withAlphaComponent(0.08).setFill()
        zoneOverlayPath.fill()

        // --- Highlight the currently selected section ---
        var highlightPaths: [NSBezierPath] = []
        
        switch activeSection {
        case 0: // Top
            let rect = CGRect(x: 0, y: 0, width: visualWidth, height: yInset * visualHeight)
            highlightPaths.append(NSBezierPath(rect: rect))
        case 1: // Bottom
            let rect = CGRect(x: 0, y: visualHeight * (1.0 - yInset), width: visualWidth, height: yInset * visualHeight)
            highlightPaths.append(NSBezierPath(rect: rect))
        case 2: // Left
            let rect = CGRect(x: 0, y: 0, width: xInset * visualWidth, height: visualHeight)
            highlightPaths.append(NSBezierPath(rect: rect))
        case 3: // Right
            let rect = CGRect(x: visualWidth * (1.0 - xInset), y: 0, width: xInset * visualWidth, height: visualHeight)
            highlightPaths.append(NSBezierPath(rect: rect))
        case 4: // Corners
            highlightPaths.append(NSBezierPath(rect: CGRect(x: 0, y: 0, width: cornerX * visualWidth, height: cornerY * visualHeight))) // Top-Left
            highlightPaths.append(NSBezierPath(rect: CGRect(x: visualWidth * (1.0 - cornerX), y: 0, width: cornerX * visualWidth, height: cornerY * visualHeight))) // Top-Right
            highlightPaths.append(NSBezierPath(rect: CGRect(x: 0, y: visualHeight * (1.0 - cornerY), width: cornerX * visualWidth, height: cornerY * visualHeight))) // Bottom-Left
            highlightPaths.append(NSBezierPath(rect: CGRect(x: visualWidth * (1.0 - cornerX), y: visualHeight * (1.0 - cornerY), width: cornerX * visualWidth, height: cornerY * visualHeight))) // Bottom-Right
        default:
            break
        }

        for path in highlightPaths {
            highlightColor.setFill()
            path.fill()
            strokeColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
        
        // --- Draw Trigger Delta (movement threshold indicators) ---
        drawTriggerDeltaIndicators(xInset: xInset, yInset: yInset)
    }

    private func drawTriggerDeltaIndicators(xInset: CGFloat, yInset: CGFloat) {
        let visualWidth = bounds.width
        let visualHeight = bounds.height
        let delta = CGFloat(triggerDelta)
        let deltaColor = NSColor.systemOrange.withAlphaComponent(0.4)
        
        // Draw some dashed lines to show how far you have to slide
        let dashPath = NSBezierPath()
        dashPath.setLineDash([4, 4], count: 2, phase: 0)
        dashPath.lineWidth = 1
        
        if activeSection == 2 || activeSection == 3 { // Left or Right edges (vertical swipes)
            // Show horizontal bands for vertical travel required
            let startY: CGFloat = visualHeight * 0.2 // arbitrary center-ish point
            dashPath.move(to: CGPoint(x: 0, y: startY))
            dashPath.line(to: CGPoint(x: visualWidth, y: startY))
            
            dashPath.move(to: CGPoint(x: 0, y: startY + delta * visualHeight))
            dashPath.line(to: CGPoint(x: visualWidth, y: startY + delta * visualHeight))
        } else if activeSection == 0 || activeSection == 1 { // Top or Bottom edges (horizontal swipes)
            let startX: CGFloat = visualWidth * 0.2
            dashPath.move(to: CGPoint(x: startX, y: 0))
            dashPath.line(to: CGPoint(x: startX, y: visualHeight))
            
            dashPath.move(to: CGPoint(x: startX + delta * visualWidth, y: 0))
            dashPath.line(to: CGPoint(x: startX + delta * visualWidth, y: visualHeight))
        }
        
        deltaColor.setStroke()
        dashPath.stroke()
    }

    private func drawBackground() {
        let roundedRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let fillPath = NSBezierPath(roundedRect: roundedRect, xRadius: 10, yRadius: 10)
        let gradient = NSGradient(colors: [
            NSColor.windowBackgroundColor.blended(withFraction: 0.30, of: .controlBackgroundColor) ?? .windowBackgroundColor,
            NSColor.controlBackgroundColor.blended(withFraction: 0.12, of: .black) ?? .controlBackgroundColor,
        ])
        gradient?.draw(in: fillPath, angle: 90)

        NSColor.separatorColor.withAlphaComponent(0.9).setStroke()
        fillPath.lineWidth = 1
        fillPath.stroke()
    }

    private func drawGrid() {
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 1

        let thirdWidth = bounds.width / 3
        let thirdHeight = bounds.height / 3

        for index in 1...2 {
            let x = thirdWidth * CGFloat(index)
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.line(to: CGPoint(x: x, y: bounds.height))
        }

        for index in 1...2 {
            let y = thirdHeight * CGFloat(index)
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.line(to: CGPoint(x: bounds.width, y: y))
        }

        NSColor.separatorColor.withAlphaComponent(0.28).setStroke()
        gridPath.stroke()

        drawHeaderLabel("Left", x: 14, emphasized: false)
        drawHeaderLabel("Center", x: bounds.midX - 22, emphasized: false)
        drawHeaderLabel("Gesture Zone", x: bounds.width - 104, emphasized: true)
    }

    private func drawHeaderLabel(_ text: String, x: CGFloat, emphasized: Bool) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: emphasized ? .semibold : .medium),
            .foregroundColor: emphasized
                ? NSColor.controlAccentColor
                : NSColor.secondaryLabelColor,
        ]
        NSString(string: text).draw(at: CGPoint(x: x, y: 12), withAttributes: attributes)
    }

    private func drawTouches() {
        for touch in touches {
            let point = CGPoint(
                x: bounds.width * CGFloat(clamped(touch.x)),
                y: bounds.height * CGFloat(1 - clamped(touch.y))
            )

            let radius = max(10, min(24, CGFloat(touch.size * 22)))
            let haloRect = CGRect(
                x: point.x - radius * 1.6,
                y: point.y - radius * 1.6,
                width: radius * 3.2,
                height: radius * 3.2
            )
            let touchRect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            let haloGradient = NSGradient(colors: [
                NSColor.systemOrange.withAlphaComponent(0.28),
                NSColor.systemOrange.withAlphaComponent(0.05),
            ])
            haloGradient?.draw(in: NSBezierPath(ovalIn: haloRect), relativeCenterPosition: .zero)

            NSColor.systemOrange.withAlphaComponent(0.92).setFill()
            NSBezierPath(ovalIn: touchRect).fill()

            NSColor.white.withAlphaComponent(0.32).setStroke()
            let stroke = NSBezierPath(ovalIn: touchRect.insetBy(dx: 1, dy: 1))
            stroke.lineWidth = 1
            stroke.stroke()

            drawTouchLabel("id \(touch.identifier)", origin: CGPoint(x: point.x + radius + 8, y: point.y - 11))
        }
    }

    private func drawTouchLabel(_ text: String, origin: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .backgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.82),
        ]
        NSString(string: text).draw(at: origin, withAttributes: attributes)
    }

    private func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
