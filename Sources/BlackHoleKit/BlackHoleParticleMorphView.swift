import SwiftUI
import Combine

/// A SwiftUI view that morphs a procedural black hole particle field into text or symbol targets.
///
/// The view is self-contained: it owns the particle simulation, renders with SwiftUI `Canvas`, and
/// rasterizes text/SF Symbol targets on the main actor when the target changes.
public struct BlackHoleParticleMorphView: View {
    /// Particle count used by the default initializer.
    ///
    /// Xcode previews use a lower count to keep preview refreshes responsive.
    public static var defaultParticleCount: Int {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ? 1800 : 2800
    }

    public var target: BlackHoleParticleMorphTarget
    public var visualConfig: BlackHoleParticleVisualConfig
    public var particleCount: Int
    public var pointSampleStep: Int
    public var seed: UInt64

    public init(
        target: BlackHoleParticleMorphTarget = .blackHole,
        visualConfig: BlackHoleParticleVisualConfig = BlackHoleParticleVisualConfig(),
        particleCount: Int = Self.defaultParticleCount,
        pointSampleStep: Int = 3,
        seed: UInt64 = 0xC0FFEE
    ) {
        self.target = target
        self.visualConfig = visualConfig
        self.particleCount = particleCount
        self.pointSampleStep = pointSampleStep
        self.seed = seed
    }

    public var body: some View {
        GeometryReader { proxy in
            ParticleMorphCoreView(
                target: target,
                size: proxy.size,
                particleCount: particleCount,
                pointSampleStep: pointSampleStep,
                seed: seed,
                visualConfig: visualConfig
            )
        }
    }
}

@MainActor
final class ParticleSystemBox: ObservableObject {
    var system: ParticleSystem
    @Published var redrawToken: Int = 0

    init(system: ParticleSystem) {
        self.system = system
    }

    func bump() {
        redrawToken &+= 1
    }

    func replaceSystem(seed: UInt64) {
        system = ParticleSystem(seed: seed)
        redrawToken = 0
    }
}

private struct ParticleMorphCoreView: View {
    let target: BlackHoleParticleMorphTarget
    let size: CGSize
    let particleCount: Int
    let pointSampleStep: Int
    let seed: UInt64
    let visualConfig: BlackHoleParticleVisualConfig

    @StateObject private var system: ParticleSystemBox
    @State private var smoothedVisualConfig: BlackHoleParticleVisualConfig = BlackHoleParticleVisualConfig()
    @State private var lastTarget: BlackHoleParticleMorphTarget?
    @State private var frameTick: Int = 0
    @State private var isInitialized: Bool = false
    @State private var lastLayoutSize: CGSize = .zero
    @State private var lastParticleCount: Int?
    @State private var lastPointSampleStep: Int?
    @State private var lastSeed: UInt64?

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    init(
        target: BlackHoleParticleMorphTarget,
        size: CGSize,
        particleCount: Int,
        pointSampleStep: Int,
        seed: UInt64,
        visualConfig: BlackHoleParticleVisualConfig
    ) {
        self.target = target
        self.size = size
        self.particleCount = particleCount
        self.pointSampleStep = pointSampleStep
        self.seed = seed
        self.visualConfig = visualConfig
        _system = StateObject(wrappedValue: ParticleSystemBox(system: ParticleSystem(seed: seed)))
        _smoothedVisualConfig = State(initialValue: visualConfig)
    }

    var body: some View {
        // Reading the tick invalidates the Canvas renderers without replacing their identity.
        // Using `.id(frameTick)` here rebuilt the full Canvas + Metal subtree every frame.
        let _ = frameTick
        let renderPlan = BlackHoleParticleRenderPlan(visualConfig: smoothedVisualConfig)

        ZStack {
            if renderPlan.appliesMetalLens {
                Canvas { context, canvasSize in
                    system.system.drawBackground(in: context, size: canvasSize)
                }
                .blackHoleLens(
                    center: .center,
                    radius: metalLensRadius,
                    strength: metalLensStrength,
                    spin: (0.34 + smoothedVisualConfig.spacetimeWarpStrength * 0.12) * metalLensVisibility,
                    darkness: 0.10 * metalLensVisibility,
                    glow: 0.16 * metalLensVisibility,
                    isEnabled: metalLensStrength > 0.015
                )
            } else {
                Canvas { context, canvasSize in
                    system.system.drawBackground(in: context, size: canvasSize)
                }
            }

            if renderPlan.rendersForegroundCanvas {
                Canvas { context, canvasSize in
                    system.system.drawForeground(in: context, size: canvasSize)
                }
            }
        }
        .onReceive(timer) { _ in
            // Apply visual config every frame to ensure it stays in sync
            applyVisualConfigIfNeeded()
            if smoothedVisualConfig.showsParticles || frameTick.isMultiple(of: 4) {
                // Keep simulation time continuous while the foreground is hidden, but avoid
                // paying for 2,800 invisible particle updates on every display refresh.
                let simulationStep = smoothedVisualConfig.showsParticles ? 1.0 / 60.0 : 4.0 / 60.0
                system.system.update(dt: simulationStep)
            }
            frameTick &+= 1
        }
        .onAppear {
            smoothedVisualConfig = visualConfig
            applyVisualConfigIfNeeded()
            syncTargetIfNeeded(animated: false)
        }
        .onChange(of: size) { _, _ in
            syncTargetIfNeeded(animated: false)
        }
        .onChange(of: target) { _, _ in
            syncTargetIfNeeded(animated: true)
        }
    }
    
    private func applyVisualConfigIfNeeded() {
        let dt = 1.0 / 60.0
        let easing = CGFloat(1.0 - exp(-12.0 * dt))

        smoothedVisualConfig.colorHue = interpolateHue(
            from: smoothedVisualConfig.colorHue,
            to: visualConfig.colorHue,
            amount: easing
        )
        smoothedVisualConfig.showsParticles = visualConfig.showsParticles
        smoothedVisualConfig.showsWarp = visualConfig.showsWarp
        smoothedVisualConfig.colorSaturation = lerp(
            from: smoothedVisualConfig.colorSaturation,
            to: visualConfig.colorSaturation,
            amount: easing
        )
        smoothedVisualConfig.speedMultiplier = lerp(
            from: smoothedVisualConfig.speedMultiplier,
            to: visualConfig.speedMultiplier,
            amount: easing
        )
        smoothedVisualConfig.particleScale = lerp(
            from: smoothedVisualConfig.particleScale,
            to: visualConfig.particleScale,
            amount: easing
        )
        smoothedVisualConfig.morphCycleSpeed = lerp(
            from: smoothedVisualConfig.morphCycleSpeed,
            to: visualConfig.morphCycleSpeed,
            amount: easing
        )
        smoothedVisualConfig.densityWaveStrength = lerp(from: smoothedVisualConfig.densityWaveStrength, to: visualConfig.densityWaveStrength, amount: easing)
        smoothedVisualConfig.fallInActivity = lerp(from: smoothedVisualConfig.fallInActivity, to: visualConfig.fallInActivity, amount: easing)
        smoothedVisualConfig.lensingStrength = lerp(from: smoothedVisualConfig.lensingStrength, to: visualConfig.lensingStrength, amount: easing)
        smoothedVisualConfig.spacetimeWarpStrength = lerp(from: smoothedVisualConfig.spacetimeWarpStrength, to: visualConfig.spacetimeWarpStrength, amount: easing)
        smoothedVisualConfig.spaceBackgroundStrength = lerp(from: smoothedVisualConfig.spaceBackgroundStrength, to: visualConfig.spaceBackgroundStrength, amount: easing)
        smoothedVisualConfig.horizonDrama = lerp(from: smoothedVisualConfig.horizonDrama, to: visualConfig.horizonDrama, amount: easing)
        smoothedVisualConfig.photonFlashStrength = lerp(from: smoothedVisualConfig.photonFlashStrength, to: visualConfig.photonFlashStrength, amount: easing)
        smoothedVisualConfig.sideFlareStrength = lerp(from: smoothedVisualConfig.sideFlareStrength, to: visualConfig.sideFlareStrength, amount: easing)
        smoothedVisualConfig.shearOutwardStrength = lerp(from: smoothedVisualConfig.shearOutwardStrength, to: visualConfig.shearOutwardStrength, amount: easing)

        // Always apply smoothed values for frame-stable transitions.
        system.system.colorHueBase = smoothedVisualConfig.colorHue
        system.system.colorSaturation = smoothedVisualConfig.colorSaturation
        system.system.speedMultiplier = smoothedVisualConfig.speedMultiplier
        system.system.maxSpeed = 400.0 * smoothedVisualConfig.speedMultiplier
        system.system.particleScale = smoothedVisualConfig.particleScale
        system.system.morphCycleSpeed = smoothedVisualConfig.morphCycleSpeed
        system.system.densityWaveStrength = smoothedVisualConfig.densityWaveStrength
        system.system.fallInActivity = smoothedVisualConfig.fallInActivity
        system.system.lensingStrength = smoothedVisualConfig.lensingStrength
        system.system.spaceBackgroundStrength = smoothedVisualConfig.spaceBackgroundStrength
        system.system.horizonDrama = smoothedVisualConfig.horizonDrama
        system.system.photonFlashStrength = smoothedVisualConfig.photonFlashStrength
        system.system.sideFlareStrength = smoothedVisualConfig.sideFlareStrength
        system.system.shearOutwardStrength = smoothedVisualConfig.shearOutwardStrength
    }

    private func lerp(from: CGFloat, to: CGFloat, amount: CGFloat) -> CGFloat {
        from + (to - from) * amount
    }

    /// Hue interpolation that follows the shortest path around the 0-1 color wheel.
    private func interpolateHue(from: CGFloat, to: CGFloat, amount: CGFloat) -> CGFloat {
        let normalizedFrom = (from.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        let normalizedTo = (to.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        let delta = shortestCircularDelta(from: normalizedFrom, to: normalizedTo)
        return (normalizedFrom + delta * amount).truncatingRemainder(dividingBy: 1)
    }

    private func shortestCircularDelta(from: CGFloat, to: CGFloat) -> CGFloat {
        let raw = to - from
        if raw > 0.5 { return raw - 1.0 }
        if raw < -0.5 { return raw + 1.0 }
        return raw
    }

    private func syncTargetIfNeeded(animated: Bool) {
        guard size.width > 0, size.height > 0 else { return }

        let effectiveParticleCount = max(0, particleCount)
        let effectivePointSampleStep = max(1, pointSampleStep)
        let sizeDidChange = !isInitialized || lastLayoutSize != size
        let particleCountDidChange = !isInitialized || lastParticleCount != effectiveParticleCount
        let pointSampleStepDidChange = !isInitialized || lastPointSampleStep != effectivePointSampleStep
        let seedDidChange = !isInitialized || lastSeed != seed
        let targetDidChange = lastTarget != target

        guard !isInitialized || sizeDidChange || particleCountDidChange || pointSampleStepDidChange || seedDidChange || targetDidChange else { return }

        let shouldRebuild = !isInitialized || sizeDidChange || particleCountDidChange || seedDidChange
        if seedDidChange, isInitialized {
            system.replaceSystem(seed: seed)
        }
        if shouldRebuild {
            // Rebuild particles on first load and resize so the black hole remains centered.
            let bhData = ParticleTargets.blackHoleData(in: size, desiredCount: effectiveParticleCount)
            system.system.blackHoleCenter = bhData.center
            system.system.blackHoleRadius = bhData.eventHorizonRadius
            system.system.initializeAsBlackHole(
                points: bhData.points,
                particleData: bhData.particleData
            )
        }

        if shouldRebuild || pointSampleStepDidChange || targetDidChange {
            if target == .blackHole {
                // Pure black hole mode - particles return to orbit
                system.system.setShapeTarget(nil, morphStrength: 0)
            } else {
                do {
                    // Hybrid mode - particles form shape clearly then warp back
                    let points = try ParticleTargets.points(
                        for: target,
                        in: size,
                        sampleStep: effectivePointSampleStep,
                        desiredCount: effectiveParticleCount,
                        time: 0
                    )
                    system.system.setShapeTarget(points, morphStrength: 0.95)
                } catch {
                    // Fallback to black hole shape if rendering points fail.
                    system.system.setShapeTarget(nil, morphStrength: 0)
                }
            }
        }

        if animated && targetDidChange && !sizeDidChange {
            system.system.dampVelocities(0.3)
        }

        isInitialized = true
        lastTarget = target
        lastLayoutSize = size
        lastParticleCount = effectiveParticleCount
        lastPointSampleStep = effectivePointSampleStep
        lastSeed = seed
        frameTick &+= 1
    }

    private var metalLensRadius: CGFloat {
        let minSide = min(size.width, size.height)
        let baseRadius = system.system.blackHoleRadius > 0 ? system.system.blackHoleRadius : minSide * 0.10
        return min(max(1, minSide * 0.54), max(1, baseRadius * 4.8))
    }

    private var metalLensStrength: CGFloat {
        let morphFade = max(0, 1.0 - system.system.visualMorphStrength * 1.2)
        let backgroundMask = max(0, min(1, smoothedVisualConfig.spaceBackgroundStrength))
        return max(0, smoothedVisualConfig.spacetimeWarpStrength) * 0.58 * morphFade * backgroundMask
    }

    private var metalLensVisibility: CGFloat {
        min(1, max(0, metalLensStrength / 0.58))
    }
}

/// The stable layer contract for the particle and warp visibility controls.
///
/// The background always renders. Disabling particles removes the full foreground Canvas while the
/// timer continues updating the system, and disabling warp avoids constructing the Metal lens layer.
struct BlackHoleParticleRenderPlan: Equatable {
    let rendersForegroundCanvas: Bool
    let appliesMetalLens: Bool

    init(visualConfig: BlackHoleParticleVisualConfig) {
        rendersForegroundCanvas = visualConfig.showsParticles
        appliesMetalLens = visualConfig.showsWarp
    }
}

#Preview {
    BlackHoleParticleMorphView(
        target: .blackHole,
        visualConfig: .init(
            colorHue: 0.33,
            speedMultiplier: 0.8,
            particleScale: 0.72,
            lensingStrength: 1.2,
            spacetimeWarpStrength: 1.35,
            spaceBackgroundStrength: 1.0,
            horizonDrama: 1.15
        ),
        particleCount: 2_800
    )
    .frame(width: 560, height: 420)
}
