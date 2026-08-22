import CoreGraphics

extension ParticleSystem {
    func dampVelocities(_ factor: CGFloat) {
        let clampedFactor = max(0, min(1, factor))
        for index in particles.indices {
            particles[index].velocity.dx *= clampedFactor
            particles[index].velocity.dy *= clampedFactor
        }
    }

    /// Initialize the particle system with black hole as base.
    func initializeAsBlackHole(points: [CGPoint], particleData: [ParticleData]) {
        particles = points.enumerated().map { index, point in
            let data = particleData[safe: index]
            return Particle(
                position: point,
                velocity: .zero,
                phase: rng.nextDouble(in: 0...1000),
                baseOrbitRadius: data?.orbitRadius ?? 0,
                orbitRadius: data?.orbitRadius ?? 0,
                orbitAngle: data?.orbitAngle ?? 0,
                layer: data?.layer ?? .eventHorizon,
                shapeTarget: point,
                baseSize: CGFloat(rng.nextDouble(in: 1.2...3.0)),
                hueShift: CGFloat(rng.nextDouble(in: -0.08...0.08)),
                brightness: CGFloat(rng.nextDouble(in: 0.5...1.3)),
                pulseSpeed: CGFloat(rng.nextDouble(in: 0.5...2.5)),
                pulsePhase: CGFloat(rng.nextDouble(in: 0...(.pi * 2)))
            )
        }
    }

    /// Set a shape target for particles to try to form.
    func setShapeTarget(_ targets: [CGPoint]?, morphStrength: CGFloat) {
        guard let targets else {
            targetMorphStrength = 0.0
            return
        }

        targetMorphStrength = morphStrength
        for index in particles.indices where index < targets.count {
            particles[index].shapeTarget = targets[index]
        }
    }
}
