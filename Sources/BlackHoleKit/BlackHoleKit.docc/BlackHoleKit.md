# ``BlackHoleKit``

Render a SwiftUI particle field that cycles between a procedural black hole and a readable morph target.

## Overview

`BlackHoleParticleMorphView` owns a deterministic CPU particle simulation and draws it with SwiftUI `Canvas`. The base state is a black hole with an event horizon, photon ring, accretion disk, lensing band, metallic spacetime warp mesh, and small flare events. When given a non-black-hole target, the particle field periodically forms that target and then falls back into orbital motion.

Use the package for decorative or stateful visual surfaces where the black hole itself is the primary effect.

```swift
BlackHoleParticleMorphView(
    target: .text("OK"),
    visualConfig: .init(
        colorHue: 0.33,
        speedMultiplier: 0.8,
        particleScale: 0.72,
        spacetimeWarpStrength: 1.0
    )
)
```

## Topics

### Rendering

- ``BlackHoleParticleMorphView``

### Targets

- ``BlackHoleParticleMorphTarget``

### Styling

- ``BlackHoleParticleVisualConfig``
