# BlackHoleKit

SwiftUI package for the particle morph black hole effect.

The package renders a CPU-driven particle field with SwiftUI `Canvas`. Particles orbit a procedural black hole and can periodically morph into text, SF Symbols, or a built-in classic Mac silhouette before falling back into the accretion flow.




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
- `particleCount`: number of simulated particles. The default is `1_760`, or `1_200` in Xcode previews.
- `pointSampleStep`: raster sampling stride for text and symbol targets. Lower values are more detailed and more expensive.
- `seed`: deterministic seed for repeatable particle initialization.

`BlackHoleParticleVisualConfig` is intentionally generic. App-specific state mapping should live in the host app.

By default, particles render smaller than the original extraction and the black-hole state includes a mostly black mesh-gradient space background with distant stars. The metallic spacetime warp mesh fades out as particles form a text or symbol target, so foreground morphs stay readable. Set `spaceBackgroundStrength` to `0` if the host app should provide its own background.

## Platform Notes

The package uses SwiftUI `Canvas`, `GraphicsContext`, and `ImageRenderer`.

Supported package floors:

- iOS 17+
- macOS 14+
- visionOS 1+

The package focuses on the particle morph effect. Reflection shaders, overlays, and separate volumetric scenes belong in the host app's presentation layer.

## Verification

From this directory:

```sh
swift build
swift test
```

The tests cover the public initializer, deterministic black hole point generation, and particle simulation advancement. Visual quality still requires screenshot or preview inspection in a host app.

## License

BlackHoleKit is available under the MIT License. See `LICENSE.md` for details.
