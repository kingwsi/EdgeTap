import AppKit

@MainActor
final class StatusBarController {
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private var statusItem: NSStatusItem?
    private let settingsItem = NSMenuItem(title: Localization.get("MENU_SETTINGS"), action: #selector(openSettings), keyEquivalent: ",")
    private let quitItem = NSMenuItem(title: Localization.get("MENU_QUIT"), action: #selector(quitApp), keyEquivalent: "q")

    func install() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = Localization.get("STATUS_BAR_TITLE")

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
        statusItem?.button?.title = Localization.get("STATUS_BAR_TITLE")
        settingsItem.title = Localization.get("MENU_SETTINGS")
        quitItem.title = Localization.get("MENU_QUIT")
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
