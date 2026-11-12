# BlackHoleKit

SwiftUI package for the particle morph black hole effect.

The package renders a CPU-driven particle field with SwiftUI `Canvas`. Particles orbit a procedural black hole and can periodically morph into text, SF Symbols, or a built-in classic Mac silhouette before falling back into the accretion flow. The built-in background uses a bundled Metal lens shader so the starfield bends and rotates with the black hole.

[Watch the original macOS desktop prototype on X](https://x.com/AndreasInk/status/2099759676246167956).

## Installation

Use it as a local or Git Swift Package dependency:

```swift
.package(url: "https://github.com/AndreasInk/BlackHoleKit.git", branch: "main")
```

Then add the `BlackHoleKit` product to your app target.

## Basic Usage

```swift
import SwiftUI
import BlackHoleKit

struct HeroView: View {
    var body: some View {
        BlackHoleParticleMorphView(
            target: .sfSymbol("sparkles"),
            visualConfig: .init(
                colorHue: 0.55,
                colorSaturation: 0.75,
                speedMultiplier: 0.9,
                particleScale: 0.72,
                spacetimeWarpStrength: 1.0,
                spaceBackgroundStrength: 1.0
            ),
            particleCount: 1_760
        )
        .frame(width: 420, height: 420)
    }
}
```

## Public API

`BlackHoleParticleMorphView` is the main SwiftUI view. It accepts:

- `target`: `.blackHole`, `.classicMac`, `.text(String)`, or `.sfSymbol(String)`.
- `visualConfig`: hue, saturation, speed, particle scale, lensing, spacetime warp, background, flare, and disk-motion controls.
- `particleCount`: number of simulated particles. The default is `2_800`, or `1_800` in Xcode previews.
- `pointSampleStep`: raster sampling stride for text and symbol targets. Lower values are more detailed and more expensive.
- `seed`: deterministic seed for repeatable particle initialization.

`BlackHoleParticleVisualConfig` is intentionally generic. App-specific state mapping should live in the host app. `showsParticles` and `showsWarp` default to `true` and can be changed independently, covering particles + warp, particles only, warp only, and untouched background.

By default, particles render smaller than the original extraction and the black-hole state includes a mostly black, rotating mesh-gradient space background with distant stars. The bundled Metal lens bends that background behind the event horizon, while the foreground particles stay sharp. The metal warp fades out as particles form a text or symbol target, so foreground morphs stay readable. Set `spaceBackgroundStrength` to `0` if the host app should provide its own background.

`blackHoleLens(...)` is also public as a standalone SwiftUI modifier for applying the same bundled Metal lens to other views. Use `BlackHoleLensConfiguration` to tune center, radius, strength, spin, darkness, glow, caustics, chromatic separation, and animation speed. The cinematic default includes bounded gravitational deflection, an opaque event horizon, nested photon curves, and a refractive shell. The particle foreground owns the accretion disk, Doppler asymmetry, and lensed disk particles so those elements are not duplicated by Metal.

```swift
desktopPixels.blackHoleLens(
    configuration: .init(
        radius: 220,
        strength: 1.25,
        spin: 0.9,
        glow: 1.1,
        causticStrength: 1.3,
        chromaticAberration: 0.55
    )
)
```

See [`Examples/BlackHoleEffectDemo`](Examples/BlackHoleEffectDemo) for a focused macOS sample that requests Screen Recording permission, captures the pixels behind its window, and applies the lens effect to them. The sample intentionally omits host-app behavior such as app consumption, restore scheduling, and production overlay controls.

## Platform Notes

The package uses SwiftUI `Canvas`, `GraphicsContext`, and `ImageRenderer`.

Supported package floors:

- iOS 17+
- macOS 14+
- visionOS 1+

The package focuses on the particle morph effect. Reflection shaders, overlays, and separate volumetric scenes belong in the host app's presentation layer.

## Verification

Open the package to build the library and run its tests. To exercise real desktop distortion, open `Examples/BlackHoleEffectDemo/BlackHoleEffectDemo.xcodeproj`, run the `BlackHoleEffectDemo` scheme on My Mac, and grant Screen Recording permission when prompted.

The tests cover defaults, source-compatible forwarding, configuration clamping, deterministic particle behavior, and all four particle/warp combinations.

## License

BlackHoleKit is available under the MIT License. See `LICENSE.md` for details.
