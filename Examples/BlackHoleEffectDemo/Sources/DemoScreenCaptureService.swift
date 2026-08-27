import AppKit
import CoreImage
import CoreMedia
import CoreVideo
import Observation
import OSLog
@preconcurrency import ScreenCaptureKit

enum DemoCaptureState: Equatable {
    case permissionRequired
    case preparing
    case running
    case failed(String)

    var title: String {
        switch self {
        case .permissionRequired:
            "Screen Recording permission required"
        case .preparing:
            "Preparing desktop distortion"
        case .running:
            "Distorting the desktop"
        case .failed:
            "Desktop capture unavailable"
        }
    }

    var detail: String {
        switch self {
        case .permissionRequired:
            "Allow access so the demo can capture and distort the pixels behind this window. macOS may require you to reopen the app after granting access."
        case .preparing:
            "Waiting for an aligned frame from the current display."
        case .running:
            ""
        case .failed(let message):
            message
        }
    }

    var symbolName: String {
        switch self {
        case .permissionRequired:
            "rectangle.on.rectangle.slash"
        case .preparing, .running:
            "sparkles"
        case .failed:
            "exclamationmark.triangle"
        }
    }

    var needsPermission: Bool {
        self == .permissionRequired
    }

    var canRetry: Bool {
        if case .failed = self { return true }
        return false
    }
}

@MainActor
@Observable
final class DemoScreenCaptureService {
    private static let logger = Logger(
        subsystem: "com.andreasink.BlackHoleEffectDemo",
        category: "ScreenCapture"
    )

    private let output = DemoStreamOutput()
    private var stream: SCStream?
    private var refreshTask: Task<Void, Never>?
    private var requestedContentFrame: CGRect?
    private var requestedScreen: NSScreen?
    private var requestedWindowID: CGWindowID?
    private var activeDisplayID: CGDirectDisplayID?

    var state: DemoCaptureState = .preparing
    var image: CGImage?
    var imageScale: CGFloat = 1

    init() {
        output.onFrame = { [weak self] frame in
            Task { @MainActor in
                guard let self else { return }
                self.image = frame.image
                self.imageScale = frame.scale
                self.state = .running
                self.output.markFrameConsumed()
            }
        }
        output.onStop = { [weak self] message in
            Task { @MainActor in
                guard let self else { return }
                self.stream = nil
                self.activeDisplayID = nil
                self.state = .failed(message)
            }
        }
    }

    func update(for window: NSWindow) {
        guard let contentView = window.contentView else { return }
        let contentRectInWindow = contentView.convert(contentView.bounds, to: nil)
        let contentFrame = window.convertToScreen(contentRectInWindow)

        requestedContentFrame = contentFrame
        requestedScreen = window.screen
        requestedWindowID = window.windowNumber > 0
            ? CGWindowID(window.windowNumber)
            : nil

        if let screen = window.screen {
            output.setCropRequest(
                Self.makeCropRequest(contentFrame: contentFrame, screen: screen)
            )
            if activeDisplayID != nil, activeDisplayID != screen.displayID {
                let previousStream = stream
                stream = nil
                activeDisplayID = nil
                image = nil
                state = .preparing
                output.deactivate()
                Task {
                    try? await previousStream?.stopCapture()
                }
            }
        }

        guard CGPreflightScreenCaptureAccess() else {
            state = .permissionRequired
            return
        }

        if stream == nil || activeDisplayID != window.screen?.displayID {
            scheduleRefresh()
        }
    }

    func startIfAuthorized() {
        guard CGPreflightScreenCaptureAccess() else {
            state = .permissionRequired
            return
        }
        scheduleRefresh()
    }

    func requestPermission() {
        state = .preparing
        let granted = CGRequestScreenCaptureAccess()
        Self.logger.notice("Screen capture permission request returned \(granted, privacy: .public)")
        if granted || CGPreflightScreenCaptureAccess() {
            scheduleRefresh()
        } else {
            state = .permissionRequired
        }
    }

    func retry() {
        guard CGPreflightScreenCaptureAccess() else {
            state = .permissionRequired
            return
        }
        scheduleRefresh()
    }

    func stop() async {
        refreshTask?.cancel()
        refreshTask = nil
        output.deactivate()

        if let stream {
            self.stream = nil
            try? await stream.stopCapture()
        }
        activeDisplayID = nil
        image = nil
        state = CGPreflightScreenCaptureAccess() ? .preparing : .permissionRequired
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled, let self else { return }
            await self.refreshCapture()
        }
    }

    private func refreshCapture() async {
        guard CGPreflightScreenCaptureAccess() else {
            state = .permissionRequired
            return
        }
        guard let contentFrame = requestedContentFrame,
              let screen = requestedScreen,
              let displayID = screen.displayID,
              let windowID = requestedWindowID else {
            state = .preparing
            return
        }

        state = .preparing
        output.setCropRequest(
            Self.makeCropRequest(contentFrame: contentFrame, screen: screen)
        )

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                state = .failed("The current display is not available to ScreenCaptureKit.")
                return
            }

            let ownProcessID = pid_t(ProcessInfo.processInfo.processIdentifier)
            let ownWindows = content.windows.filter { window in
                window.windowID == windowID
                    || window.owningApplication?.processID == ownProcessID
            }
            guard ownWindows.contains(where: { $0.windowID == windowID }) else {
                state = .failed("The demo window could not be excluded safely from its own capture.")
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
            let configuration = Self.makeConfiguration(for: screen)

            if let stream {
                output.deactivate()
                try? await stream.stopCapture()
            }

            let newStream = SCStream(
                filter: filter,
                configuration: configuration,
                delegate: output
            )
            try newStream.addStreamOutput(
                output,
                type: .screen,
                sampleHandlerQueue: output.queue
            )
            output.activate(stream: newStream)
            try await newStream.startCapture()
            stream = newStream
            activeDisplayID = displayID
            Self.logger.info("Screen capture started for display \(displayID, privacy: .public)")
        } catch {
            stream = nil
            activeDisplayID = nil
            state = CGPreflightScreenCaptureAccess()
                ? .failed(error.localizedDescription)
                : .permissionRequired
            Self.logger.error("Screen capture failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func makeConfiguration(for screen: NSScreen) -> SCStreamConfiguration {
        let scale = max(1, screen.backingScaleFactor)
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(origin: .zero, size: screen.frame.size)
        configuration.width = max(2, Int((screen.frame.width * scale).rounded()))
        configuration.height = max(2, Int((screen.frame.height * scale).rounded()))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 24)
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.capturesAudio = false
        return configuration
    }

    private static func makeCropRequest(
        contentFrame: CGRect,
        screen: NSScreen
    ) -> DemoCropRequest {
        let scale = max(1, screen.backingScaleFactor)
        let frame = contentFrame.intersection(screen.frame)
        return DemoCropRequest(
            pixelRect: CGRect(
                x: floor((frame.minX - screen.frame.minX) * scale),
                y: floor((frame.minY - screen.frame.minY) * scale),
                width: max(1, ceil(frame.width * scale)),
                height: max(1, ceil(frame.height * scale))
            ),
            scale: scale
        )
    }
}

private struct DemoCapturedFrame: @unchecked Sendable {
    let image: CGImage
    let scale: CGFloat
}

private struct DemoCropRequest: @unchecked Sendable {
    let pixelRect: CGRect
    let scale: CGFloat
}

private final class DemoStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let queue = DispatchQueue(
        label: "com.andreasink.BlackHoleEffectDemo.capture",
        qos: .userInteractive
    )

    private let context = CIContext(options: [.cacheIntermediates: false])
    private weak var activeStream: SCStream?
    private var cropRequest: DemoCropRequest?
    private var deliveryPending = false

    var onFrame: (@Sendable (DemoCapturedFrame) -> Void)?
    var onStop: (@Sendable (String) -> Void)?

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen,
              stream === activeStream,
              sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer,
              !deliveryPending else { return }

        let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]]
        let statusRawValue = attachments?.first?[.status] as? Int
        guard statusRawValue == nil || statusRawValue == SCFrameStatus.complete.rawValue else {
            return
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let request = cropRequest
        let cropRect = request?.pixelRect.intersection(ciImage.extent) ?? ciImage.extent
        guard !cropRect.isNull,
              !cropRect.isEmpty,
              let image = context.createCGImage(ciImage, from: cropRect) else { return }

        deliveryPending = true
        onFrame?(
            DemoCapturedFrame(
                image: image,
                scale: request?.scale ?? 1
            )
        )
    }

    func activate(stream: SCStream) {
        queue.sync {
            activeStream = stream
            deliveryPending = false
        }
    }

    func deactivate() {
        queue.sync {
            activeStream = nil
            deliveryPending = false
        }
    }

    func setCropRequest(_ request: DemoCropRequest) {
        queue.async { [weak self] in
            self?.cropRequest = request
        }
    }

    func markFrameConsumed() {
        queue.async { [weak self] in
            self?.deliveryPending = false
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        queue.async { [weak self, weak stream] in
            guard let self,
                  let stream,
                  stream === self.activeStream else { return }
            self.onStop?(error.localizedDescription)
        }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }
}
