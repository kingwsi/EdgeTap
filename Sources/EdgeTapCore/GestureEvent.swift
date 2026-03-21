import Foundation

public enum GestureDirection: String, Sendable {
    case up
    case down
    case left
    case right
}

public enum TrackpadEdge: String, Sendable {
    case left
    case right
    case top
    case bottom
}

public enum TrackpadCorner: String, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

public enum GestureActionKey: String, CaseIterable, Sendable, Hashable {
    case leftEdgeUp
    case leftEdgeDown
    case rightEdgeUp
    case rightEdgeDown
    case topEdgeLeft
    case topEdgeRight
    case bottomEdgeLeft
    case bottomEdgeRight
    case topLeftCornerTap
    case topRightCornerTap
    case bottomLeftCornerTap
    case bottomRightCornerTap
}

public enum GestureEvent: Sendable {
    case edgeSwipe(edge: TrackpadEdge, direction: GestureDirection, magnitude: Double)
    case cornerTap(corner: TrackpadCorner)

    public var actionKey: GestureActionKey {
        switch self {
        case let .edgeSwipe(edge, direction, _):
            switch (edge, direction) {
            case (.left, .up):
                return .leftEdgeUp
            case (.left, .down):
                return .leftEdgeDown
            case (.right, .up):
                return .rightEdgeUp
            case (.right, .down):
                return .rightEdgeDown
            case (.top, .left):
                return .topEdgeLeft
            case (.top, .right):
                return .topEdgeRight
            case (.bottom, .left):
                return .bottomEdgeLeft
            case (.bottom, .right):
                return .bottomEdgeRight
            default:
                return .rightEdgeUp
            }

        case let .cornerTap(corner):
            switch corner {
            case .topLeft:
                return .topLeftCornerTap
            case .topRight:
                return .topRightCornerTap
            case .bottomLeft:
                return .bottomLeftCornerTap
            case .bottomRight:
                return .bottomRightCornerTap
            }
        }
    }
}
