import AppKit

@MainActor
final class ToastManager {
    static let shared = ToastManager()

    private var window: NSPanel?
    private var hideWorkItem: DispatchWorkItem?
    private let iconView = NSImageView()
    private let iconBackgroundView = NSView()
    private let messageLabel = NSTextField(labelWithString: "")

    private init() {}

    func show(message: String) {
        hideWorkItem?.cancel()

        if window == nil {
            window = makePanel()
        }

        messageLabel.stringValue = message
        iconView.image = NSImage(
            systemSymbolName: "checkmark",
            accessibilityDescription: nil
        )

        guard let window else { return }
        let fittingSize = window.contentView?.fittingSize ?? NSSize(width: 240, height: 72)
        window.setContentSize(fittingSize)
        positionWindow(isInitial: window.alphaValue == 0)

        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
            positionWindow(isInitial: false)
        })

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.hide()
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }

    private func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window?.animator().alphaValue = 0.0
            let frame = window?.frame ?? .zero
            window?.animator().setFrameOrigin(NSPoint(x: frame.origin.x, y: frame.origin.y - 10))
        }, completionHandler: {
            Task { @MainActor in
                if self.window?.alphaValue == 0 {
                    self.window?.orderOut(nil)
                }
            }
        })
    }

    private func positionWindow(isInitial: Bool) {
        guard let window = window, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let padding: CGFloat = isInitial ? 40 : 80

        let windowFrame = window.frame
        let newX = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
        let newY = screenFrame.origin.y + padding

        window.setFrameOrigin(NSPoint(x: newX, y: newY))
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 52),
            styleMask: [.nonactivatingPanel, .hudWindow, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.alphaValue = 0
        panel.appearance = NSAppearance(named: .vibrantDark)
        panel.contentView = makeContentView()
        return panel
    }

    private func makeContentView() -> NSView {
        configureContentViews()
        return makeHUDToastView()
    }

    private func configureContentViews() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        iconView.contentTintColor = NSColor.white.withAlphaComponent(0.98)
        iconView.imageScaling = .scaleProportionallyDown

        iconBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        iconBackgroundView.wantsLayer = true
        iconBackgroundView.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.98).cgColor
        iconBackgroundView.layer?.cornerRadius = 12
        iconBackgroundView.addSubview(iconView)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
            iconBackgroundView.widthAnchor.constraint(equalToConstant: 24),
            iconBackgroundView.heightAnchor.constraint(equalToConstant: 24),
            iconView.widthAnchor.constraint(equalToConstant: 13),
            iconView.heightAnchor.constraint(equalToConstant: 13)
        ])

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 17, weight: .bold)
        messageLabel.textColor = NSColor.white.withAlphaComponent(0.96)
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.maximumNumberOfLines = 1
        messageLabel.alignment = .left
    }

    private func makeHUDToastView() -> NSView {
        let stack = makeStackView()
        let effectView = NSVisualEffectView(frame: .zero)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 24
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        effectView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -12),
            effectView.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            effectView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])

        let rootView = NSView(frame: .zero)
        rootView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(effectView)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: rootView.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])

        return rootView
    }

    private func makeStackView() -> NSStackView {
        let stack = NSStackView(views: [iconBackgroundView, messageLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12

        return stack
    }
}
