#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static inline float2 rotate2D(float2 p, float radians) {
    float s = sin(radians);
    float c = cos(radians);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// A SwiftUI layer shader that bends pixels inside a circular radius, creating
// a gravitational-lensing / black-hole effect with a soft event horizon.
//
// SwiftUI calls this for each pixel in the affected view. `layer.sample(...)`
// reads from the rendered view texture at the requested coordinate.
[[ stitchable ]]
half4 blackHoleLens(
    float2 position,
    SwiftUI::Layer layer,
    float2 center,
    float2 layerSize,
    float radius,
    float strength,
    float spin,
    float darkness,
    float glow,
    float causticStrength,
    float chromaticAberration,
    float animationSpeed,
    float time
) {
    half4 original = layer.sample(position);

    radius = max(radius, 1.0);
    strength = clamp(strength, 0.0, 1.5);
    spin = clamp(spin, -2.0, 2.0);
    darkness = clamp(darkness, 0.0, 1.0);
    glow = clamp(glow, 0.0, 2.0);
    causticStrength = clamp(causticStrength, 0.0, 2.0);
    chromaticAberration = clamp(chromaticAberration, 0.0, 1.0);
    animationSpeed = clamp(animationSpeed, 0.0, 3.0);
    float effectAmount = smoothstep(0.0, 0.02, strength);
    float motionTime = time * animationSpeed;
    float radiusPulse = 1.0 + sin(motionTime * 0.32) * 0.068;
    radius *= radiusPulse;

    float2 delta = position - center;
    float dist = length(delta);

    if (dist >= radius) {
        return original;
    }

    float dist01 = clamp(dist / radius, 0.0, 1.0);
    float horizon = radius * 0.18;
    float outerFalloff = 1.0 - smoothstep(0.64, 1.0, dist01);
    float innerLensRamp = smoothstep(0.205, 0.30, dist01);
    float lensEnvelope = innerLensRamp * outerFalloff;
    float2 direction = delta / max(dist, 1.0);
    float azimuth = atan2(delta.y, delta.x);

    // Inverse-impact mapping: pixels nearer the horizon sample farther out, but the finite
    // denominator and mapping limit keep the event horizon stable instead of exploding inward.
    float inverseImpact = 1.0 / max(dist01, 0.14);
    float gravity = pow(1.0 - dist01, 1.85) * lensEnvelope;
    float deflection = min(strength * radius * 0.17 * gravity * inverseImpact, radius * 0.56);
    float phase = sin(motionTime * 0.55);
    float criticalShear = exp(-pow((dist01 - 0.34) / 0.24, 2.0));
    float swirl = spin * effectAmount * gravity * criticalShear * (0.16 + 0.05 * phase)
        + sin(motionTime * 0.24 + dist01 * 3.0) * gravity * 0.018;
    float2 shearedDelta = rotate2D(delta, swirl);
    float2 shearedDirection = shearedDelta / max(length(shearedDelta), 1.0);
    float mappedRadius = max(horizon * 1.08, dist - deflection);
    float2 source = center + shearedDirection * mappedRadius;

    float maxOffset = radius * (1.0 + strength * 0.72);
    float2 offset = source - position;
    float offsetLength = length(offset);
    if (offsetLength > maxOffset) {
        offset *= maxOffset / offsetLength;
        source = position + offset;
    }
    float2 sampleMax = max(layerSize - float2(1.0), float2(0.0));
    source = clamp(source, float2(0.0), sampleMax);

    half4 warped = layer.sample(source);
    float warpAmount = lensEnvelope * effectAmount;
    float outputAlpha = mix(float(original.a), float(warped.a), warpAmount);
    float3 originalStraight = float3(original.rgb) / max(float(original.a), 0.0001);
    float3 warpedStraight = float3(warped.rgb) / max(float(warped.a), 0.0001);
    float3 color = mix(originalStraight, warpedStraight, warpAmount);

    float photonSphere = radius * 0.292;
    float ringWidth = max(radius * 0.018, 0.85);
    float primaryRing = exp(-pow((dist - photonSphere) / ringWidth, 2.0));
    float secondaryRing = exp(-pow(
        (dist - radius * 0.268) / max(radius * 0.007, 0.65),
        2.0
    ));
    float ring = (primaryRing + secondaryRing * 0.22) * effectAmount;
    ring *= 0.72 + 0.28 * sin(azimuth - motionTime * 0.34);
    float caustic = exp(-pow((dist - radius * 0.47) / max(radius * 0.034, 1.0), 2.0));
    float causticAxis = azimuth - motionTime * 0.10 * spin;
    float causticArcs = pow(abs(sin(causticAxis)), 5.0);
    caustic *= causticStrength * outerFalloff * (0.80 + 0.20 * phase)
        * (0.025 + causticArcs * 0.72);

    // A narrow refractive shell gives the horizon a liquid-glass compression edge. It samples
    // the already-warped scene rather than painting an opaque ring, so detail remains visible
    // through the material. The moving highlight follows the same bounded orbital motion.
    float glassCenter = radius * 0.305;
    float glassWidth = max(radius * 0.016, 0.85);
    float glassBand = exp(-pow((dist - glassCenter) / glassWidth, 2.0)) * effectAmount;
    if (glassBand > 0.002) {
        float orbitalHighlight = pow(
            clamp(0.5 + 0.5 * cos(azimuth - motionTime * 0.68 - 0.65), 0.0, 1.0),
            7.0
        );
        float counterHighlight = pow(
            clamp(0.5 + 0.5 * cos(azimuth - motionTime * 0.68 + 2.45), 0.0, 1.0),
            12.0
        );
        float glassVisibility = 0.025 + orbitalHighlight * 0.58 + counterHighlight * 0.18;
        glassBand *= glassVisibility;
        float glassRefraction = radius * 0.024 * glassBand;
        float2 glassPosition = clamp(source + direction * glassRefraction, float2(0.0), sampleMax);
        half4 glassSample = layer.sample(glassPosition);
        float3 glassStraight = float3(glassSample.rgb) / max(float(glassSample.a), 0.0001);
        color = mix(color, glassStraight, glassBand * 0.24);

        float innerEdge = exp(-pow((dist - (glassCenter - glassWidth * 0.72))
            / max(glassWidth * 0.22, 0.75), 2.0));
        float outerEdge = exp(-pow((dist - (glassCenter + glassWidth * 0.72))
            / max(glassWidth * 0.26, 0.75), 2.0));
        float glassFresnel = glassBand * (0.08 + orbitalHighlight * 0.66 + counterHighlight * 0.20);
        float edgeGlint = (innerEdge * 0.38 + outerEdge * 0.62)
            * (0.28 + orbitalHighlight * 0.72) * effectAmount;
        color += float3(0.56, 0.78, 1.0) * glassFresnel * glow * 0.30;
        color += float3(0.82, 0.94, 1.0) * edgeGlint * glow * 0.24;
    }

    // The split is deliberately localized to the photon ring and remains within maxSampleOffset.
    float split = radius * chromaticAberration * (ring + caustic * 0.08) * 0.050;
    float2 tangent = float2(-direction.y, direction.x);
    float chromaAmount = (ring + caustic * 0.08) * chromaticAberration;
    if (chromaAmount > 0.002) {
        float2 redPosition = clamp(source + tangent * split, float2(0.0), sampleMax);
        float2 bluePosition = clamp(source - tangent * split, float2(0.0), sampleMax);
        half4 redSample = layer.sample(redPosition);
        half4 blueSample = layer.sample(bluePosition);
        float3 redStraight = float3(redSample.rgb) / max(float(redSample.a), 0.0001);
        float3 blueStraight = float3(blueSample.rgb) / max(float(blueSample.a), 0.0001);
        color.r = mix(color.r, redStraight.r, chromaAmount);
        color.b = mix(color.b, blueStraight.b, chromaAmount);
    }

    float horizonMask = 1.0 - smoothstep(horizon * 0.82, horizon * 1.38, dist);
    float absorption = horizonMask * effectAmount;
    color *= 1.0 - darkness * absorption;
    // The horizon is intentionally opaque, even where the source layer is transparent.
    outputAlpha = mix(outputAlpha, 1.0, absorption);

    float glowBand = exp(-pow((dist - horizon * 1.35) / max(radius * 0.045, 1.0), 2.0)) * effectAmount;
    float3 warmGlow = float3(1.0, 0.58, 0.20) * (glowBand * glow * 0.85);
    float3 blueHalo = float3(0.20, 0.48, 1.0) * ((ring * 0.55 + caustic * 0.24) * glow * 0.10);
    color += warmGlow + blueHalo;

    color = clamp(color, float3(0.0), float3(1.0));
    outputAlpha = clamp(outputAlpha, 0.0, 1.0);
    return half4(half3(color * outputAlpha), half(outputAlpha));
}
