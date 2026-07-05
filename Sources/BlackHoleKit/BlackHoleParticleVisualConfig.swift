import CoreGraphics

/// Visual and motion controls for ``BlackHoleParticleMorphView``.
public struct BlackHoleParticleVisualConfig: Equatable {
    /// Base hue in SwiftUI's normalized 0...1 hue space. The default is warm orange.
    public var colorHue: CGFloat

    /// Particle color saturation in normalized 0...1 space.
    public var colorSaturation: CGFloat

    /// Overall particle motion multiplier. Set this to `0` for nearly static previews.
    public var speedMultiplier: CGFloat

    /// Multiplier applied to particle cores, trails, and glows.
    public var particleScale: CGFloat

    /// Speed of the shape-to-black-hole morph cycle. The default is roughly a twelve second loop.
    public var morphCycleSpeed: CGFloat

    /// Strength of hot spots and spiral density waves in the accretion disk.
    public var densityWaveStrength: CGFloat

    /// Frequency and intensity of particles falling toward the event horizon.
    public var fallInActivity: CGFloat

    /// Strength of the curved light band around the event horizon.
    public var lensingStrength: CGFloat

    /// Strength of the metallic spacetime warp field visible when a morph target is not formed.
    public var spacetimeWarpStrength: CGFloat

    /// Opacity of the built-in dark mesh-gradient space background and distant stars.
    public var spaceBackgroundStrength: CGFloat

    /// Contrast and persistence of the dark event horizon.
    public var horizonDrama: CGFloat

    /// Intensity of rare bright photon-ring flashes.
    public var photonFlashStrength: CGFloat

    /// Strength of directional side flares in the disk.
    public var sideFlareStrength: CGFloat

    /// Strength of outward shearing motion in the disk.
    public var shearOutwardStrength: CGFloat

    public init(
        colorHue: CGFloat = 0.08,
        colorSaturation: CGFloat = 0.8,
        speedMultiplier: CGFloat = 1.0,
        particleScale: CGFloat = 0.72,
        morphCycleSpeed: CGFloat = 0.52,
        densityWaveStrength: CGFloat = 1.0,
        fallInActivity: CGFloat = 0.7,
        lensingStrength: CGFloat = 1.0,
        spacetimeWarpStrength: CGFloat = 1.0,
        spaceBackgroundStrength: CGFloat = 1.0,
        horizonDrama: CGFloat = 1.0,
        photonFlashStrength: CGFloat = 0.0,
        sideFlareStrength: CGFloat = 0.0,
        shearOutwardStrength: CGFloat = 0.0
    ) {
        self.colorHue = colorHue
        self.colorSaturation = colorSaturation
        self.speedMultiplier = speedMultiplier
        self.particleScale = particleScale
        self.morphCycleSpeed = morphCycleSpeed
        self.densityWaveStrength = densityWaveStrength
        self.fallInActivity = fallInActivity
        self.lensingStrength = lensingStrength
        self.spacetimeWarpStrength = spacetimeWarpStrength
        self.spaceBackgroundStrength = spaceBackgroundStrength
        self.horizonDrama = horizonDrama
        self.photonFlashStrength = photonFlashStrength
        self.sideFlareStrength = sideFlareStrength
        self.shearOutwardStrength = shearOutwardStrength
    }
}
