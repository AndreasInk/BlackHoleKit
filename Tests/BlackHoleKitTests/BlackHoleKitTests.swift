import CoreGraphics
import Testing
import SwiftUI
@testable import BlackHoleKit

struct BlackHoleKitTests {
    @MainActor
    @Test func publicViewInitializerStoresConfiguration() {
        let config = BlackHoleParticleVisualConfig(
            colorHue: 0.55,
            colorSaturation: 0.7,
            speedMultiplier: 0.8,
            particleScale: 0.62,
            morphCycleSpeed: 0.4,
            spacetimeWarpStrength: 1.2,
            spaceBackgroundStrength: 0.7,
            photonFlashStrength: 0.25,
            showsParticles: false,
            showsWarp: false
        )

        let view = BlackHoleParticleMorphView(
            target: .text("OK"),
            visualConfig: config,
            particleCount: 64,
            pointSampleStep: 4,
            seed: 42
        )

        #expect(view.target == .text("OK"))
        #expect(view.visualConfig == config)
        #expect(view.particleCount == 64)
        #expect(view.pointSampleStep == 4)
        #expect(view.seed == 42)
        #expect(view.visualConfig.showsParticles == false)
        #expect(view.visualConfig.showsWarp == false)
        #expect(BlackHoleParticleVisualConfig().particleScale < 1.0)
        #expect(BlackHoleParticleVisualConfig().showsParticles)
        #expect(BlackHoleParticleVisualConfig().showsWarp)
        #expect(BlackHoleParticleVisualConfig().spacetimeWarpStrength > 0.0)
        #expect(BlackHoleParticleVisualConfig().spaceBackgroundStrength > 0.0)
    }

    @Test func particleAndWarpVisibilityControlsHaveIndependentRenderPlans() {
        let cases: [(showsParticles: Bool, showsWarp: Bool, rendersForeground: Bool, appliesLens: Bool)] = [
            (true, true, true, true),
            (true, false, true, false),
            (false, true, false, true),
            (false, false, false, false)
        ]

        for testCase in cases {
            let config = BlackHoleParticleVisualConfig(
                showsParticles: testCase.showsParticles,
                showsWarp: testCase.showsWarp
            )
            let plan = BlackHoleParticleRenderPlan(visualConfig: config)

            #expect(plan.rendersForegroundCanvas == testCase.rendersForeground)
            #expect(plan.appliesMetalLens == testCase.appliesLens)
        }
    }

    @Test func lensConfigurationResolvesUnsafeValuesAndLegacyInitializer() {
        let configuration = BlackHoleLensConfiguration(
            radius: -20,
            strength: 8,
            spin: -8,
            darkness: 4,
            glow: 9,
            causticStrength: -1,
            chromaticAberration: 5,
            animationSpeed: 7
        )
        let resolved = BlackHoleLensResolvedConfiguration(configuration)

        #expect(resolved.radius == 1)
        #expect(resolved.strength == 1.5)
        #expect(resolved.spin == -2)
        #expect(resolved.darkness == 1)
        #expect(resolved.glow == 2)
        #expect(resolved.causticStrength == 0)
        #expect(resolved.chromaticAberration == 1)
        #expect(resolved.animationSpeed == 3)
        #expect(resolved.maxSampleOffset > 1)

        let staticResolved = BlackHoleLensResolvedConfiguration(
            .init(animationSpeed: -1)
        )
        #expect(staticResolved.animationSpeed == 0)

        let legacy = BlackHoleLensModifier(
            center: .topLeading,
            radius: 120,
            strength: 0.7,
            spin: 0.3,
            darkness: 0.8,
            glow: 0.6
        )
        #expect(legacy.configuration.center == .topLeading)
        #expect(legacy.configuration.radius == 120)
        #expect(legacy.configuration.causticStrength == 0.8)
        #expect(legacy.configuration.chromaticAberration == 0.35)
    }

    @Test func blackHolePointCloudUsesRequestedCountAndCenter() {
        let result = ParticleTargets.blackHoleData(
            in: CGSize(width: 200, height: 100),
            desiredCount: 128
        )

        #expect(result.points.count == 128)
        #expect(result.particleData.count == 128)
        #expect(result.center == CGPoint(x: 100, y: 50))
        #expect(result.eventHorizonRadius == 10)
        #expect(result.particleData.contains { $0.layer == 3 })
    }

    @Test func particleSystemAdvancesFromInitialBlackHoleState() {
        let blackHole = ParticleTargets.blackHoleData(
            in: CGSize(width: 180, height: 180),
            desiredCount: 48
        )
        let system = ParticleSystem(seed: 7)
        system.blackHoleCenter = blackHole.center
        system.blackHoleRadius = blackHole.eventHorizonRadius
        system.initializeAsBlackHole(
            points: blackHole.points,
            particleData: blackHole.particleData
        )

        let initialPositions = system.particles.map(\.position)
        system.update(dt: 1.0 / 60.0)

        #expect(system.time > 0)
        #expect(system.particles.count == 48)
        #expect(zip(initialPositions, system.particles.map(\.position)).contains { $0 != $1 })
    }

    @MainActor
    @Test func proceduralTargetSamplerReturnsRequestedCount() throws {
        let points = try ParticleTargets.points(
            for: .blackHole,
            in: CGSize(width: 120, height: 120),
            sampleStep: 3,
            desiredCount: 40
        )

        #expect(points.count == 40)
    }
}
