# ``BlackHoleKit``

Render a SwiftUI particle field that cycles between a procedural black hole and a readable morph target.

## Overview

`BlackHoleParticleMorphView` owns a deterministic CPU particle simulation and draws it with SwiftUI `Canvas`. The base state is a black hole with an event horizon, photon ring, Doppler-asymmetric accretion disk, lensed disk particles, mostly black rotating star background, a bundled Metal spacetime lens, and small flare events. Metal owns only the background deflection, warp-only singularity, nested photon response, chromatic separation, and refractive shell. When given a non-black-hole target, the particle field periodically forms that target and then falls back into orbital motion.

Use the package for decorative or stateful visual surfaces where the black hole itself is the primary effect.

```swift
BlackHoleParticleMorphView(
    target: .text("OK"),
    visualConfig: .init(
        colorHue: 0.33,
        speedMultiplier: 0.8,
        particleScale: 0.72,
        spacetimeWarpStrength: 1.0,
        spaceBackgroundStrength: 1.0
    )
)
```

Use `showsParticles` and `showsWarp` independently to select any of the four rendering combinations. To lens caller-supplied pixels directly, apply ``SwiftUI/View/blackHoleLens(configuration:isEnabled:)`` with a ``BlackHoleLensConfiguration``.

## Topics

### Rendering

- ``BlackHoleParticleMorphView``
- ``BlackHoleLensModifier``
- ``BlackHoleLensConfiguration``

### Targets

- ``BlackHoleParticleMorphTarget``

### Styling

- ``BlackHoleParticleVisualConfig``
