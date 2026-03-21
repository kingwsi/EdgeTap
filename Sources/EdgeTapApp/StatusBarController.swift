import AppKit

@MainActor
final class StatusBarController {
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private var statusItem: NSStatusItem?
    private let settingsItem = NSMenuItem(title: Localization.get("MENU_SETTINGS"), action: #selector(openSettings), keyEquivalent: ",")
    private let quitItem = NSMenuItem(title: Localization.get("MENU_QUIT"), action: #selector(quitApp), keyEquivalent: "q")

    func install() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = makeMenuBarIcon()
        statusItem.button?.imageScaling = .scaleProportionallyDown

        let menu = NSMenu()
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    func refreshMenu() {
        settingsItem.title = Localization.get("MENU_SETTINGS")
        quitItem.title = Localization.get("MENU_QUIT")
    }

    private func makeMenuBarIcon() -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let pad = NSRect(x: 2, y: 3, width: 14, height: 12)
            let padPath = NSBezierPath(roundedRect: pad, xRadius: 2.5, yRadius: 2.5)
            padPath.lineWidth = 1.2
            NSColor.black.setStroke()
            padPath.stroke()

            // Left edge highlight
            let leftEdge = NSBezierPath()
            leftEdge.move(to: NSPoint(x: 2, y: 5.5))
            leftEdge.line(to: NSPoint(x: 2, y: 12.5))
            leftEdge.lineWidth = 2.0
            leftEdge.lineCapStyle = .round
            NSColor.black.setStroke()
            leftEdge.stroke()

            // Bottom edge highlight
            let bottomEdge = NSBezierPath()
            bottomEdge.move(to: NSPoint(x: 4.5, y: 3))
            bottomEdge.line(to: NSPoint(x: 13.5, y: 3))
            bottomEdge.lineWidth = 2.0
            bottomEdge.lineCapStyle = .round
            NSColor.black.setStroke()
            bottomEdge.stroke()

            return true
        }

        image.isTemplate = true
        return image
    }

    @objc
    private func openSettings() {
        DispatchQueue.main.async { [weak self] in
            self?.onOpenSettings?()
        }
    }

    @objc
    private func quitApp() {
        onQuit?()
    }
}
