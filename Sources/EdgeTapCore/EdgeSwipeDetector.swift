import Foundation

public struct EdgeSwipeDetector: Sendable {
    public struct Configuration: Sendable {
        public var normalizedEdgeThresholdX: Double = 0.94
        public var absoluteEdgeThresholdX: Double = 1.45
        public var triggerDeltaY: Double = 0.18
        public var edgeInset: Double = 0.06
        public var cornerInset: Double = 0.10
        public var minimumEdgeTravel: Double = 0.18
        public var maximumPerpendicularDrift: Double = 0.08
        public var minimumTrackDuration: TimeInterval = 0.05
        public var maximumTrackDuration: TimeInterval = 0.70
        public var minimumCornerTapDuration: TimeInterval = 0.03
        public var maximumCornerTapDuration: TimeInterval = 0.25
        public var maximumCornerTravel: Double = 0.05
        public var cooldown: TimeInterval = 0.4
        public var minimumSampleCount: Int = 4
        public var minimumDirectionConsistency: Double = 0.75
        
        public var continuousModeEnabled: Bool = true
        public var continuousStepThreshold: Double = 0.05

        public init() {}
    }

    private enum TrackingKind: Sendable {
        case edge(TrackpadEdge)
        case corner(TrackpadCorner)
    }

    private struct TrackingState: Sendable {
        let kind: TrackingKind
        var startTime: TimeInterval
        var startX: Double
        var startY: Double
        var latestX: Double
        var latestY: Double
        var lastY: Double
        var accumulatedDeltaX: Double
        var accumulatedDeltaY: Double
        var totalAbsoluteDeltaX: Double
        var totalAbsoluteDeltaY: Double
        var sampleCount: Int
        var emittedDeltaX: Double
        var emittedDeltaY: Double
    }

    public var configuration: Configuration
    private var trackingState: TrackingState?
    private var cooldownUntil: TimeInterval = 0

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public mutating func process(
        contacts: [TouchContact],
        timestamp: TimeInterval
    ) -> GestureEvent? {
        if timestamp < cooldownUntil {
            if contacts.isEmpty {
                trackingState = nil
            }
            return nil
        }

        guard contacts.count == 1, let contact = contacts.first else {
            if let state = trackingState {
                let event = finalizeTrackingIfNeeded(state: state, timestamp: timestamp)
                trackingState = nil
                return event
            }
            return nil
        }

        if var state = trackingState {
            let horizontalDrift = max(abs(contact.x - state.startX), abs(contact.x - state.latestX))
            let verticalDrift = max(abs(contact.y - state.startY), abs(contact.y - state.latestY))
            let deltaX = contact.x - state.latestX
            let deltaY = contact.y - state.lastY
            state.accumulatedDeltaX += deltaX
            state.accumulatedDeltaY += deltaY
            state.totalAbsoluteDeltaX += abs(deltaX)
            state.totalAbsoluteDeltaY += abs(deltaY)
            state.latestX = contact.x
            state.latestY = contact.y
            state.lastY = contact.y
            state.sampleCount += 1
            trackingState = state

            let duration = timestamp - state.startTime
            if isEdgeState(state.kind) {
                let isExpired = !configuration.continuousModeEnabled && duration > configuration.maximumTrackDuration
                if horizontalDrift > configuration.maximumPerpendicularDrift || isExpired {
                    let event = finalizeTrackingIfNeeded(state: state, timestamp: timestamp)
                    trackingState = nil
                    return event
                }
                
                if configuration.continuousModeEnabled {
                    if case let .edge(edge) = state.kind {
                        let primaryDelta = primaryAxisDelta(for: edge, state: state)
                        let emittedDelta = primaryAxisEmittedDelta(for: edge, state: state)
                        let unhandledDelta = primaryDelta - emittedDelta
                        
                        if duration >= configuration.minimumTrackDuration, abs(unhandledDelta) >= configuration.continuousStepThreshold {
                            let direction: GestureDirection
                            switch edge {
                            case .left, .right:
                                direction = unhandledDelta > 0 ? .up : .down
                                trackingState?.emittedDeltaY += unhandledDelta > 0 ? configuration.continuousStepThreshold : -configuration.continuousStepThreshold
                            case .top, .bottom:
                                direction = unhandledDelta < 0 ? .left : .right
                                trackingState?.emittedDeltaX += unhandledDelta < 0 ? -configuration.continuousStepThreshold : configuration.continuousStepThreshold
                            }
                            return .edgeSwipe(edge: edge, direction: direction, magnitude: configuration.continuousStepThreshold)
                        }
                    }
                }
            } else {
                if verticalDrift > configuration.maximumCornerTravel ||
                    horizontalDrift > configuration.maximumCornerTravel ||
                    duration > configuration.maximumCornerTapDuration {
                    let event = finalizeTrackingIfNeeded(state: state, timestamp: timestamp)
                    trackingState = nil
                    return event
                }
            }

            if contact.isEndTouch {
                let event = finalizeTrackingIfNeeded(state: state, timestamp: timestamp)
                trackingState = nil
                return event
            }

            return nil
        }

        guard shouldStartTracking(contact: contact) else {
            return nil
        }

        guard let kind = trackingKind(for: contact) else {
            return nil
        }

        trackingState = TrackingState(
            kind: kind,
            startTime: timestamp,
            startX: contact.x,
            startY: contact.y,
            latestX: contact.x,
            latestY: contact.y,
            lastY: contact.y,
            accumulatedDeltaX: 0,
            accumulatedDeltaY: 0,
            totalAbsoluteDeltaX: 0,
            totalAbsoluteDeltaY: 0,
            sampleCount: 1,
            emittedDeltaX: 0,
            emittedDeltaY: 0
        )
        return nil
    }

    public mutating func reset() {
        trackingState = nil
    }

    private mutating func finalizeTrackingIfNeeded(
        state: TrackingState,
        timestamp: TimeInterval
    ) -> GestureEvent? {
        let duration = timestamp - state.startTime
        switch state.kind {
        case let .edge(edge):
            if configuration.continuousModeEnabled {
                return nil
            }
            
            let primaryDelta = primaryAxisDelta(for: edge, state: state)
            let magnitude = abs(primaryDelta)
            let totalMagnitude = totalPrimaryTravel(for: edge, state: state)
            let consistency = magnitude / max(totalMagnitude, 0.0001)
            let travelThreshold = max(configuration.minimumEdgeTravel, configuration.triggerDeltaY)

            guard duration >= configuration.minimumTrackDuration,
                  magnitude >= travelThreshold,
                  state.sampleCount >= configuration.minimumSampleCount,
                  consistency >= configuration.minimumDirectionConsistency else {
                return nil
            }

            return emitEdgeGesture(for: state, edge: edge, timestamp: timestamp)

        case let .corner(corner):
            let travel = max(abs(state.accumulatedDeltaX), abs(state.accumulatedDeltaY))

            guard duration >= configuration.minimumCornerTapDuration,
                  duration <= configuration.maximumCornerTapDuration,
                  travel <= configuration.maximumCornerTravel else {
                return nil
            }

            return emitCornerGesture(corner: corner, timestamp: timestamp)
        }
    }

    private mutating func emitEdgeGesture(
        for state: TrackingState,
        edge: TrackpadEdge,
        timestamp: TimeInterval
    ) -> GestureEvent {
        trackingState = nil
        cooldownUntil = timestamp + configuration.cooldown

        let direction: GestureDirection
        switch edge {
        case .left, .right:
            direction = state.accumulatedDeltaY > 0 ? .up : .down
        case .top, .bottom:
            direction = state.accumulatedDeltaX < 0 ? .left : .right
        }

        let magnitude = edge == .left || edge == .right ? abs(state.accumulatedDeltaY) : abs(state.accumulatedDeltaX)
        return .edgeSwipe(edge: edge, direction: direction, magnitude: magnitude)
    }

    private mutating func emitCornerGesture(
        corner: TrackpadCorner,
        timestamp: TimeInterval
    ) -> GestureEvent {
        trackingState = nil
        cooldownUntil = timestamp + configuration.cooldown
        return .cornerTap(corner: corner)
    }

    private func shouldStartTracking(contact: TouchContact) -> Bool {
        guard contact.isBeginTouch else {
            return false
        }

        return trackingKind(for: contact) != nil
    }

    private func trackingKind(for contact: TouchContact) -> TrackingKind? {
        if let corner = corner(for: contact) {
            return .corner(corner)
        }

        if let edge = edge(for: contact) {
            return .edge(edge)
        }

        return nil
    }

    private func edge(for contact: TouchContact) -> TrackpadEdge? {
        let xInset = configuration.absoluteEdgeThresholdX / 10.0
        let yInset = xInset * 1.6 // Assume ~1.6:1 aspect ratio for physical consistency
        
        if contact.x <= xInset {
            return .left
        }
        if contact.x >= 1.0 - xInset {
            return .right
        }
        if contact.y <= yInset {
            return .bottom // Flipped logic: y=0 is bottom in trackpad coordinates
        }
        if contact.y >= 1.0 - yInset {
            return .top
        }
        return nil
    }

    private func corner(for contact: TouchContact) -> TrackpadCorner? {
        let xInset = max(configuration.cornerInset, configuration.absoluteEdgeThresholdX / 10.0)
        let yInset = xInset * 1.6
        
        guard contact.x <= xInset || contact.x >= 1.0 - xInset else {
            return nil
        }
        guard contact.y <= yInset || contact.y >= 1.0 - yInset else {
            return nil
        }

        switch (contact.x <= xInset, contact.y >= 1.0 - yInset) {
        case (true, true):
            return .topLeft
        case (false, true):
            return .topRight
        case (true, false):
            return .bottomLeft
        case (false, false):
            return .bottomRight
        }
    }

    private func isEdgeState(_ kind: TrackingKind) -> Bool {
        switch kind {
        case .edge:
            return true
        case .corner:
            return false
        }
    }

    private func primaryAxisDelta(for edge: TrackpadEdge, state: TrackingState) -> Double {
        switch edge {
        case .left, .right:
            return state.accumulatedDeltaY
        case .top, .bottom:
            return state.accumulatedDeltaX
        }
    }

    private func totalPrimaryTravel(for edge: TrackpadEdge, state: TrackingState) -> Double {
        switch edge {
        case .left, .right:
            return state.totalAbsoluteDeltaY
        case .top, .bottom:
            return state.totalAbsoluteDeltaX
        }
    }
    
    private func primaryAxisEmittedDelta(for edge: TrackpadEdge, state: TrackingState) -> Double {
        switch edge {
        case .left, .right:
            return state.emittedDeltaY
        case .top, .bottom:
            return state.emittedDeltaX
        }
    }
}
