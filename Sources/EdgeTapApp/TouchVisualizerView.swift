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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        drawBackground()
        drawGrid()
        drawTouches()
    }

    private func drawBackground() {
        let roundedRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let fillPath = NSBezierPath(roundedRect: roundedRect, xRadius: 10, yRadius: 10)
        let gradient = NSGradient(colors: [
            NSColor.windowBackgroundColor.blended(withFraction: 0.30, of: .controlBackgroundColor) ?? .windowBackgroundColor,
            NSColor.controlBackgroundColor.blended(withFraction: 0.12, of: .black) ?? .controlBackgroundColor,
        ])
        gradient?.draw(in: fillPath, angle: 90)

        let captureZoneRect = CGRect(x: bounds.width * (2.0 / 3.0), y: 0, width: bounds.width / 3.0, height: bounds.height)
        let captureZonePath = NSBezierPath(rect: captureZoneRect)
        NSColor.controlAccentColor.withAlphaComponent(0.08).setFill()
        captureZonePath.fill()

        NSColor.white.withAlphaComponent(0.04).setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * 0.32)).fill()

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
