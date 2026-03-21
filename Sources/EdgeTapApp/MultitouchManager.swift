import CMultitouchBridge
import EdgeTapCore
import Foundation

private func edgeTapFrameHandler(
    _ contacts: UnsafePointer<ETMTTouch>?,
    _ count: Int32,
    _ timestamp: Double,
    _ context: UnsafeMutableRawPointer?
) {
    guard let context else {
        return
    }

    let manager = Unmanaged<MultitouchManager>.fromOpaque(context).takeUnretainedValue()
    manager.handleFrame(contacts: contacts, count: count, timestamp: timestamp)
}

final class MultitouchManager {
    struct StartResult {
        let started: Bool
        let message: String
    }

    private var frameHandler: (([TouchContact], TimeInterval) -> Void)?
    private var lastPrintedFrameAt: TimeInterval = 0
    var isFrameLoggingEnabled = true

    var isFrameworkAvailable: Bool {
        ETMTIsAvailable()
    }

    func start(
        frameHandler: @escaping ([TouchContact], TimeInterval) -> Void
    ) -> StartResult {
        self.frameHandler = frameHandler

        var errorBuffer = Array<CChar>(repeating: 0, count: 256)
        let started = ETMTStart(
            edgeTapFrameHandler,
            Unmanaged.passUnretained(self).toOpaque(),
            &errorBuffer,
            Int32(errorBuffer.count)
        )

        if started {
            return StartResult(
                started: true,
                message: Localization.get("MONITORING_STARTED")
            )
        }

        self.frameHandler = nil
        let messageBytes = errorBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let message = String(decoding: messageBytes, as: UTF8.self)
        return StartResult(
            started: false,
            message: message.isEmpty ? Localization.get("MONITORING_FAILED") : message
        )
    }

    func stop() {
        ETMTStop()
        frameHandler = nil
    }

    fileprivate func handleFrame(
        contacts: UnsafePointer<ETMTTouch>?,
        count: Int32,
        timestamp: Double
    ) {
        guard let frameHandler else {
            return
        }

        guard let contacts, count > 0 else {
            frameHandler([], timestamp)
            return
        }

        let touches = UnsafeBufferPointer(start: contacts, count: Int(count)).map { contact in
            TouchContact(
                identifier: Int(contact.identifier),
                state: Int(contact.state),
                x: Double(contact.x),
                y: Double(contact.y),
                size: Double(contact.size),
                timestamp: timestamp
            )
        }

        printFrameIfNeeded(touches, timestamp: timestamp)
        frameHandler(touches, timestamp)
    }

    private func printFrameIfNeeded(_ touches: [TouchContact], timestamp: TimeInterval) {
        guard isFrameLoggingEnabled else {
            return
        }

        guard !touches.isEmpty else {
            return
        }

        // Throttle terminal output so live touch frames stay readable.
        guard timestamp - lastPrintedFrameAt >= 0.08 else {
            return
        }

        lastPrintedFrameAt = timestamp

        let summary = touches.prefix(3).map { touch in
            "id=\(touch.identifier) state=\(touch.state) x=\(String(format: "%.3f", touch.x)) y=\(String(format: "%.3f", touch.y)) size=\(String(format: "%.3f", touch.size))"
        }.joined(separator: " | ")

        print("[EdgeTap] frame count=\(touches.count) t=\(String(format: "%.3f", timestamp)) \(summary)")
    }
}
