import AppKit
import EdgeTapCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBarController = StatusBarController()
    private let gestureEngine = GestureEngine()
    private let demoActionExecutor = DemoActionExecutor()
    private let multitouchManager = MultitouchManager()
    private let settings = AppSettings()
    private lazy var settingsWindowController = SettingsWindowController(settings: settings)

    private var isMonitoring = false
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController.install()
        statusBarController.onOpenSettings = { [weak self] in
            self?.settingsWindowController.show()
        }
        statusBarController.onQuit = {
            NSApplication.shared.terminate(nil)
        }
        settingsWindowController.onSettingsChanged = { [weak self] settings in
            self?.applySettings(settings)
        }

        gestureEngine.onGesture = { [weak self] event in
            Task { @MainActor in
                self?.demoActionExecutor.perform(event: event)
            }
        }

        applySettings(settings)
    }

    private func startMonitoring() {
        let result = multitouchManager.start { [weak self] contacts, timestamp in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                self.settingsWindowController.updateTouches(contacts)



                self.gestureEngine.process(contacts: contacts, timestamp: timestamp)
            }
        }

        isMonitoring = result.started
        if !result.started {
            print("[EdgeTap] \(result.message)")
            settings.monitoringEnabled = false
            settingsWindowController.onSettingsChanged?(settings)
        } else {
            if activity == nil {
                activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "EdgeTap Continuous Multitouch Observation")
            }
            print("[EdgeTap] Monitoring started")
        }
    }

    private func stopMonitoring() {
        multitouchManager.stop()
        gestureEngine.reset()
        isMonitoring = false
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        print("[EdgeTap] Monitoring stopped")
    }

    private func applySettings(_ settings: AppSettings) {
        gestureEngine.updateConfiguration(settings.detectorConfiguration)
        demoActionExecutor.updateBindings(settings.actionBindings, edgeActionTypes: settings.edgeActionTypes)

        statusBarController.refreshMenu()

        if settings.monitoringEnabled && !isMonitoring {
            startMonitoring()
        } else if !settings.monitoringEnabled && isMonitoring {
            stopMonitoring()
        }
    }
}
