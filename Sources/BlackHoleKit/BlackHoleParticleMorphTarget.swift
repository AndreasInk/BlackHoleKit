import CoreGraphics

/// A destination that the particle cloud can form before falling back into the black hole flow.
public enum BlackHoleParticleMorphTarget: Hashable {
    /// The procedural black hole and accretion disk with no foreground shape target.
    case blackHole

    /// A built-in pixel-art inspired classic Mac silhouette.
    case classicMac

    /// A rasterized text target rendered with a heavy rounded system font.
    case text(String)

    /// A rasterized SF Symbol target rendered in monochrome.
    case sfSymbol(String)
}
