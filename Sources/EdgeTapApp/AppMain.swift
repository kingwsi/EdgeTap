import AppKit

@main
enum EdgeTapAppMain {
    @MainActor static var appDelegate: AppDelegate?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        appDelegate = AppDelegate()
        application.delegate = appDelegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}

