#if os(macOS)
import AppKit
import CoreGraphics
import SwiftUI
import Testing
@testable import BlackHoleKit

private enum SnapshotError: Error {
    case cgImageMissing
    case pngDataMissing
}

struct BlackHoleSnapshotTests {
    @MainActor
    @Test func optionalBlackHoleSnapshot() throws {
        guard let outputPath = ProcessInfo.processInfo.environment["BLACKHOLEKIT_SNAPSHOT_PATH"],
              !outputPath.isEmpty else {
            return
        }

        let size = CGSize(width: 720, height: 720)
        let blackHole = ParticleTargets.blackHoleData(in: size, desiredCount: 2_200)
        let system = ParticleSystem(seed: 0xB1A9C0DE)
        system.blackHoleCenter = blackHole.center
        system.blackHoleRadius = blackHole.eventHorizonRadius
        system.particleScale = 0.72
        system.spacetimeWarpStrength = 1.0
        system.spaceBackgroundStrength = 1.0
        system.lensingStrength = 1.15
        system.initializeAsBlackHole(
            points: blackHole.points,
            particleData: blackHole.particleData
        )

        let snapshotTarget = ProcessInfo.processInfo.environment["BLACKHOLEKIT_SNAPSHOT_TARGET"]
        if snapshotTarget == "symbol" {
            let points = try ParticleTargets.points(
                for: .sfSymbol("sparkles"),
                in: size,
                sampleStep: 3,
                desiredCount: blackHole.points.count
            )
            system.setShapeTarget(points, morphStrength: 0.95)
        } else if snapshotTarget == "text" {
            let points = try ParticleTargets.points(
                for: .text("OK"),
                in: size,
                sampleStep: 3,
                desiredCount: blackHole.points.count
            )
            system.setShapeTarget(points, morphStrength: 0.95)
        }

        let frameCount = ProcessInfo.processInfo.environment["BLACKHOLEKIT_SNAPSHOT_FRAMES"]
            .flatMap(Int.init) ?? 150
        for _ in 0..<frameCount {
            system.update(dt: 1.0 / 60.0)
        }

        let lensStrength = max(0, system.spacetimeWarpStrength) * 0.58 * max(0, 1.0 - system.visualMorphStrength * 1.2)
        let lensVisibility = min(1, max(0, lensStrength / 0.58))

        let view = ZStack {
            Canvas { context, canvasSize in
                system.drawBackground(in: context, size: canvasSize)
            }
            .blackHoleLens(
                center: .center,
                radius: max(1, blackHole.eventHorizonRadius * 4.8),
                strength: lensStrength,
                spin: 0.46 * lensVisibility,
                darkness: 0.10 * lensVisibility,
                glow: 0.16 * lensVisibility,
                isEnabled: lensStrength > 0.015
            )

            Canvas { context, canvasSize in
                system.drawForeground(in: context, size: canvasSize)
            }
        }
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1.0

        guard let image = renderer.cgImage else {
            throw SnapshotError.cgImageMissing
        }

        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw SnapshotError.pngDataMissing
        }

        try png.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }
}
#endif
