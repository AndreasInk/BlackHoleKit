import SwiftUI
import Foundation

/// The visual parameters for ``BlackHoleLensModifier``.
///
/// Values are intentionally expressed in points and unit coordinates so the same configuration
/// can be reused across views of different sizes. The modifier clamps unsafe values before they
/// reach the Metal shader.
@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct BlackHoleLensConfiguration: Sendable, Equatable {
    public var center: UnitPoint
    public var radius: CGFloat
    public var strength: CGFloat
    public var spin: CGFloat
    public var darkness: CGFloat
    public var glow: CGFloat
    public var causticStrength: CGFloat
    public var chromaticAberration: CGFloat
    public var animationSpeed: CGFloat

    public init(
        center: UnitPoint = .center,
        radius: CGFloat = 150,
        strength: CGFloat = 0.85,
        spin: CGFloat = 0.85,
        darkness: CGFloat = 0.98,
        glow: CGFloat = 0.90,
        causticStrength: CGFloat = 0.80,
        chromaticAberration: CGFloat = 0.35,
        animationSpeed: CGFloat = 1.0
    ) {
        self.center = center
        self.radius = radius
        self.strength = strength
        self.spin = spin
        self.darkness = darkness
        self.glow = glow
        self.causticStrength = causticStrength
        self.chromaticAberration = chromaticAberration
        self.animationSpeed = animationSpeed
    }
}

struct BlackHoleLensResolvedConfiguration: Equatable {
    let radius: Float
    let strength: Float
    let spin: Float
    let darkness: Float
    let glow: Float
    let causticStrength: Float
    let chromaticAberration: Float
    let animationSpeed: Float
    let maxSampleOffset: CGFloat

    init(_ configuration: BlackHoleLensConfiguration) {
        radius = max(1, Float(configuration.radius))
        strength = Float(configuration.strength.clamped(to: 0...1.5))
        spin = Float(configuration.spin.clamped(to: -2...2))
        darkness = Float(configuration.darkness.clamped(to: 0...1))
        glow = Float(configuration.glow.clamped(to: 0...2))
        causticStrength = Float(configuration.causticStrength.clamped(to: 0...2))
        chromaticAberration = Float(configuration.chromaticAberration.clamped(to: 0...1))
        animationSpeed = Float(configuration.animationSpeed.clamped(to: 0...3))
        maxSampleOffset = CGFloat(radius) * 1.08 * (
            1.0 + CGFloat(strength) * 0.72 + CGFloat(chromaticAberration) * 0.065 + 0.030
        )
    }
}

/// A SwiftUI layer-effect modifier that bends rendered pixels around a black-hole center.
///
/// Apply this to content that should be distorted by the singularity, typically a background
/// layer. ``BlackHoleParticleMorphView`` uses the same shader internally to make the built-in
/// star background respond to the black-hole warp.
@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct BlackHoleLensModifier: ViewModifier {
    public var configuration: BlackHoleLensConfiguration
    public var isEnabled: Bool
    @State private var animationStart = Date()

    /// Legacy parameter accessors retained for source compatibility.
    public var center: UnitPoint { get { configuration.center } set { configuration.center = newValue } }
    public var radius: CGFloat { get { configuration.radius } set { configuration.radius = newValue } }
    public var strength: CGFloat { get { configuration.strength } set { configuration.strength = newValue } }
    public var spin: CGFloat { get { configuration.spin } set { configuration.spin = newValue } }
    public var darkness: CGFloat { get { configuration.darkness } set { configuration.darkness = newValue } }
    public var glow: CGFloat { get { configuration.glow } set { configuration.glow = newValue } }

    public init(
        center: UnitPoint = .center,
        radius: CGFloat = 150,
        strength: CGFloat = 0.85,
        spin: CGFloat = 0.85,
        darkness: CGFloat = 0.98,
        glow: CGFloat = 0.90,
        isEnabled: Bool = true
    ) {
        self.configuration = BlackHoleLensConfiguration(
            center: center,
            radius: radius,
            strength: strength,
            spin: spin,
            darkness: darkness,
            glow: glow
        )
        self.isEnabled = isEnabled
    }

    public init(configuration: BlackHoleLensConfiguration, isEnabled: Bool = true) {
        self.configuration = configuration
        self.isEnabled = isEnabled
    }

    public func body(content: Content) -> some View {
        Group {
            if !isEnabled {
                content
            } else if configuration.animationSpeed <= 0 {
                lensEffect(content: content, time: 0)
            } else {
                TimelineView(.animation) { timeline in
                    let time = Float(max(0, timeline.date.timeIntervalSince(animationStart)))
                    lensEffect(content: content, time: time)
                }
            }
        }
    }

    private func lensEffect(content: Content, time: Float) -> some View {
        content.visualEffect { visualContent, proxy in
            let size = proxy.size
            let centerX = Float(size.width * configuration.center.x)
            let centerY = Float(size.height * configuration.center.y)
            let resolved = BlackHoleLensResolvedConfiguration(configuration)

            return visualContent.layerEffect(
                ShaderLibrary.bundle(.module).blackHoleLens(
                    .float2(centerX, centerY),
                    .float2(Float(size.width), Float(size.height)),
                    .float(resolved.radius),
                    .float(resolved.strength),
                    .float(resolved.spin),
                    .float(resolved.darkness),
                    .float(resolved.glow),
                    .float(resolved.causticStrength),
                    .float(resolved.chromaticAberration),
                    .float(resolved.animationSpeed),
                    .float(time)
                ),
                maxSampleOffset: CGSize(
                    width: resolved.maxSampleOffset,
                    height: resolved.maxSampleOffset
                )
            )
        }
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public extension View {
    /// Applies a circular gravitational lens using a reusable configuration.
    func blackHoleLens(
        configuration: BlackHoleLensConfiguration,
        isEnabled: Bool = true
    ) -> some View {
        modifier(BlackHoleLensModifier(configuration: configuration, isEnabled: isEnabled))
    }

    /// Applies a circular gravitational lensing effect to this view.
    ///
    /// The modifier samples nearby pixels from the rendered layer, so it works best on a
    /// background or already-composited group that contains visible texture for the lens to bend.
    func blackHoleLens(
        center: UnitPoint = .center,
        radius: CGFloat = 150,
        strength: CGFloat = 0.85,
        spin: CGFloat = 0.85,
        darkness: CGFloat = 0.98,
        glow: CGFloat = 0.90,
        isEnabled: Bool = true
    ) -> some View {
        blackHoleLens(
            configuration: BlackHoleLensConfiguration(
                center: center,
                radius: radius,
                strength: strength,
                spin: spin,
                darkness: darkness,
                glow: glow
            ),
            isEnabled: isEnabled
        )
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
