import Foundation

public final class GestureEngine {
    public var onGesture: (@Sendable (GestureEvent) -> Void)?

    private var detector: EdgeSwipeDetector

    public init(detector: EdgeSwipeDetector = EdgeSwipeDetector()) {
        self.detector = detector
    }

    public func process(contacts: [TouchContact], timestamp: TimeInterval) {
        if let event = detector.process(contacts: contacts, timestamp: timestamp) {
            onGesture?(event)
        }
    }

    public func simulate(direction: GestureDirection) {
        onGesture?(.edgeSwipe(edge: .right, direction: direction, magnitude: 0.18))
    }

    public func simulate(edge: TrackpadEdge, direction: GestureDirection) {
        onGesture?(.edgeSwipe(edge: edge, direction: direction, magnitude: 0.18))
    }

    public func simulate(corner: TrackpadCorner) {
        onGesture?(.cornerTap(corner: corner))
    }

    public func reset() {
        detector.reset()
    }

    public func updateConfiguration(_ configuration: EdgeSwipeDetector.Configuration) {
        detector.configuration = configuration
        detector.configuration.minimumEdgeTravel = configuration.triggerDeltaY
        detector.reset()
    }
}
