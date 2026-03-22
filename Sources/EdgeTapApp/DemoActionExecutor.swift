import Foundation
import EdgeTapCore

struct DemoActionBinding: Sendable {
    let enabled: Bool
    let shortcut: ShortcutBinding?
    let rawShortcut: String
    let mediaAction: MediaAction
}

@MainActor
final class DemoActionExecutor {
    var onStatusUpdate: ((String) -> Void)?

    private let logURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library")
        .appending(path: "Logs")
        .appending(path: "EdgeTapDemo.log")
    private let shortcutExecutor = ShortcutExecutor()
    private var actionBindings: [GestureActionKey: DemoActionBinding] = DemoActionExecutor.defaultBindings()
    private var edgeActionTypes: [String: EdgeActionType] = [:]

    func updateBindings(_ bindings: [GestureActionKey: DemoActionBinding], edgeActionTypes: [String: EdgeActionType]) {
        self.actionBindings = bindings
        self.edgeActionTypes = edgeActionTypes
    }

    func perform(event: GestureEvent) {
        let key = event.actionKey
        let binding = actionBindings[key]
        let output = description(for: event, binding: binding)

        print("[EdgeTap] gesture \(output)")
        onStatusUpdate?(output)
        appendLogLine(output)

        if case let .edgeSwipe(edge, direction, _) = event, edgeActionTypes[edge.rawValue] == .continuousVolume {
            let isVolumeUp = (edge == .left || edge == .right) ? direction == .up : direction == .right
            let mediaAction: MediaAction = isVolumeUp ? .volumeUp : .volumeDown
            if shortcutExecutor.performMediaAction(mediaAction) {
                print("[EdgeTap] continuous volume \(mediaAction.displayName)")
                ToastManager.shared.show(message: mediaAction.displayName)
            }
            return
        }

        guard let binding, binding.enabled else {
            return
        }

        if binding.mediaAction != .none {
            if shortcutExecutor.performMediaAction(binding.mediaAction) {
                print("[EdgeTap] media action executed \(binding.mediaAction.displayName)")
                appendLogLine("Executed media action \(binding.mediaAction.displayName)")
                ToastManager.shared.show(message: binding.mediaAction.displayName)
            } else {
                print("[EdgeTap] media action failed \(binding.mediaAction.displayName)")
                appendLogLine("Failed to execute media action \(binding.mediaAction.displayName)")
            }
            return
        }

        guard let shortcut = binding.shortcut else {
            return
        }

        if shortcutExecutor.perform(shortcut) {
            print("[EdgeTap] shortcut executed \(shortcut.displayString)")
            appendLogLine("Executed shortcut \(shortcut.displayString)")
            ToastManager.shared.show(message: shortcut.displayString)
        } else {
            print("[EdgeTap] shortcut failed \(shortcut.displayString)")
            appendLogLine("Failed to execute shortcut \(shortcut.displayString)")
        }
    }

    private func appendLogLine(_ message: String) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        let data = Data(line.utf8)

        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if FileManager.default.fileExists(atPath: logURL.path) {
            guard let handle = try? FileHandle(forWritingTo: logURL) else {
                return
            }

            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            return
        }

        try? data.write(to: logURL)
    }

    private func description(for event: GestureEvent, binding: DemoActionBinding?) -> String {
        let actionText = bindingDescription(binding)
        switch event {
        case let .edgeSwipe(edge, direction, magnitude):
            return String(format: Localization.get("GESTURE_EDGE_SWIPE_FORMAT"), edge.rawValue, direction.rawValue, String(format: "%.3f", magnitude), actionText)
        case let .cornerTap(corner):
            return String(format: Localization.get("GESTURE_CORNER_TAP_FORMAT"), corner.rawValue, actionText)
        }
    }

    private func bindingDescription(_ binding: DemoActionBinding?) -> String {
        guard let binding else {
            return Localization.get("ACTION_NONE")
        }

        if binding.mediaAction != .none {
            return binding.mediaAction.displayName
        }

        return binding.rawShortcut.isEmpty ? Localization.get("ACTION_NONE") : binding.rawShortcut
    }

    private static func defaultBindings() -> [GestureActionKey: DemoActionBinding] {
        [
            .leftEdgeUp: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("cmd+option+left"), rawShortcut: "cmd+option+left", mediaAction: .none),
            .leftEdgeDown: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("cmd+option+right"), rawShortcut: "cmd+option+right", mediaAction: .none),
            .rightEdgeUp: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("cmd+shift+up"), rawShortcut: "cmd+shift+up", mediaAction: .none),
            .rightEdgeDown: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("cmd+shift+down"), rawShortcut: "cmd+shift+down", mediaAction: .none),
            .topEdgeLeft: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("cmd+left"), rawShortcut: "cmd+left", mediaAction: .none),
            .topEdgeRight: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("cmd+right"), rawShortcut: "cmd+right", mediaAction: .none),
            .bottomEdgeLeft: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("ctrl+left"), rawShortcut: "ctrl+left", mediaAction: .none),
            .bottomEdgeRight: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("ctrl+right"), rawShortcut: "ctrl+right", mediaAction: .none),
            .topLeftCornerTap: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("cmd+shift+1"), rawShortcut: "cmd+shift+1", mediaAction: .none),
            .topRightCornerTap: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("cmd+shift+2"), rawShortcut: "cmd+shift+2", mediaAction: .none),
            .bottomLeftCornerTap: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("cmd+shift+3"), rawShortcut: "cmd+shift+3", mediaAction: .none),
            .bottomRightCornerTap: DemoActionBinding(enabled: false, shortcut: ShortcutBinding("cmd+shift+4"), rawShortcut: "cmd+shift+4", mediaAction: .none),
        ]
    }
}
