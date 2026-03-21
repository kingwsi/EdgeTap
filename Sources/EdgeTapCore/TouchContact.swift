import Foundation

public struct TouchContact: Sendable {
    public let identifier: Int
    public let state: Int
    public let x: Double
    public let y: Double
    public let size: Double
    public let timestamp: TimeInterval

    public init(
        identifier: Int,
        state: Int,
        x: Double,
        y: Double,
        size: Double,
        timestamp: TimeInterval
    ) {
        self.identifier = identifier
        self.state = state
        self.x = x
        self.y = y
        self.size = size
        self.timestamp = timestamp
    }

    public var isActiveTouch: Bool {
        state != 7
    }

    public var isBeginTouch: Bool {
        state == 1 || state == 3
    }

    public var isEndTouch: Bool {
        state == 7
    }
}
