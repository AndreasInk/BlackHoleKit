import SwiftUI

enum ParticleTargets {
    
    struct BlackHoleResult {
        var points: [CGPoint]
        var particleData: [ParticleSystem.ParticleData]
        var center: CGPoint
        var eventHorizonRadius: CGFloat
    }
    
    // Procedural "black hole" point cloud: dense event horizon + accretion disk ring.
    static func blackHoleData(in size: CGSize, desiredCount: Int) -> BlackHoleResult {
        let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let minSide = min(size.width, size.height)

        let holeR = minSide * 0.10
        let photonR = holeR * 1.15
        let innerDiskR = holeR * 1.5
        let outerDiskR = minSide * 0.42

        var pts: [CGPoint] = []
        var data: [ParticleSystem.ParticleData] = []
        pts.reserveCapacity(desiredCount)
        data.reserveCapacity(desiredCount)

        // Distribution weights - fewer in event horizon (it's mostly black), more in disk
        let holeCount = Int(CGFloat(desiredCount) * 0.12)
        let photonCount = Int(CGFloat(desiredCount) * 0.055)
        let lensRingCount = Int(CGFloat(desiredCount) * 0.10)
        let diskCount = max(0, desiredCount - holeCount - photonCount - lensRingCount)

        // Event horizon: sparse points inside circle (will be covered by black disk)
        for i in 0..<holeCount {
            let u = pseudo(i, 41)
            let v = pseudo(i, 42)
            let ang = CGFloat(u) * (.pi * 2)
            let r = holeR * 0.85 * sqrt(CGFloat(v))
            
            pts.append(CGPoint(x: c.x + cos(ang) * r, y: c.y + sin(ang) * r))
            data.append(ParticleSystem.ParticleData(orbitRadius: r, orbitAngle: ang, layer: 0))
        }

        // Photon ring: tight ring just outside event horizon
        for i in 0..<photonCount {
            let u = pseudo(i, 51)
            let ang = CGFloat(u) * (.pi * 2)
            let jitter = (pseudo(i, 52) - 0.5) * (minSide * 0.008)
            let r = photonR + jitter
            
            pts.append(CGPoint(x: c.x + cos(ang) * r, y: c.y + sin(ang) * r))
            data.append(ParticleSystem.ParticleData(orbitRadius: r, orbitAngle: ang, layer: 1))
        }

        // Accretion disk: distributed from inner to outer radius
        for i in 0..<diskCount {
            let u = pseudo(i, 61)
            let v = pseudo(i, 62)
            let ang = CGFloat(u) * (.pi * 2)
            
            // Bias material toward the hot inner disk. `sqrt` would crowd the outer rim
            // and create a clipped, CD-like silhouette at the horizontal edges.
            let radialT = CGFloat(v)
            let r = innerDiskR + (outerDiskR - innerDiskR) * pow(radialT, 1.55)
            
            // Elliptical tilt + yaw to sell a 3D disk
            let tilt: CGFloat = 0.38
            let yaw: CGFloat = 0.14
            let x = cos(ang) * r
            let y = sin(ang) * r * tilt
            let xr = x * cos(yaw) - y * sin(yaw)
            let yr = x * sin(yaw) + y * cos(yaw)
            
            pts.append(CGPoint(x: c.x + xr, y: c.y + yr))
            data.append(ParticleSystem.ParticleData(orbitRadius: r, orbitAngle: ang, layer: 2))
        }

        // Lensing ring: perpendicular to main disk (Interstellar effect)
        // This represents light from the back of the disk bent around the black hole
        // Ring appears as vertical band passing over/under the black hole
        let lensInnerR = holeR * 1.3
        let lensOuterR = minSide * 0.30
        for i in 0..<lensRingCount {
            let u = pseudo(i, 71)
            let v = pseudo(i, 72)
            let ang = CGFloat(u) * (.pi * 2)
            
            // Keep the lensed image close to the photon sphere instead of drawing a
            // second full-width disk over the real accretion plane.
            let radialT = CGFloat(v)
            let r = lensInnerR + (lensOuterR - lensInnerR) * pow(radialT, 1.7)
            
            // Horizontal lensing ring: wraps left-right around the black hole
            let vertCompress: CGFloat = 0.42  // compressed vertically (depth) - more circular
            let x = cos(ang) * r  // full horizontal extent
            let y = sin(ang) * r * vertCompress  // narrow vertical
            
            pts.append(CGPoint(x: c.x + x, y: c.y + y))
            data.append(ParticleSystem.ParticleData(orbitRadius: r, orbitAngle: ang, layer: 3))
        }

        // If we underfilled due to rounding, pad.
        while pts.count < desiredCount {
            let idx = pts.count % max(1, pts.count)
            pts.append(pts[idx])
            data.append(data[idx])
        }
        
        return BlackHoleResult(
            points: pts,
            particleData: data,
            center: c,
            eventHorizonRadius: holeR
        )
    }
    
    // Legacy method for compatibility
    private static func blackHolePoints(in size: CGSize, desiredCount: Int, time: TimeInterval) -> [CGPoint] {
        return blackHoleData(in: size, desiredCount: desiredCount).points
    }

    private static func pseudo(_ i: Int, _ j: Int) -> CGFloat {
        let x = Double(i * 92821 + j * 68917)
        let s = sin(x * 0.000123 + Double(j) * 1.73) * 43758.5453
        return CGFloat(s - floor(s))
    }

    enum TargetError: Error {
        case renderFailed
        case cgImageMissing
        case pixelDataMissing
    }

    @MainActor
    static func points(
        for target: BlackHoleParticleMorphTarget,
        in size: CGSize,
        sampleStep: Int,
        desiredCount: Int,
        time: TimeInterval = 0
    ) throws -> [CGPoint] {
        let renderSize = CGSize(width: max(64, size.width), height: max(64, size.height))

        let view: AnyView = {
            switch target {
            case .classicMac:
                return AnyView(
                    ZStack {
                        Color.black
                        ZStack {
                            ClassicMacShell().fill(.white)
                            ClassicMacEyes().fill(.black)
                        }
                        .padding(renderSize.width * 0.14)
                    }
                )
            case .text(let string):
                return AnyView(
                    ZStack {
                        Color.black
                        Text(string)
                            .font(.system(size: min(renderSize.width, renderSize.height) * 0.42, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.2)
                            .padding(renderSize.width * 0.10)
                    }
                )
            case .blackHole:
                // procedural target (skip ImageRenderer)
                return AnyView(EmptyView())
            case .sfSymbol(let name):
                return AnyView(
                    ZStack {
                        Color.black
                        Image(systemName: name)
                            .font(.system(size: min(renderSize.width, renderSize.height) * 0.55, weight: .bold))
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.monochrome)
                            .padding(renderSize.width * 0.12)
                    }
                )
            }
        }()

        if case .blackHole = target {
            return blackHolePoints(in: size, desiredCount: desiredCount, time: time)
        }

        let renderer = ImageRenderer(content: view.frame(width: renderSize.width, height: renderSize.height))
        renderer.isOpaque = true

        guard let cgImage = renderer.cgImage else {
            throw TargetError.cgImageMissing
        }

        var points = try samplePoints(from: cgImage, step: max(1, sampleStep), alphaThreshold: 16)

        // Normalize count (repeat/shuffle) and map into actual view size.
        points = normalize(points: points, to: desiredCount)
        points = points.map { p in
            CGPoint(x: p.x / renderSize.width * size.width, y: p.y / renderSize.height * size.height)
        }

        return points
    }

    private static func samplePoints(from cgImage: CGImage, step: Int, alphaThreshold: UInt8) throws -> [CGPoint] {
        guard let dataProvider = cgImage.dataProvider, let data = dataProvider.data else {
            throw TargetError.pixelDataMissing
        }
        let ptr = CFDataGetBytePtr(data)!

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow

        var result: [CGPoint] = []
        result.reserveCapacity((width / step) * (height / step) / 4)

        // Important: ImageRenderer output is usually fully opaque (alpha=255) for both black and white.
        // So alpha thresholding alone selects the whole frame (which is what you saw: a grid).
        // Instead, threshold by brightness ("how white is this pixel").
        let alphaOffset = 3

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let idx = y * bytesPerRow + x * bytesPerPixel

                let b0 = ptr[idx + 0]
                let b1 = ptr[idx + 1]
                let b2 = ptr[idx + 2]
                let a = ptr[idx + alphaOffset]

                // Treat "on" pixels as bright + not transparent.
                let brightness = max(b0, max(b1, b2))
                if a > alphaThreshold && brightness > 32 {
                    result.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
                }
            }
        }

        if result.isEmpty {
            // Fallback: full grid.
            for y in stride(from: 0, to: height, by: step) {
                for x in stride(from: 0, to: width, by: step) {
                    result.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
                }
            }
        }

        return result
    }

    private static func normalize(points: [CGPoint], to desiredCount: Int) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        if points.count == desiredCount { return points }

        var out: [CGPoint] = []
        out.reserveCapacity(desiredCount)

        // Deterministic-ish selection: stride through points.
        let step = max(1, points.count / desiredCount)
        var i = 0
        while out.count < desiredCount {
            out.append(points[i % points.count])
            i += step
        }
        return out
    }
}

/// Procedural "classic Mac" monitor + two square eyes.
struct ClassicMacShell: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        let r = rect
        let corner = min(r.width, r.height) * 0.10
        let screen = CGRect(
            x: r.minX,
            y: r.minY,
            width: r.width,
            height: r.height * 0.78
        )
        p.addPath(Path(roundedRect: screen, cornerRadius: corner))

        // Chin / base
        let baseW = r.width * 0.56
        let baseH = r.height * 0.20
        let base = CGRect(
            x: r.midX - baseW / 2,
            y: screen.maxY - baseH * 0.20,
            width: baseW,
            height: baseH
        )
        p.addRoundedRect(in: base, cornerSize: CGSize(width: baseH * 0.45, height: baseH * 0.45))

        return p
    }
}

struct ClassicMacEyes: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect
        let screen = CGRect(
            x: r.minX,
            y: r.minY,
            width: r.width,
            height: r.height * 0.78
        )

        let eyeSize = min(r.width, r.height) * 0.12
        let eyeY = screen.minY + screen.height * 0.42
        let eyeSpacing = r.width * 0.18

        let left = CGRect(
            x: r.midX - eyeSpacing - eyeSize / 2,
            y: eyeY - eyeSize / 2,
            width: eyeSize,
            height: eyeSize
        )
        let right = CGRect(
            x: r.midX + eyeSpacing - eyeSize / 2,
            y: eyeY - eyeSize / 2,
            width: eyeSize,
            height: eyeSize
        )
        p.addRect(left)
        p.addRect(right)
        return p
    }
}
