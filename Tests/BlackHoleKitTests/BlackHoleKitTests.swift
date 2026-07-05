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
            morphCycleSpeed: 0.4,
            photonFlashStrength: 0.25
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
