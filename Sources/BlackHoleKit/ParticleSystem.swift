import SwiftUI

/// CPU particle system with black hole as the base state.
/// Particles always orbit the black hole but can be influenced by shape targets.
final class ParticleSystem {
    
    struct Particle {
        var position: CGPoint
        var velocity: CGVector
        var phase: Double
        
        // Black hole orbital properties (always active)
        var baseOrbitRadius: CGFloat = 0
        var orbitRadius: CGFloat = 0
        var orbitAngle: CGFloat = 0
        var layer: Int = 0  // 0=event horizon, 1=photon ring, 2=accretion disk
        
        // Shape morph target
        var shapeTarget: CGPoint = .zero
        
        // Per-particle visual properties
        var baseSize: CGFloat = 2.0
        var hueShift: CGFloat = 0.0
        var brightness: CGFloat = 1.0
        var pulseSpeed: CGFloat = 1.0
        var pulsePhase: CGFloat = 0.0
    }

    private(set) var particles: [Particle] = []
    private var rng: SeededRNG
    private(set) var time: Double = 0
    
    // Black hole properties (always active)
    var blackHoleCenter: CGPoint = .zero
    var blackHoleRadius: CGFloat = 40.0
    
    // Morph control
    private var shapeTargets: [CGPoint]? = nil
    private var currentMorphStrength: CGFloat = 0.0
    private var targetMorphStrength: CGFloat = 0.0
    private var morphPulsePhase: CGFloat = 0.0
    
    // Physics tunables
    var maxSpeed: CGFloat = 400.0
    
    // Visual tunables (can be adjusted based on mode/state)
    var colorHueBase: CGFloat = 0.08  // Base hue (0.08 = orange, 0.55 = cyan, 0.0 = red)
    var colorSaturation: CGFloat = 0.8  // Color intensity
    var speedMultiplier: CGFloat = 1.0  // Overall motion speed
    var particleScale: CGFloat = 0.72
    var morphCycleSpeed: CGFloat = 0.52  // Default ~12s cycle (higher = faster)
    var densityWaveStrength: CGFloat = 1.0
    var fallInActivity: CGFloat = 0.7
    var lensingStrength: CGFloat = 1.0
    var spacetimeWarpStrength: CGFloat = 1.0
    var horizonDrama: CGFloat = 1.0
    var photonFlashStrength: CGFloat = 0.0
    var sideFlareStrength: CGFloat = 0.0
    var shearOutwardStrength: CGFloat = 0.0

    private var nextFallInEventTime: Double = 4.0
    private var fallInEventStartTime: Double = -100.0
    private var fallInEventDuration: Double = 3.8
    private var fallInEventAngle: CGFloat = 0.0
    private var fallInEventRadius: CGFloat = 0.0

    init(seed: UInt64) {
        self.rng = SeededRNG(seed: seed)
    }
    
    /// Attempt to read current morph wave for external access (visual sync)
    var currentMorphWave: CGFloat {
        let cyclePos = (morphPulsePhase.truncatingRemainder(dividingBy: CGFloat.pi * 2)) / (CGFloat.pi * 2)
        if cyclePos < 0.15 {
            let t = cyclePos / 0.15
            return smoothstep(t)
        } else if cyclePos < 0.50 {
            return 1.0
        } else if cyclePos < 0.65 {
            let t = (cyclePos - 0.50) / 0.15
            return 1.0 - smoothstep(t)
        } else {
            return 0.0
        }
    }
    
    /// Attempt to smooth ease in/out using cubic smoothstep
    private func smoothstep(_ t: CGFloat) -> CGFloat {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }
    
    func dampVelocities(_ factor: CGFloat) {
        let f = max(0, min(1, factor))
        for i in particles.indices {
            particles[i].velocity.dx *= f
            particles[i].velocity.dy *= f
        }
    }
    
    struct ParticleData {
        var orbitRadius: CGFloat
        var orbitAngle: CGFloat
        var layer: Int
    }
    
    /// Initialize the particle system with black hole as base
    func initializeAsBlackHole(points: [CGPoint], particleData: [ParticleData]) {
        particles = points.enumerated().map { (i, p) in
            let data = particleData[safe: i]
            return Particle(
                position: p,
                velocity: .zero,
                phase: rng.nextDouble(in: 0...1000),
                baseOrbitRadius: data?.orbitRadius ?? 0,
                orbitRadius: data?.orbitRadius ?? 0,
                orbitAngle: data?.orbitAngle ?? 0,
                layer: data?.layer ?? 0,
                shapeTarget: p,
                baseSize: CGFloat(rng.nextDouble(in: 1.2...3.0)),
                hueShift: CGFloat(rng.nextDouble(in: -0.08...0.08)),
                brightness: CGFloat(rng.nextDouble(in: 0.5...1.3)),
                pulseSpeed: CGFloat(rng.nextDouble(in: 0.5...2.5)),
                pulsePhase: CGFloat(rng.nextDouble(in: 0...(.pi * 2)))
            )
        }
    }
    
    /// Set a shape target for particles to try to form
    func setShapeTarget(_ targets: [CGPoint]?, morphStrength: CGFloat) {
        if let targets = targets {
            shapeTargets = targets
            targetMorphStrength = morphStrength
            
            // Assign shape targets to particles
            for i in particles.indices {
                if i < targets.count {
                    particles[i].shapeTarget = targets[i]
                }
            }
        } else {
            shapeTargets = nil
            targetMorphStrength = 0.0
        }
    }

    func update(dt: Double) {
        time += dt
        let dtf = CGFloat(dt)
        updateFallInEvent()
        
        // Smoothly transition morph strength when target changes
        let morphSpeed: CGFloat = 2.5
        if currentMorphStrength < targetMorphStrength {
            currentMorphStrength = min(targetMorphStrength, currentMorphStrength + morphSpeed * dtf)
        } else if currentMorphStrength > targetMorphStrength {
            currentMorphStrength = max(targetMorphStrength, currentMorphStrength - morphSpeed * 0.8 * dtf)
        }
        
        // Custom wave: rises smoothly, holds at peak, falls smoothly
        // Full cycle ~12 seconds: 2s rise, 4s hold, 2s fall, 4s black hole
        // Can be sped up/slowed down via morphCycleSpeed
        morphPulsePhase += dtf * morphCycleSpeed
        
        // Normalize to 0-1 for cycle position
        let cyclePos = (morphPulsePhase.truncatingRemainder(dividingBy: CGFloat.pi * 2)) / (CGFloat.pi * 2)
        
        // Create plateau wave using smoothstep-like easing
        let morphWave: CGFloat
        if cyclePos < 0.15 {
            // Rising phase (0 to 0.15) - smooth ease in
            let t = cyclePos / 0.15
            morphWave = smoothstep(t)
        } else if cyclePos < 0.50 {
            // Hold at peak (0.15 to 0.50) - stay at 1.0 with tiny wobble
            let wobble = 0.02 * CGFloat(sin(time * 3.0))
            morphWave = 1.0 + wobble
        } else if cyclePos < 0.65 {
            // Falling phase (0.50 to 0.65) - smooth ease out
            let t = (cyclePos - 0.50) / 0.15
            morphWave = 1.0 - smoothstep(t)
        } else {
            // Black hole phase (0.65 to 1.0) - stay near 0 with subtle pulse
            let pulse = 0.05 * CGFloat(sin(time * 1.5))
            morphWave = max(0, pulse)
        }
        
        // Apply morph strength with the wave
        let morphPulse = currentMorphStrength * morphWave
        
        let center = blackHoleCenter

        for i in particles.indices {
            var p = particles[i]
            
            // Calculate base black hole orbital position
            let bhPosition = calculateBlackHolePosition(for: &p, dt: dtf)
            
            // Always use spring-based movement for smooth transitions
            // Blend between black hole orbital position and shape target based on morphPulse
            
            let individualMorphStrength: CGFloat
            let targetX: CGFloat
            let targetY: CGFloat
            
            if morphPulse > 0.01 {
                // Morphing: blend between black hole and shape
                let variationScale = 1.0 - morphPulse * 0.9
                let phaseOffset = 0.05 * CGFloat(sin(p.phase * 0.1)) * variationScale
                individualMorphStrength = min(1.0, morphPulse * (0.95 + phaseOffset))
                
                let targetPos = p.shapeTarget
                
                // Blend between black hole position and shape target
                let blendedX = bhPosition.x + (targetPos.x - bhPosition.x) * individualMorphStrength
                let blendedY = bhPosition.y + (targetPos.y - bhPosition.y) * individualMorphStrength
                
                // Struggle is almost zero when morph is high
                let struggleScale = pow(1.0 - individualMorphStrength, 2.0)
                let struggle = 3.0 * CGFloat(sin(time * 2.0 + p.phase * 2.0)) * struggleScale
                let struggleY = 3.0 * CGFloat(cos(time * 1.8 + p.phase * 1.7)) * struggleScale
                
                targetX = blendedX + struggle
                targetY = blendedY + struggleY
            } else {
                // Pure black hole mode - smoothly track orbital position
                individualMorphStrength = 0.0
                targetX = bhPosition.x
                targetY = bhPosition.y
            }
            
            let dx = targetX - p.position.x
            let dy = targetY - p.position.y
            
            // Spring stiffness: high during shape, moderate during black hole for smooth tracking
            let baseStiffness: CGFloat = 18.0  // Smooth black hole tracking
            let morphStiffness: CGFloat = 60.0 * individualMorphStrength  // Crisp shape formation
            let stiffness = baseStiffness + morphStiffness
            
            p.velocity.dx += dx * stiffness * dtf
            p.velocity.dy += dy * stiffness * dtf
            
            // Damping: moderate always, higher during shape hold
            let baseDamping: CGFloat = 0.90
            let morphDamping: CGFloat = 0.07 * individualMorphStrength
            let damping = baseDamping + morphDamping
            p.velocity.dx *= damping
            p.velocity.dy *= damping
            
            // Clamp speed
            let speed = hypot(p.velocity.dx, p.velocity.dy)
            if speed > maxSpeed {
                let s = maxSpeed / speed
                p.velocity.dx *= s
                p.velocity.dy *= s
            }
            
            p.position.x += p.velocity.dx * dtf
            p.position.y += p.velocity.dy * dtf
            
            // Gentle tangential velocity for orbital motion when in black hole mode
            // This makes particles spiral smoothly rather than just spring to position
            if morphPulse < 0.5 {
                let toCenter = CGPoint(x: center.x - p.position.x, y: center.y - p.position.y)
                let distFromCenter = hypot(toCenter.x, toCenter.y)
                
                if distFromCenter > blackHoleRadius * 0.5 {
                    // Add tangential velocity component for orbital feel
                    let orbitFactor = (0.5 - morphPulse) * 2.0  // 0 to 1 as morph goes to 0
                    let tangentX = -toCenter.y / distFromCenter
                    let tangentY = toCenter.x / distFromCenter
                    
                    // Orbital speed based on layer
                    let orbitSpeed: CGFloat = p.layer == 1 ? 25.0 : (p.layer == 2 ? 15.0 : 5.0)
                    
                    p.velocity.dx += tangentX * orbitSpeed * orbitFactor * dtf
                    p.velocity.dy += tangentY * orbitSpeed * orbitFactor * dtf
                }
            }
            
            particles[i] = p
        }
    }

    private func updateFallInEvent() {
        guard fallInActivity > 0.05, blackHoleRadius > 0 else { return }
        guard time >= nextFallInEventTime else { return }

        fallInEventStartTime = time
        fallInEventDuration = Double(2.6 + 1.4 * CGFloat(rng.nextDouble(in: 0...1)))
        fallInEventAngle = CGFloat(rng.nextDouble(in: 0...(Double.pi * 2)))
        fallInEventRadius = blackHoleRadius * CGFloat(rng.nextDouble(in: 2.8...4.3))

        let cadence = Double(18.0 - min(1.0, fallInActivity) * 8.0)
        let jitter = rng.nextDouble(in: 0...5.0)
        nextFallInEventTime = time + cadence + jitter
    }

    private func fallInInfluence(for p: Particle) -> CGFloat {
        guard p.layer == 2, fallInActivity > 0.05 else { return 0 }

        let progress = CGFloat((time - fallInEventStartTime) / fallInEventDuration)
        guard progress >= 0, progress <= 1 else { return 0 }

        let angleDelta = abs(shortestAngleDelta(p.orbitAngle, fallInEventAngle))
        let angleWindow: CGFloat = 0.24 + 0.12 * fallInActivity
        guard angleDelta < angleWindow else { return 0 }

        let radialDelta = abs(p.baseOrbitRadius - fallInEventRadius)
        let radialWindow = blackHoleRadius * (0.45 + 0.25 * fallInActivity)
        guard radialDelta < radialWindow else { return 0 }

        let angularFalloff = 1.0 - angleDelta / angleWindow
        let radialFalloff = 1.0 - radialDelta / radialWindow
        let eventShape = sin(progress * .pi)
        let particleMask = 0.65 + 0.35 * CGFloat(sin(p.phase * 1.73))
        return max(0, angularFalloff * radialFalloff * eventShape * particleMask * fallInActivity)
    }

    private func flarePulse() -> CGFloat {
        let interval = 14.0
        let local = time.truncatingRemainder(dividingBy: interval) / interval
        guard local < 0.18 else { return 0 }
        let attack = min(1.0, local / 0.035)
        let decay = max(0, 1.0 - (local - 0.035) / 0.145)
        return smoothstep(CGFloat(attack)) * smoothstep(CGFloat(decay))
    }

    private func shortestAngleDelta(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        var delta = (a - b).truncatingRemainder(dividingBy: .pi * 2)
        if delta > .pi { delta -= .pi * 2 }
        if delta < -.pi { delta += .pi * 2 }
        return delta
    }

    private func densityWave(at angle: CGFloat, radius: CGFloat, index: Int) -> CGFloat {
        let centers: [CGFloat] = [0.35, 2.35, 4.45]
        let speeds: [CGFloat] = [0.18, -0.11, 0.07]
        let widths: [CGFloat] = [0.38, 0.28, 0.46]
        let radialCenters: [CGFloat] = [0.52, 0.78, 0.38]

        let centerAngle = centers[index] + CGFloat(time) * speeds[index]
        let angularDelta = abs(shortestAngleDelta(angle, centerAngle))
        let angularEnvelope = max(0, 1.0 - angularDelta / widths[index])
        let radialDelta = abs(radius - radialCenters[index])
        let radialEnvelope = max(0, 1.0 - radialDelta / 0.42)
        return pow(angularEnvelope, 2.0) * pow(radialEnvelope, 1.4)
    }

    private func horizonLensingOffset(x: CGFloat, y: CGFloat, baseRadius: CGFloat) -> CGFloat {
        guard lensingStrength > 0.01 else { return 0 }
        let radius = hypot(x, y)
        let rimDistance = abs(radius - blackHoleRadius * 1.22)
        let rimCompression = max(0, 1.0 - rimDistance / (blackHoleRadius * 0.95))
        let farSide = sin(atan2(y, x)) < 0 ? -1.0 : 1.0
        let rimArc = farSide * pow(rimCompression, 1.6) * blackHoleRadius * 0.28 * lensingStrength
        let grazing = max(0, 1.0 - abs(y) / max(1, baseRadius * 0.34))
        return rimArc + farSide * grazing * blackHoleRadius * 0.08 * lensingStrength
    }
    
    private func calculateBlackHolePosition(for p: inout Particle, dt: CGFloat) -> CGPoint {
        let center = blackHoleCenter
        
        switch p.layer {
        case 0:
            // Event horizon: slow swirl
            let baseSpeed: CGFloat = 0.15
            let speedVariation = 0.05 * CGFloat(sin(p.phase * 0.1))
            p.orbitAngle += (baseSpeed + speedVariation) * dt
            
            let pulseRadius = p.orbitRadius * (1.0 + 0.03 * CGFloat(sin(time * 1.5 + p.phase)))
            
            return CGPoint(
                x: center.x + cos(p.orbitAngle) * pulseRadius,
                y: center.y + sin(p.orbitAngle) * pulseRadius
            )
            
        case 1:
            // Photon ring: faster orbit
            let flare = flarePulse()
            let orbitSpeed: CGFloat = (1.8 + 0.3 * CGFloat(sin(p.phase * 0.5))) * speedMultiplier * (1.0 + photonFlashStrength * 0.35 + flare * 0.25)
            p.orbitAngle += orbitSpeed * dt
            
            let wobble = 2.0 * CGFloat(sin(time * 3.0 + p.phase * 2.0)) + flare * photonFlashStrength * blackHoleRadius * 0.05
            let effectiveRadius = p.orbitRadius + wobble
            
            return CGPoint(
                x: center.x + cos(p.orbitAngle) * effectiveRadius,
                y: center.y + sin(p.orbitAngle) * effectiveRadius
            )
            
        case 2:
            // Accretion disk
            let normalizedRadius = p.orbitRadius / (blackHoleRadius * 4.0)
            let fallIn = fallInInfluence(for: p)
            let baseOrbitSpeed: CGFloat = 2.5 / max(0.3, sqrt(normalizedRadius))
            let speedNoise = 0.2 * CGFloat(sin(p.phase + time * 0.5))
            p.orbitAngle += (baseOrbitSpeed + speedNoise + fallIn * 2.2) * speedMultiplier * dt
            
            // Slow 3D rotation oscillation for depth
            let baseTilt: CGFloat = 0.78
            let baseYaw: CGFloat = 0.35
            let tiltOsc = 0.08 * CGFloat(sin(time * 0.15))
            let yawOsc = 0.12 * CGFloat(sin(time * 0.12 + 0.5))
            let tilt = baseTilt + tiltOsc
            let yaw = baseYaw + yawOsc
            
            let wave1 = densityWave(at: p.orbitAngle, radius: normalizedRadius, index: 0)
            let wave2 = densityWave(at: p.orbitAngle, radius: normalizedRadius, index: 1)
            let wave3 = densityWave(at: p.orbitAngle, radius: normalizedRadius, index: 2)
            let densityPush = (wave1 * 13.0 - wave2 * 8.0 + wave3 * 5.0) * densityWaveStrength
            let armPhase = p.orbitAngle * 2.0 + p.phase * 0.1
            let armWobble = 8.0 * CGFloat(sin(armPhase + time * 0.3)) + densityPush
            
            let turbX = 3.0 * CGFloat(sin(time * 2.0 + p.phase * 3.0))
            let turbY = 3.0 * CGFloat(cos(time * 1.8 + p.phase * 2.5))
            
            let inward = fallIn * smoothstep(CGFloat((time - fallInEventStartTime) / fallInEventDuration)) * p.orbitRadius * 0.76
            let shearOutward = shearOutwardStrength * max(0, sin(p.orbitAngle * 2.0 + CGFloat(time) * 2.4 + CGFloat(p.phase))) * blackHoleRadius * 0.3
            let effectiveRadius = max(blackHoleRadius * 0.88, p.orbitRadius + armWobble - inward + shearOutward)
            
            let x = cos(p.orbitAngle) * effectiveRadius + turbX
            let y = sin(p.orbitAngle) * effectiveRadius * tilt + turbY
            let xr = x * cos(yaw) - y * sin(yaw)
            let yr = x * sin(yaw) + y * cos(yaw)
            let lens = horizonLensingOffset(x: xr, y: yr, baseRadius: effectiveRadius)
            
            return CGPoint(
                x: center.x + xr,
                y: center.y + yr + lens
            )
            
        case 3:
            // Lensing ring: vertical ring perpendicular to main disk (Interstellar effect)
            let normalizedRadius = p.orbitRadius / (blackHoleRadius * 4.0)
            let baseOrbitSpeed: CGFloat = 1.8 / max(0.3, sqrt(normalizedRadius))
            let speedNoise = 0.12 * CGFloat(sin(p.phase + time * 0.4))
            p.orbitAngle += (baseOrbitSpeed + speedNoise) * speedMultiplier * (1.0 + 0.2 * lensingStrength) * dt
            
            // Subtle oscillation for 3D depth feel
            let depthOsc = 0.04 * CGFloat(sin(time * 0.15))
            
            // Horizontal lensing ring: wraps left-right around the black hole - more circular
            let rimCompression = max(0, 1.0 - abs(sin(p.orbitAngle)) / 0.55) * (lensingStrength - 1.0) * 0.08
            let vertCompress: CGFloat = 0.42 + depthOsc - rimCompression
            
            let turbX = 1.5 * CGFloat(sin(time * 1.8 + p.phase * 2.5))
            let turbY = 1.5 * CGFloat(cos(time * 2.0 + p.phase * 3.0))
            
            let effectiveRadius = p.orbitRadius
            
            // Horizontal ring orientation: particles orbit left-right
            let x = cos(p.orbitAngle) * effectiveRadius + turbX
            let y = sin(p.orbitAngle) * effectiveRadius * vertCompress + turbY
            let lensArc = horizonLensingOffset(x: x, y: y, baseRadius: effectiveRadius) * 0.75
            
            return CGPoint(
                x: center.x + x,
                y: center.y + y + lensArc
            )
            
        default:
            return center
        }
    }

    func draw(in context: GraphicsContext, size: CGSize) {
        drawBlackHoleHybrid(in: context, size: size)
    }
    
    private func drawBlackHoleHybrid(in context: GraphicsContext, size: CGSize) {
        let center = blackHoleCenter
        
        // Calculate visual morph state - use the same wave as update
        let visualMorphStrength = currentMorphStrength * currentMorphWave
        let rareFlare = flarePulse()
        let flash = rareFlare * max(0.35, photonFlashStrength)
        let particleSizeScale = max(0.15, particleScale) * (1.0 + visualMorphStrength * 0.25)
        
        // Event horizon size shrinks more when morphing (particles escape)
        let eventHorizonScale = 1.0 - visualMorphStrength * 0.25
        let eventHorizonRadius = blackHoleRadius * 1.03 * eventHorizonScale
        let horizonRect = CGRect(
            x: center.x - eventHorizonRadius,
            y: center.y - eventHorizonRadius,
            width: eventHorizonRadius * 2,
            height: eventHorizonRadius * 2
        )
        
        // Multi-layered outer glow - dims when particles are forming shape
        let glowPulse = 0.8 + 0.2 * CGFloat(sin(time * 0.4)) + rareFlare * 0.45
        let morphGlowDim = 1.0 - visualMorphStrength * 0.4  // Glow dims as shape forms
        
        // Outermost ambient glow - use configurable color
        let outerGlowRadius = blackHoleRadius * (2.5 - visualMorphStrength * 0.5)
        let glowColor1 = Color(hue: Double(colorHueBase), saturation: Double(colorSaturation), brightness: 1.0)
        let glowColor2 = Color(hue: Double(colorHueBase + 0.02), saturation: Double(min(1.0, colorSaturation * 1.2)), brightness: 0.8)
        
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - outerGlowRadius,
                y: center.y - outerGlowRadius,
                width: outerGlowRadius * 2,
                height: outerGlowRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    glowColor1.opacity((0.08 + 0.05 * sideFlareStrength) * glowPulse * morphGlowDim),
                    glowColor2.opacity((0.03 + 0.06 * rareFlare) * morphGlowDim),
                    Color.clear
                ]),
                center: center,
                startRadius: blackHoleRadius * 1.2,
                endRadius: outerGlowRadius
            )
        )
        
        // Inner hot glow - also dims when morphing, uses configurable color
        let innerGlowRadius = blackHoleRadius * 1.6 * (1.0 - visualMorphStrength * 0.2)
        let hotGlowColor = Color(hue: Double(colorHueBase + 0.01), saturation: Double(colorSaturation * 0.9), brightness: 1.0)
        
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - innerGlowRadius,
                y: center.y - innerGlowRadius,
                width: innerGlowRadius * 2,
                height: innerGlowRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                        hotGlowColor.opacity((0.15 + 0.14 * rareFlare) * glowPulse * morphGlowDim),
                        glowColor1.opacity((0.08 + 0.08 * flash) * morphGlowDim),
                    Color.clear
                ]),
                center: center,
                startRadius: blackHoleRadius * 0.9,
                endRadius: innerGlowRadius
            )
        )

        drawSpacetimeWarpField(
            in: context,
            size: size,
            center: center,
            eventHorizonRadius: eventHorizonRadius,
            visualMorphStrength: visualMorphStrength,
            flash: flash
        )

        drawCinematicLensingBand(
            in: context,
            center: center,
            eventHorizonRadius: eventHorizonRadius,
            visualMorphStrength: visualMorphStrength,
            flash: flash,
            front: false
        )
        
        // Draw particles with depth sorting for lensing ring
        var baseCtx = context
        baseCtx.blendMode = .plusLighter
        
        // PASS 1: Draw BACK half of lensing ring (behind black hole)
        for p in particles where p.layer == 3 {
            // Back half: sin(orbitAngle) < 0 means particle is on far side
            if sin(p.orbitAngle) < 0 {
                drawLensingRingParticle(p, in: baseCtx, center: center, visualMorphStrength: visualMorphStrength)
            }
        }
        
        // PASS 2: Draw layers 0, 1, 2 (event horizon particles, photon ring, accretion disk)
        for p in particles where p.layer != 3 {
            let individualPulse = 0.7 + 0.3 * CGFloat(sin(time * Double(p.pulseSpeed) + Double(p.pulsePhase)))
            
            // Distance from center for color calculation
            let distFromCenter = hypot(p.position.x - center.x, p.position.y - center.y)
            let normalizedDist = distFromCenter / (blackHoleRadius * 4.0)
            
            // Color temperature based on distance
            var r: CGFloat, g: CGFloat, b: CGFloat
            
            // When morphing at high strength, particles become whiter/brighter (shape mode)
            let morphColorShift = visualMorphStrength
            
            if p.layer == 0 {
                // Event horizon particles - use mode color, brighter when morphing
                let pulse = 0.15 + 0.1 * individualPulse + visualMorphStrength * 0.4
                let hue = colorHueBase + p.hueShift * 0.1  // Use mode-based hue
                let saturation = max(0.2, colorSaturation * 0.8 - morphColorShift * 0.3)
                let brightness = 0.25 + morphColorShift * 0.5  // Brighter when morphing
                let color = Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness * p.brightness))
                let particleSize = p.baseSize * (0.8 + morphColorShift * 0.3) * particleSizeScale
                let opacity = pulse * p.brightness
                
                drawParticle(in: baseCtx, position: p.position, size: particleSize, glowSize: particleSize * 2.0, color: color, opacity: opacity, sharpness: morphColorShift)
                
            } else if p.layer == 1 {
                // Photon ring particles - use mode color, very bright when morphing
                let flicker = 0.6 + 0.4 * individualPulse
                let sparkle = max(0, sin(time * 8.0 + p.phase * 3.0))
                let hue = colorHueBase + p.hueShift * 0.05  // Use mode-based hue
                let saturation = max(0.15, colorSaturation * 0.5 - sparkle * 0.1)
                let color = Color(hue: Double(hue), saturation: Double(saturation), brightness: 1.0)
                let particleSize = p.baseSize * (0.9 + sparkle * 0.4 + morphColorShift * 0.2 + flash * 0.75 + photonFlashStrength * 0.18) * particleSizeScale
                let opacity = (flicker + sparkle * 0.3 + morphColorShift * 0.2 + flash * 1.2 + photonFlashStrength * 0.2) * p.brightness
                
                let speed = hypot(p.velocity.dx, p.velocity.dy)
                let trailStrength = min(1.0, speed / 130.0)
                if trailStrength > 0.05 {
                    let trailLength = particleSize * (5.0 + 6.0 * trailStrength)
                    let trailWidth = particleSize * (0.7 + 0.3 * trailStrength)
                    drawParticleTrail(
                        in: baseCtx,
                        position: p.position,
                        velocity: p.velocity,
                        length: trailLength,
                        width: trailWidth,
                        color: color,
                        opacity: opacity * (0.18 + 0.16 * trailStrength)
                    )
                }
                drawParticle(in: baseCtx, position: p.position, size: particleSize, glowSize: particleSize * 3.5, color: color, opacity: opacity, sharpness: morphColorShift)
                
            } else if p.layer == 2 {
                // Accretion disk particles - use configurable color scheme
                // Convert HSB to RGB for the base color
                let hue = colorHueBase
                let sat = colorSaturation
                let baseR = hueToRGB(hue: hue, saturation: sat, brightness: 1.0).r
                let baseG = hueToRGB(hue: hue, saturation: sat, brightness: 1.0).g
                let baseB = hueToRGB(hue: hue, saturation: sat, brightness: 1.0).b
                
                // Create temperature gradient based on distance
                if normalizedDist < 0.35 {
                    r = baseR
                    g = baseG * (0.85 + 0.15 * individualPulse)
                    b = baseB * (0.6 + 0.2 * individualPulse)
                } else if normalizedDist < 0.55 {
                    let t = (normalizedDist - 0.35) / 0.2
                    r = baseR
                    g = baseG * (0.85 - 0.35 * t)
                    b = baseB * (0.6 - 0.4 * t)
                } else if normalizedDist < 0.75 {
                    let t = (normalizedDist - 0.55) / 0.2
                    r = baseR * (1.0 - 0.1 * t)
                    g = baseG * (0.5 - 0.2 * t)
                    b = baseB * (0.2 - 0.1 * t)
                } else {
                    let t = min(1.0, (normalizedDist - 0.75) / 0.4)
                    r = baseR * (0.85 - 0.35 * t)
                    g = baseG * (0.22 - 0.12 * t)
                    b = baseB * (0.08 + 0.08 * t)
                }
                
                // Blend toward brighter version when morphing (shape becomes clearer)
                // Keep some of the base hue visible even when morphed
                // Doppler beaming - reduced when morphing (more uniform brightness)
                let angle = atan2(p.position.y - center.y, p.position.x - center.x)
                let beamingRaw = max(0, cos(angle - 0.5))
                let beamingBase = 0.14 + 0.98 * pow(beamingRaw, 2.9)
                let beaming = beamingBase * (1.0 - morphColorShift * 0.45) + morphColorShift * 0.65  // More uniform when morphing
                let flicker = 0.5 + 0.5 * individualPulse
                
                let wave1 = densityWave(at: p.orbitAngle, radius: normalizedDist, index: 0)
                let wave2 = densityWave(at: p.orbitAngle, radius: normalizedDist, index: 1)
                let wave3 = densityWave(at: p.orbitAngle, radius: normalizedDist, index: 2)
                let hotBand = max(wave1 * 1.15, max(wave2 * 0.95, wave3 * 0.8)) * densityWaveStrength
                let fallIn = fallInInfluence(for: p)
                let sideFlare = sideFlareStrength * pow(max(0, cos(angle - CGFloat(time) * 0.18 - 0.55)), 3.0)
                let flareSide = rareFlare * pow(max(0, cos(angle - 0.5)), 2.0)
                let spiralPhase = p.orbitAngle * 3.0 + normalizedDist * 6.0 - CGFloat(time) * 0.6
                let spiral = 0.72 + 0.24 * CGFloat(sin(spiralPhase)) + hotBand * 0.45
                let clumpSeed = CGFloat(sin(p.phase * 0.35 + time * 0.4))
                let clump = 0.8 + 0.18 * pow(max(0, clumpSeed), 2.0) + hotBand * 0.35 + fallIn * 0.8

                let brightBlend = morphColorShift * 0.5
                let innerHeat = max(0, 1.0 - normalizedDist / 0.58)
                let cinematicHeat = innerHeat * (0.25 + beaming * 0.45 + hotBand * 0.28 + flareSide * 0.35)
                r = min(1.0, r * (1.0 + brightBlend * 0.8) + cinematicHeat * 0.28)
                g = min(1.0, g * (1.0 + brightBlend * 0.6) + cinematicHeat * 0.34)
                b = min(1.0, b * (1.0 + brightBlend * 0.4) + cinematicHeat * 0.22)
                
                r = min(1.0, r + p.hueShift * 0.3)
                g = max(0, min(1.0, g + p.hueShift * 0.2))
                b = max(0, min(1.0, b))
                
                let color = Color(red: Double(r), green: Double(g), blue: Double(b))
                
                let particleSize = p.baseSize * (1.15 - 0.36 * min(1.0, normalizedDist) + morphColorShift * 0.2 + hotBand * 0.55 + fallIn * 0.8 + innerHeat * beaming * 0.22) * particleSizeScale
                let opacity = (0.2 + 0.7 * beaming * flicker + morphColorShift * 0.15 + sideFlare * 0.45 + flareSide * 0.7) * p.brightness * spiral * clump
                let glowSize = particleSize * (2.5 + 1.5 * (1.0 - min(1.0, normalizedDist)) + hotBand * 1.6 + fallIn * 2.2)
                
                let speed = hypot(p.velocity.dx, p.velocity.dy)
                let trailStrength = min(1.0, speed / 150.0 + fallIn * 0.95 + shearOutwardStrength * 0.25)
                if trailStrength > 0.1 {
                    let trailLength = particleSize * (4.0 + 5.0 * trailStrength + fallIn * 8.0)
                    let trailWidth = particleSize * (0.8 + 0.3 * trailStrength + fallIn * 0.25)
                    drawParticleTrail(
                        in: baseCtx,
                        position: p.position,
                        velocity: p.velocity,
                        length: trailLength,
                        width: trailWidth,
                        color: color,
                        opacity: opacity * (0.15 + 0.15 * trailStrength)
                    )
                }
                drawParticle(in: baseCtx, position: p.position, size: particleSize, glowSize: glowSize, color: color, opacity: opacity, sharpness: morphColorShift)
            }
        }
        
        // Draw event horizon on top: pure black-hole mode keeps a hard swallowing core.
        let horizonOpacity = max(0.08, 1.0 - visualMorphStrength * (0.82 / max(0.65, horizonDrama)))
        if horizonOpacity > 0.05 {
            var horizonCtx = context
            horizonCtx.opacity = horizonOpacity
            horizonCtx.fill(
                Path(ellipseIn: horizonRect),
                with: .radialGradient(
                    Gradient(colors: [
                        .black,
                        .black,
                        Color.black.opacity(0.95)
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: eventHorizonRadius
                )
            )
        }
        
        // PASS 3: Draw FRONT half of lensing ring (in front of black hole)
        for p in particles where p.layer == 3 {
            // Front half: sin(orbitAngle) >= 0 means particle is on near side
            if sin(p.orbitAngle) >= 0 {
                drawLensingRingParticle(p, in: baseCtx, center: center, visualMorphStrength: visualMorphStrength)
            }
        }

        drawCinematicLensingBand(
            in: context,
            center: center,
            eventHorizonRadius: eventHorizonRadius,
            visualMorphStrength: visualMorphStrength,
            flash: flash,
            front: true
        )
        
        // Photon sphere rings - fade out when morphing to not interfere with symbol
        let ringFade = max(0.05, 1.0 - visualMorphStrength * 0.8)  // Fade out when morphed
        if ringFade > 0.05 {
            var ringCtx = context
            ringCtx.blendMode = .plusLighter
            let ringPulse = (0.22 + 0.15 * CGFloat(sin(time * 0.8)) + 0.1 * CGFloat(sin(time * 2.3)) + flash * 1.2 + photonFlashStrength * 0.16) * ringFade
            ringCtx.opacity = ringPulse
            let photonSphereRadius = blackHoleRadius * (1.055 + horizonDrama * 0.012 + flash * 0.025) * eventHorizonScale
            let photonRect = CGRect(
                x: center.x - photonSphereRadius,
                y: center.y - photonSphereRadius,
                width: photonSphereRadius * 2,
                height: photonSphereRadius * 2
            )
            ringCtx.stroke(Path(ellipseIn: photonRect), with: .color(.white), lineWidth: 1.2 + horizonDrama * 0.35 + flash * 1.0)
            
            // Inner ring
            var innerRingCtx = context
            innerRingCtx.blendMode = .plusLighter
            innerRingCtx.opacity = ringPulse * (0.45 + horizonDrama * 0.12)
            let innerRingRadius = blackHoleRadius * 1.02 * eventHorizonScale
            let innerRingRect = CGRect(
                x: center.x - innerRingRadius,
                y: center.y - innerRingRadius,
                width: innerRingRadius * 2,
                height: innerRingRadius * 2
            )
            innerRingCtx.stroke(Path(ellipseIn: innerRingRect), with: .color(Color(red: 0.9, green: 0.95, blue: 1.0)), lineWidth: 0.8 + flash * 0.7)
        }
        
        // Faint lensing ring outside the disk - also fade when morphing
        var lensCtx = context
        lensCtx.blendMode = .plusLighter
        lensCtx.opacity = 0.06 * (1.0 - visualMorphStrength * 0.8)
        let lensRadius = blackHoleRadius * 3.6
        let lensRect = CGRect(
            x: center.x - lensRadius,
            y: center.y - lensRadius,
            width: lensRadius * 2,
            height: lensRadius * 2
        )
        lensCtx.stroke(Path(ellipseIn: lensRect), with: .color(Color(red: 0.85, green: 0.9, blue: 1.0)), lineWidth: 0.6)
    }

    private func drawSpacetimeWarpField(
        in context: GraphicsContext,
        size: CGSize,
        center: CGPoint,
        eventHorizonRadius: CGFloat,
        visualMorphStrength: CGFloat,
        flash: CGFloat
    ) {
        let blackHoleVisibility = 1.0 - smoothstep(min(1.0, max(0.0, visualMorphStrength * 1.25)))
        let strength = max(0.0, spacetimeWarpStrength) * blackHoleVisibility
        guard strength > 0.015 else { return }

        let maxRadius = min(min(size.width, size.height) * 0.52, blackHoleRadius * 5.1)
        guard maxRadius > eventHorizonRadius * 1.8 else { return }

        var meshCtx = context
        meshCtx.blendMode = .plusLighter

        let silver = Color(red: 0.82, green: 0.9, blue: 1.0)
        let hotEdge = Color(hue: Double(colorHueBase + 0.03), saturation: Double(min(1.0, colorSaturation * 0.85)), brightness: 1.0)
        let coldEdge = Color(red: 0.42, green: 0.58, blue: 0.82)
        let gradient = Gradient(colors: [
            coldEdge.opacity(0.06),
            silver.opacity(0.58 + flash * 0.18),
            hotEdge.opacity(0.38 + flash * 0.18),
            Color.white.opacity(0.24),
            coldEdge.opacity(0.05)
        ])

        for ringIndex in 0..<8 {
            let t = CGFloat(ringIndex) / 7.0
            let radius = eventHorizonRadius * (1.55 + t * 4.05)
            guard radius <= maxRadius else { continue }

            let opacity = (0.28 + 0.16 * (1.0 - t)) * strength * (1.0 + flash * 0.4)
            let lineWidth = (0.55 + 1.25 * pow(1.0 - t, 1.6)) * strength

            var ringCtx = meshCtx
            ringCtx.opacity = opacity
            ringCtx.stroke(
                warpedEllipsePath(
                    center: center,
                    radius: radius,
                    verticalScale: 0.34 + t * 0.22,
                    yaw: 0.42 + 0.05 * CGFloat(sin(time * 0.18)),
                    rippleAmount: eventHorizonRadius * (0.06 + 0.10 * (1.0 - t)) * strength,
                    phase: CGFloat(time) * (0.35 + 0.12 * t) + t * 3.4
                ),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: center.x - radius, y: center.y - radius * 0.6),
                    endPoint: CGPoint(x: center.x + radius, y: center.y + radius * 0.6)
                ),
                lineWidth: lineWidth
            )
        }

        for spokeIndex in 0..<10 {
            let angle = CGFloat(spokeIndex) / 10.0 * .pi * 2 + CGFloat(time) * 0.08
            var spokeCtx = meshCtx
            spokeCtx.opacity = 0.085 * strength * (1.0 + flash * 0.25)
            spokeCtx.stroke(
                warpedSpokePath(
                    center: center,
                    angle: angle,
                    startRadius: eventHorizonRadius * 1.35,
                    endRadius: maxRadius * 0.92,
                    verticalScale: 0.48,
                    yaw: 0.42,
                    rippleAmount: eventHorizonRadius * 0.12 * strength,
                    phase: CGFloat(time) * 0.45 + CGFloat(spokeIndex)
                ),
                with: .linearGradient(
                    Gradient(colors: [
                        Color.clear,
                        silver.opacity(0.42),
                        hotEdge.opacity(0.26),
                        Color.clear
                    ]),
                    startPoint: center,
                    endPoint: CGPoint(
                        x: center.x + cos(angle) * maxRadius,
                        y: center.y + sin(angle) * maxRadius * 0.48
                    )
                ),
                lineWidth: 0.35 + 0.5 * strength
            )
        }
    }

    private func warpedEllipsePath(
        center: CGPoint,
        radius: CGFloat,
        verticalScale: CGFloat,
        yaw: CGFloat,
        rippleAmount: CGFloat,
        phase: CGFloat
    ) -> Path {
        let segments = 144
        var path = Path()

        for index in 0...segments {
            let progress = CGFloat(index) / CGFloat(segments)
            let angle = progress * .pi * 2
            let ripple = sin(angle * 3.0 + phase) * rippleAmount + sin(angle * 7.0 - phase * 0.7) * rippleAmount * 0.32
            let r = radius + ripple
            let x = cos(angle) * r
            let y = sin(angle) * r * verticalScale
            let rotated = rotate(x: x, y: y, yaw: yaw)
            let point = CGPoint(x: center.x + rotated.x, y: center.y + rotated.y)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }

    private func warpedSpokePath(
        center: CGPoint,
        angle: CGFloat,
        startRadius: CGFloat,
        endRadius: CGFloat,
        verticalScale: CGFloat,
        yaw: CGFloat,
        rippleAmount: CGFloat,
        phase: CGFloat
    ) -> Path {
        let segments = 28
        var path = Path()

        for index in 0...segments {
            let t = CGFloat(index) / CGFloat(segments)
            let radius = startRadius + (endRadius - startRadius) * t
            let shear = sin(t * .pi * 2.0 + phase) * rippleAmount * (1.0 - t * 0.45)
            let warpedAngle = angle + shear / max(1.0, radius)
            let x = cos(warpedAngle) * radius
            let y = sin(warpedAngle) * radius * verticalScale
            let rotated = rotate(x: x, y: y, yaw: yaw)
            let point = CGPoint(x: center.x + rotated.x, y: center.y + rotated.y)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }

    private func rotate(x: CGFloat, y: CGFloat, yaw: CGFloat) -> CGPoint {
        CGPoint(
            x: x * cos(yaw) - y * sin(yaw),
            y: x * sin(yaw) + y * cos(yaw)
        )
    }
    
    private func drawParticle(in context: GraphicsContext, position: CGPoint, size: CGFloat, glowSize: CGFloat, color: Color, opacity: CGFloat, sharpness: CGFloat = 0.0) {
        // sharpness: 0 = full glow (black hole mode), 1 = minimal glow (sharp symbol mode)
        let glowFade = 1.0 - sharpness * 0.7  // Reduce glow when sharp
        
        // Outer glow - fades significantly when sharp
        if glowFade > 0.1 {
            var glowC = context
            glowC.opacity = opacity * 0.25 * glowFade
            let actualGlowSize = glowSize * (1.0 - sharpness * 0.5)
            let glowDot = Path(ellipseIn: CGRect(x: 0, y: 0, width: actualGlowSize, height: actualGlowSize))
            glowC.translateBy(x: position.x - actualGlowSize / 2, y: position.y - actualGlowSize / 2)
            glowC.fill(glowDot, with: .color(color))
        }
        
        // Mid glow - shrinks when sharp
        var midGlowC = context
        midGlowC.opacity = opacity * 0.45 * (1.0 - sharpness * 0.3)
        let midSize = size * (1.8 - sharpness * 0.6)  // 1.8 -> 1.2 when sharp
        let midDot = Path(ellipseIn: CGRect(x: 0, y: 0, width: midSize, height: midSize))
        midGlowC.translateBy(x: position.x - midSize / 2, y: position.y - midSize / 2)
        midGlowC.fill(midDot, with: .color(color))
        
        // Core - stays solid, slightly larger when sharp for definition
        var coreC = context
        coreC.opacity = opacity * (0.9 + sharpness * 0.1)  // Slightly more opaque when sharp
        let coreSize = size * (1.0 + sharpness * 0.15)  // Slightly larger core when sharp
        let dot = Path(ellipseIn: CGRect(x: 0, y: 0, width: coreSize, height: coreSize))
        coreC.translateBy(x: position.x - coreSize / 2, y: position.y - coreSize / 2)
        coreC.fill(dot, with: .color(color))
    }
    
    private func drawParticleTrail(
        in context: GraphicsContext,
        position: CGPoint,
        velocity: CGVector,
        length: CGFloat,
        width: CGFloat,
        color: Color,
        opacity: CGFloat
    ) {
        let speed = hypot(velocity.dx, velocity.dy)
        guard speed > 0.001 else { return }
        
        var trailCtx = context
        trailCtx.opacity = opacity
        
        let angle = atan2(velocity.dy, velocity.dx)
        trailCtx.translateBy(x: position.x, y: position.y)
        trailCtx.rotate(by: .radians(Double(angle)))
        trailCtx.translateBy(x: -length * 0.6, y: -width / 2)
        
        let rect = CGRect(x: 0, y: 0, width: length, height: width)
        trailCtx.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(color))
    }

    private func drawCinematicLensingBand(
        in context: GraphicsContext,
        center: CGPoint,
        eventHorizonRadius: CGFloat,
        visualMorphStrength: CGFloat,
        flash: CGFloat,
        front: Bool
    ) {
        let fade = max(0, 1.0 - visualMorphStrength * 0.75)
        guard fade > 0.02 else { return }

        var bandCtx = context
        bandCtx.blendMode = .plusLighter
        bandCtx.opacity = (front ? 0.42 : 0.24) * fade * (1.0 + flash * 0.7)
        bandCtx.translateBy(x: center.x, y: center.y + (front ? eventHorizonRadius * 0.16 : -eventHorizonRadius * 0.11))
        bandCtx.scaleBy(x: 1.55, y: front ? 0.34 : 0.42)

        let radius = eventHorizonRadius * (front ? 1.09 : 1.16)
        let start = Angle.degrees(front ? 18 : 198)
        let end = Angle.degrees(front ? 162 : 342)
        var arc = Path()
        arc.addArc(center: .zero, radius: radius, startAngle: start, endAngle: end, clockwise: false)

        let hotColor = Color(red: 1.0, green: 0.9, blue: 0.58)
        bandCtx.stroke(arc, with: .color(hotColor), lineWidth: (front ? 2.0 : 1.5) + flash * 1.4)

        var whiteCoreCtx = bandCtx
        whiteCoreCtx.opacity *= 0.55
        whiteCoreCtx.stroke(arc, with: .color(Color(red: 0.98, green: 0.98, blue: 1.0)), lineWidth: (front ? 0.75 : 0.55) + flash * 0.6)
    }
    
    private func drawLensingRingParticle(_ p: Particle, in context: GraphicsContext, center: CGPoint, visualMorphStrength: CGFloat) {
        let individualPulse = 0.7 + 0.3 * CGFloat(sin(time * Double(p.pulseSpeed) + Double(p.pulsePhase)))
        let rareFlare = flarePulse()
        
        let distFromCenter = hypot(p.position.x - center.x, p.position.y - center.y)
        let normalizedDist = distFromCenter / (blackHoleRadius * 4.0)
        
        let morphColorShift = visualMorphStrength
        
        // Use mode-based color for lensing ring
        let baseRGB = hueToRGB(hue: colorHueBase, saturation: colorSaturation, brightness: 1.0)
        var r: CGFloat, g: CGFloat, b: CGFloat
        
        // Create temperature gradient based on distance using mode color
        if normalizedDist < 0.35 {
            r = baseRGB.r
            g = baseRGB.g * (0.9 + 0.1 * individualPulse)
            b = baseRGB.b * (0.7 + 0.15 * individualPulse)
        } else if normalizedDist < 0.55 {
            let t = (normalizedDist - 0.35) / 0.2
            r = baseRGB.r
            g = baseRGB.g * (0.9 - 0.35 * t)
            b = baseRGB.b * (0.7 - 0.45 * t)
        } else if normalizedDist < 0.75 {
            let t = (normalizedDist - 0.55) / 0.2
            r = baseRGB.r * (1.0 - 0.05 * t)
            g = baseRGB.g * (0.55 - 0.2 * t)
            b = baseRGB.b * (0.25 - 0.12 * t)
        } else {
            let t = min(1.0, (normalizedDist - 0.75) / 0.4)
            r = baseRGB.r * (0.95 - 0.4 * t)
            g = baseRGB.g * (0.35 - 0.2 * t)
            b = baseRGB.b * (0.13 + 0.05 * t)
        }
        
        // Blend toward brighter when morphing (keep some hue visible)
        let brightBlend = morphColorShift * 0.5
        r = min(1.0, r * (1.0 + brightBlend * 0.8))
        g = min(1.0, g * (1.0 + brightBlend * 0.6))
        b = min(1.0, b * (1.0 + brightBlend * 0.4))
        
        r = min(1.0, r + p.hueShift * 0.25)
        g = max(0, min(1.0, g + p.hueShift * 0.15))
        b = max(0, min(1.0, b))
        
        let color = Color(red: Double(r), green: Double(g), blue: Double(b))
        
        // Beaming for horizontal ring (left/right brightness variation)
        let horizAngle = atan2(p.position.y - center.y, p.position.x - center.x)
        let beamingRaw = max(0, abs(cos(horizAngle)))
        let beamingBase = 0.35 + 0.65 * pow(beamingRaw, 1.8)
        let beaming = beamingBase * (1.0 - morphColorShift * 0.4) + morphColorShift * 0.6
        let flicker = 0.6 + 0.4 * individualPulse
        
        // Intersection boost: particles near horizontal axis (where rings cross) get extra glow
        let yOffset = abs(p.position.y - center.y)
        let intersectionZone = max(0, 1.0 - yOffset / (blackHoleRadius * 1.5))
        let rimZone = max(0, 1.0 - abs(distFromCenter - blackHoleRadius * 1.25) / (blackHoleRadius * 0.9))
        let intersectionBoost = pow(intersectionZone, 2.0) * 0.5 + pow(rimZone, 2.0) * 0.45 * lensingStrength
        
        let particleSizeScale = max(0.15, particleScale) * (1.0 + visualMorphStrength * 0.25)
        let particleSize = p.baseSize * (1.1 - 0.3 * min(1.0, normalizedDist) + morphColorShift * 0.2 + intersectionBoost * 0.3 + rareFlare * 0.35) * particleSizeScale
        let opacity = (0.25 + 0.45 * beaming * flicker + morphColorShift * 0.12 + intersectionBoost * 0.25 + rareFlare * 0.45) * p.brightness * 0.85
        let glowSize = particleSize * (2.2 + 1.2 * (1.0 - min(1.0, normalizedDist)) + intersectionBoost * 1.5 + lensingStrength * 0.45)
        
        let speed = hypot(p.velocity.dx, p.velocity.dy)
        let trailStrength = min(1.0, speed / 140.0 + rimZone * 0.35 * lensingStrength)
        if trailStrength > 0.08 {
            let trailLength = particleSize * (4.5 + 5.0 * trailStrength)
            let trailWidth = particleSize * (0.75 + 0.3 * trailStrength)
            drawParticleTrail(
                in: context,
                position: p.position,
                velocity: p.velocity,
                length: trailLength,
                width: trailWidth,
                color: color,
                opacity: opacity * (0.14 + 0.14 * trailStrength)
            )
        }
        drawParticle(in: context, position: p.position, size: particleSize, glowSize: glowSize, color: color, opacity: opacity, sharpness: morphColorShift)
    }
    
    /// Convert HSB color to RGB components
    private func hueToRGB(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let h = hue
        let s = saturation
        let v = brightness
        
        let c = v * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        let hSegment = h * 6
        if hSegment < 1 {
            r = c; g = x; b = 0
        } else if hSegment < 2 {
            r = x; g = c; b = 0
        } else if hSegment < 3 {
            r = 0; g = c; b = x
        } else if hSegment < 4 {
            r = 0; g = x; b = c
        } else if hSegment < 5 {
            r = x; g = 0; b = c
        } else {
            r = c; g = 0; b = x
        }
        
        return (r + m, g + m, b + m)
    }
}

/// Tiny deterministic RNG.
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    mutating func nextUInt64() -> UInt64 {
        var x = state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        state = x
        return x &* 2685821657736338717
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let u = Double(nextUInt64() >> 11) / Double(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * u
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
