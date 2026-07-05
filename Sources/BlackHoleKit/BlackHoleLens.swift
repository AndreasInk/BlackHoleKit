import SwiftUI
import Foundation

/// A SwiftUI layer-effect modifier that bends rendered pixels around a black-hole center.
///
/// Apply this to content that should be distorted by the singularity, typically a background
/// layer. ``BlackHoleParticleMorphView`` uses the same shader internally to make the built-in
/// star background respond to the black-hole warp.
@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct BlackHoleLensModifier: ViewModifier {
    public var center: UnitPoint
    public var radius: CGFloat
    public var strength: CGFloat
    public var spin: CGFloat
    public var darkness: CGFloat
    public var glow: CGFloat
    public var isEnabled: Bool

    public init(
        center: UnitPoint = .center,
        radius: CGFloat = 150,
        strength: CGFloat = 0.85,
        spin: CGFloat = 0.85,
        darkness: CGFloat = 0.98,
        glow: CGFloat = 0.90,
        isEnabled: Bool = true
    ) {
        self.center = center
        self.radius = radius
        self.strength = strength
        self.spin = spin
        self.darkness = darkness
        self.glow = glow
        self.isEnabled = isEnabled
    }

    public func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let time = Float(timeline.date.timeIntervalSinceReferenceDate.remainder(dividingBy: 10_000))

            content.visualEffect { visualContent, proxy in
                let size = proxy.size
                let centerX = Float(size.width * center.x)
                let centerY = Float(size.height * center.y)

                let clampedRadius = max(1, Float(radius))
                let clampedStrength = Float(strength.clamped(to: 0...1.5))
                let clampedDarkness = Float(darkness.clamped(to: 0...1))
                let clampedGlow = Float(glow.clamped(to: 0...2))

                let sampleOffset = CGFloat(clampedRadius) * (1.0 + CGFloat(clampedStrength) * 0.65)

                return visualContent.layerEffect(
                    ShaderLibrary.bundle(.module).blackHoleLens(
                        .float2(centerX, centerY),
                        .float(clampedRadius),
                        .float(clampedStrength),
                        .float(Float(spin)),
                        .float(clampedDarkness),
                        .float(clampedGlow),
                        .float(time)
                    ),
                    maxSampleOffset: CGSize(width: sampleOffset, height: sampleOffset),
                    isEnabled: isEnabled
                )
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public extension View {
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
        modifier(
            BlackHoleLensModifier(
                center: center,
                radius: radius,
                strength: strength,
                spin: spin,
                darkness: darkness,
                glow: glow,
                isEnabled: isEnabled
            )
        )
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
