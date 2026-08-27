import AppKit
import BlackHoleKit
import SwiftUI

struct BlackHoleEffectView: View {
    @Bindable var captureService: DemoScreenCaptureService

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                if let image = captureService.image {
                    Image(decorative: image, scale: captureService.imageScale)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .blackHoleLens(
                            configuration: .init(
                                radius: min(proxy.size.width, proxy.size.height) * 0.46,
                                strength: 1.34,
                                spin: 0.82,
                                darkness: 1,
                                glow: 1.18,
                                causticStrength: 1.42,
                                chromaticAberration: 1,
                                animationSpeed: 0.9
                            )
                        )

                    BlackHoleParticleMorphView(
                        target: .blackHole,
                        visualConfig: .init(
                            speedMultiplier: 0.82,
                            particleScale: 0.68,
                            lensingStrength: 1.2,
                            spacetimeWarpStrength: 1,
                            spaceBackgroundStrength: 0,
                            horizonDrama: 1.18,
                            showsParticles: true,
                            showsWarp: false
                        ),
                        particleCount: 2_400
                    )
                    .allowsHitTesting(false)
                } else {
                    captureStatus
                }
            }
        }
        .frame(minWidth: 500, minHeight: 500)
        .background {
            DemoWindowObserver { window in
                captureService.update(for: window)
            }
        }
        .task {
            captureService.startIfAuthorized()
        }
        .onDisappear {
            Task {
                await captureService.stop()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var captureStatus: some View {
        VStack(spacing: 14) {
            Image(systemName: captureService.state.symbolName)
                .font(.system(size: 36, weight: .medium))

            Text(captureService.state.title)
                .font(.headline)

            Text(captureService.state.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if captureService.state.needsPermission {
                Button("Enable Screen Recording") {
                    captureService.requestPermission()
                }
                .buttonStyle(.borderedProminent)
            } else if captureService.state.canRetry {
                Button("Try Again") {
                    captureService.retry()
                }
                .buttonStyle(.borderedProminent)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(32)
    }
}

private struct DemoWindowObserver: NSViewRepresentable {
    let onChange: @MainActor (NSWindow) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var window: NSWindow?
        private let onChange: @MainActor (NSWindow) -> Void

        init(onChange: @escaping @MainActor (NSWindow) -> Void) {
            self.onChange = onChange
        }

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }
            detach()
            self.window = window
            window.title = "BlackHoleKit Desktop Effect"
            window.isMovableByWindowBackground = true

            let center = NotificationCenter.default
            center.addObserver(
                self,
                selector: #selector(windowGeometryDidChange(_:)),
                name: NSWindow.didMoveNotification,
                object: window
            )
            center.addObserver(
                self,
                selector: #selector(windowGeometryDidChange(_:)),
                name: NSWindow.didResizeNotification,
                object: window
            )
            center.addObserver(
                self,
                selector: #selector(windowGeometryDidChange(_:)),
                name: NSWindow.didChangeScreenNotification,
                object: window
            )
            onChange(window)
        }

        @objc private func windowGeometryDidChange(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            onChange(window)
        }

        private func detach() {
            guard let window else { return }
            NotificationCenter.default.removeObserver(self, name: nil, object: window)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

#Preview {
    BlackHoleEffectView(captureService: DemoScreenCaptureService())
        .frame(width: 620, height: 620)
}
