import AppKit
import SwiftUI

@MainActor
class ToastManager {
    static let shared = ToastManager()
    
    private var window: NSPanel?
    private var hideWorkItem: DispatchWorkItem?
    
    private init() {}
    
    func show(message: String) {
        // Cancel previous hide task if any
        hideWorkItem?.cancel()
        
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            
            // Allow materials to shine through
            panel.isOpaque = false
            
            window = panel
        }
        
        let contentView = NSHostingView(rootView: ToastView(message: message))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window?.contentView = contentView
        
        let fittingSize = contentView.intrinsicContentSize
        window?.setFrame(NSRect(x: 0, y: 0, width: fittingSize.width + 40, height: fittingSize.height + 40), display: true)
        
        positionWindow(isInitial: window?.alphaValue == 0)
        
        window?.orderFrontRegardless()
        
        // Start fade/slide animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1.0
            positionWindow(isInitial: false)
        })
        
        // Auto-hide after 2.5 seconds
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
            context.duration = 0.6
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window?.animator().alphaValue = 0.0
            // Slide down slightly while fading out
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
        let padding: CGFloat = isInitial ? 40 : 80 // Initial position is slightly lower
        
        let windowFrame = window.frame
        let newX = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
        let newY = screenFrame.origin.y + padding
        
        window.setFrameOrigin(NSPoint(x: newX, y: newY))
    }
}
