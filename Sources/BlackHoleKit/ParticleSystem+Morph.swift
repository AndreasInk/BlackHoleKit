import CoreGraphics

extension ParticleSystem {
    var currentMorphWave: CGFloat {
        morphWave(phase: morphPulsePhase, time: time, includesMotion: false)
    }

    var visualMorphStrength: CGFloat {
        currentMorphStrength * currentMorphWave
    }

    func smoothstep(_ value: CGFloat) -> CGFloat {
        smoothstepForMorph(value)
    }

    /// The shared plateau wave used by simulation and rendering state.
    ///
    /// `currentMorphWave` intentionally exposes the deterministic envelope,
    /// while the update path includes the small motion detail that animates
    /// the plateau and black-hole phases.
    func morphWave(phase: CGFloat, time: Double, includesMotion: Bool) -> CGFloat {
        let cyclePosition = (phase.truncatingRemainder(dividingBy: CGFloat.pi * 2)) / (CGFloat.pi * 2)

        if cyclePosition < 0.15 {
            return smoothstepForMorph(cyclePosition / 0.15)
        } else if cyclePosition < 0.50 {
            guard includesMotion else { return 1.0 }
            return 1.0 + 0.02 * CGFloat(sin(time * 3.0))
        } else if cyclePosition < 0.65 {
            return 1.0 - smoothstepForMorph((cyclePosition - 0.50) / 0.15)
        } else {
            guard includesMotion else { return 0.0 }
            return max(0, 0.05 * CGFloat(sin(time * 1.5)))
        }
    }

    private func smoothstepForMorph(_ value: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, value))
        return clamped * clamped * (3 - 2 * clamped)
    }
}

extension ParticleSystem.ParticleLayer {
    var orbitalSpeed: CGFloat {
        switch self {
        case .photonRing: return 25.0
        case .accretionDisk: return 15.0
        case .eventHorizon, .lensingRing: return 5.0
        }
    }
}
