import Foundation
import EdgeTapCore

enum EdgeActionType: String, Codable, Sendable {
    case custom
    case continuousVolume
}
enum GestureShortcutSlot: String, CaseIterable, Codable, Sendable {
    case topEdgeSwipeLeft
    case topEdgeSwipeRight
    case bottomEdgeSwipeLeft
    case bottomEdgeSwipeRight
    case leftEdgeSwipeUp
    case leftEdgeSwipeDown
    case rightEdgeSwipeUp
    case rightEdgeSwipeDown
    case cornerTopLeft
    case cornerTopRight
    case cornerBottomLeft
    case cornerBottomRight

    var displayName: String {
        switch self {
        case .topEdgeSwipeLeft:
            return Localization.get("SLOT_TOP_LEFT")
        case .topEdgeSwipeRight:
            return Localization.get("SLOT_TOP_RIGHT")
        case .bottomEdgeSwipeLeft:
            return Localization.get("SLOT_BOTTOM_LEFT")
        case .bottomEdgeSwipeRight:
            return Localization.get("SLOT_BOTTOM_RIGHT")
        case .leftEdgeSwipeUp:
            return Localization.get("SLOT_LEFT_UP")
        case .leftEdgeSwipeDown:
            return Localization.get("SLOT_LEFT_DOWN")
        case .rightEdgeSwipeUp:
            return Localization.get("SLOT_RIGHT_UP")
        case .rightEdgeSwipeDown:
            return Localization.get("SLOT_RIGHT_DOWN")
        case .cornerTopLeft:
            return Localization.get("SLOT_CORNER_TOP_LEFT")
        case .cornerTopRight:
            return Localization.get("SLOT_CORNER_TOP_RIGHT")
        case .cornerBottomLeft:
            return Localization.get("SLOT_CORNER_BOTTOM_LEFT")
        case .cornerBottomRight:
            return Localization.get("SLOT_CORNER_BOTTOM_RIGHT")
        }
    }

    var sectionTitle: String {
        switch self {
        case .topEdgeSwipeLeft, .topEdgeSwipeRight:
            return Localization.get("SEGMENT_TOP")
        case .bottomEdgeSwipeLeft, .bottomEdgeSwipeRight:
            return Localization.get("SEGMENT_BOTTOM")
        case .leftEdgeSwipeUp, .leftEdgeSwipeDown:
            return Localization.get("SEGMENT_LEFT")
        case .rightEdgeSwipeUp, .rightEdgeSwipeDown:
            return Localization.get("SEGMENT_RIGHT")
        case .cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight:
            return Localization.get("SEGMENT_CORNERS")
        }
    }
}

struct GestureShortcutBinding: Codable, Sendable, Equatable {
    var enabled: Bool
    var shortcut: String
    var mediaAction: MediaAction

    init(enabled: Bool = false, shortcut: String = "", mediaAction: MediaAction = .none) {
        self.enabled = enabled
        self.shortcut = shortcut
        self.mediaAction = mediaAction
    }
}

struct GestureShortcutMapping: Codable, Sendable, Equatable {
    var slot: GestureShortcutSlot
    var binding: GestureShortcutBinding

    init(slot: GestureShortcutSlot, binding: GestureShortcutBinding = GestureShortcutBinding()) {
        self.slot = slot
        self.binding = binding
    }
}

extension GestureShortcutSlot {
    var actionKey: GestureActionKey {
        switch self {
        case .topEdgeSwipeLeft:
            return .topEdgeLeft
        case .topEdgeSwipeRight:
            return .topEdgeRight
        case .bottomEdgeSwipeLeft:
            return .bottomEdgeLeft
        case .bottomEdgeSwipeRight:
            return .bottomEdgeRight
        case .leftEdgeSwipeUp:
            return .leftEdgeUp
        case .leftEdgeSwipeDown:
            return .leftEdgeDown
        case .rightEdgeSwipeUp:
            return .rightEdgeUp
        case .rightEdgeSwipeDown:
            return .rightEdgeDown
        case .cornerTopLeft:
            return .topLeftCornerTap
        case .cornerTopRight:
            return .topRightCornerTap
        case .cornerBottomLeft:
            return .bottomLeftCornerTap
        case .cornerBottomRight:
            return .bottomRightCornerTap
        }
    }
}

enum MediaAction: String, CaseIterable, Codable, Sendable, Equatable {
    case none
    case volumeUp
    case volumeDown
    case mute

    var displayName: String {
        switch self {
        case .none:
            return Localization.get("DISPLAY_NONE")
        case .volumeUp:
            return Localization.get("DISPLAY_VOLUME_UP")
        case .volumeDown:
            return Localization.get("DISPLAY_VOLUME_DOWN")
        case .mute:
            return Localization.get("DISPLAY_MUTE")
        }
    }
}
