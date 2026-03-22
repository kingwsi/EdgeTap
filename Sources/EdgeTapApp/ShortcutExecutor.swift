import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

struct ShortcutBinding: Sendable {
    let displayString: String
    let keyCode: CGKeyCode
    let modifierFlags: CGEventFlags

    init?(_ shortcutString: String) {
        let tokens = ShortcutBinding.tokenize(shortcutString)

        guard let keyToken = tokens.last else {
            return nil
        }

        let modifiers = Set(tokens.dropLast())
        guard let keyCode = ShortcutKeyMap[keyToken] else {
            return nil
        }

        self.displayString = shortcutString
        self.keyCode = keyCode
        self.modifierFlags = modifiers.reduce(into: []) { flags, modifier in
            flags.formUnion(ShortcutModifierMap[modifier] ?? [])
        }
    }

    private static func tokenize(_ shortcutString: String) -> [String] {
        let normalized = shortcutString
            .replacingOccurrences(of: "⌘", with: "cmd+")
            .replacingOccurrences(of: "⇧", with: "shift+")
            .replacingOccurrences(of: "⌥", with: "option+")
            .replacingOccurrences(of: "⌃", with: "ctrl+")
            .replacingOccurrences(of: "-", with: "+")

        return normalized
            .split(separator: "+")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
}

extension ShortcutBinding {
    static func makeDisplayString(keyCode: CGKeyCode, modifierFlags: NSEvent.ModifierFlags) -> String? {
        guard let key = ReverseShortcutKeyMap[keyCode] else {
            return nil
        }

        let pieces = modifierSymbols(for: modifierFlags) + [displayKey(for: key)]
        return pieces.joined()
    }

    static func modifierSymbols(for flags: NSEvent.ModifierFlags) -> [String] {
        var result: [String] = []

        if flags.contains(.command) {
            result.append("⌘")
        }
        if flags.contains(.option) {
            result.append("⌥")
        }
        if flags.contains(.control) {
            result.append("⌃")
        }
        if flags.contains(.shift) {
            result.append("⇧")
        }

        return result
    }

    private static func displayKey(for token: String) -> String {
        switch token {
        case "left":
            return "←"
        case "right":
            return "→"
        case "up":
            return "↑"
        case "down":
            return "↓"
        case "return", "enter":
            return "↩"
        case "tab":
            return "⇥"
        case "escape", "esc":
            return "⎋"
        case "delete":
            return "⌫"
        case "space":
            return "Space"
        default:
            return token.uppercased()
        }
    }
}

final class ShortcutExecutor {
    func perform(_ binding: ShortcutBinding) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: binding.keyCode,
            keyDown: true
        ),
        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: binding.keyCode,
            keyDown: false
        ) else {
            return false
        }

        keyDown.flags = binding.modifierFlags
        keyUp.flags = binding.modifierFlags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    func performMediaAction(_ mediaAction: MediaAction) -> Bool {
        let keyCode: Int32

        switch mediaAction {
        case .none:
            return false
        case .volumeUp:
            keyCode = 0
        case .volumeDown:
            keyCode = 1
        case .mute:
            keyCode = 7
        }

        return postMediaKey(keyCode) && postMediaKey(keyCode, isKeyDown: false)
    }

    private func postMediaKey(_ keyCode: Int32, isKeyDown: Bool = true) -> Bool {
        let eventFlags = NSEvent.ModifierFlags(rawValue: isKeyDown ? 0xA00 : 0xB00)
        let data1 = Int((keyCode << 16) | ((isKeyDown ? 0xA : 0xB) << 8))

        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: eventFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else {
            return false
        }

        event.cgEvent?.post(tap: .cghidEventTap)
        return true
    }
}

private let ShortcutModifierMap: [String: CGEventFlags] = [
    "cmd": .maskCommand,
    "command": .maskCommand,
    "ctrl": .maskControl,
    "control": .maskControl,
    "opt": .maskAlternate,
    "option": .maskAlternate,
    "alt": .maskAlternate,
    "shift": .maskShift,
]

private let ShortcutKeyMap: [String: CGKeyCode] = [
    "a": CGKeyCode(kVK_ANSI_A),
    "b": CGKeyCode(kVK_ANSI_B),
    "c": CGKeyCode(kVK_ANSI_C),
    "d": CGKeyCode(kVK_ANSI_D),
    "e": CGKeyCode(kVK_ANSI_E),
    "f": CGKeyCode(kVK_ANSI_F),
    "g": CGKeyCode(kVK_ANSI_G),
    "h": CGKeyCode(kVK_ANSI_H),
    "i": CGKeyCode(kVK_ANSI_I),
    "j": CGKeyCode(kVK_ANSI_J),
    "k": CGKeyCode(kVK_ANSI_K),
    "l": CGKeyCode(kVK_ANSI_L),
    "m": CGKeyCode(kVK_ANSI_M),
    "n": CGKeyCode(kVK_ANSI_N),
    "o": CGKeyCode(kVK_ANSI_O),
    "p": CGKeyCode(kVK_ANSI_P),
    "q": CGKeyCode(kVK_ANSI_Q),
    "r": CGKeyCode(kVK_ANSI_R),
    "s": CGKeyCode(kVK_ANSI_S),
    "t": CGKeyCode(kVK_ANSI_T),
    "u": CGKeyCode(kVK_ANSI_U),
    "v": CGKeyCode(kVK_ANSI_V),
    "w": CGKeyCode(kVK_ANSI_W),
    "x": CGKeyCode(kVK_ANSI_X),
    "y": CGKeyCode(kVK_ANSI_Y),
    "z": CGKeyCode(kVK_ANSI_Z),
    "0": CGKeyCode(kVK_ANSI_0),
    "1": CGKeyCode(kVK_ANSI_1),
    "2": CGKeyCode(kVK_ANSI_2),
    "3": CGKeyCode(kVK_ANSI_3),
    "4": CGKeyCode(kVK_ANSI_4),
    "5": CGKeyCode(kVK_ANSI_5),
    "6": CGKeyCode(kVK_ANSI_6),
    "7": CGKeyCode(kVK_ANSI_7),
    "8": CGKeyCode(kVK_ANSI_8),
    "9": CGKeyCode(kVK_ANSI_9),
    "space": CGKeyCode(kVK_Space),
    "return": CGKeyCode(kVK_Return),
    "enter": CGKeyCode(kVK_Return),
    "↩": CGKeyCode(kVK_Return),
    "tab": CGKeyCode(kVK_Tab),
    "⇥": CGKeyCode(kVK_Tab),
    "escape": CGKeyCode(kVK_Escape),
    "esc": CGKeyCode(kVK_Escape),
    "⎋": CGKeyCode(kVK_Escape),
    "delete": CGKeyCode(kVK_Delete),
    "⌫": CGKeyCode(kVK_Delete),
    "left": CGKeyCode(kVK_LeftArrow),
    "←": CGKeyCode(kVK_LeftArrow),
    "right": CGKeyCode(kVK_RightArrow),
    "→": CGKeyCode(kVK_RightArrow),
    "up": CGKeyCode(kVK_UpArrow),
    "↑": CGKeyCode(kVK_UpArrow),
    "down": CGKeyCode(kVK_DownArrow),
    "↓": CGKeyCode(kVK_DownArrow),
    "f1": CGKeyCode(kVK_F1),
    "f2": CGKeyCode(kVK_F2),
    "f3": CGKeyCode(kVK_F3),
    "f4": CGKeyCode(kVK_F4),
    "f5": CGKeyCode(kVK_F5),
    "f6": CGKeyCode(kVK_F6),
    "f7": CGKeyCode(kVK_F7),
    "f8": CGKeyCode(kVK_F8),
    "f9": CGKeyCode(kVK_F9),
    "f10": CGKeyCode(kVK_F10),
    "f11": CGKeyCode(kVK_F11),
    "f12": CGKeyCode(kVK_F12),
]

private let ReverseShortcutKeyMap: [CGKeyCode: String] = {
    var map: [CGKeyCode: String] = [:]
    for (token, keyCode) in ShortcutKeyMap {
        if map[keyCode] == nil {
            map[keyCode] = token
        }
    }
    return map
}()
