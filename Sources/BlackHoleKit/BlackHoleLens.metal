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
    float radius,
    float strength,
    float spin,
    float darkness,
    float glow,
    float time
) {
    half4 original = layer.sample(position);

    radius = max(radius, 1.0);
    strength = clamp(strength, 0.0, 1.5);
    darkness = clamp(darkness, 0.0, 1.0);
    glow = clamp(glow, 0.0, 2.0);
    float effectAmount = smoothstep(0.0, 0.02, strength);

    float2 delta = position - center;
    float dist = length(delta);

    if (dist >= radius) {
        return original;
    }

    float dist01 = clamp(dist / radius, 0.0, 1.0);
    float horizon = radius * 0.18;

    float edgeMask = 1.0 - smoothstep(radius * 0.82, radius, dist);
    float2 direction = delta / max(dist, 1.0);

    float gravity = pow(1.0 - dist01, 2.35);
    float pull = strength * radius * 0.44 * gravity / max(dist01, 0.16);
    pull = min(pull, radius * (0.72 + strength * 0.16));

    float swirl = spin * effectAmount * edgeMask * gravity * 7.0
        + time * 0.22 * edgeMask * (1.0 - smoothstep(0.55, 1.0, dist01));

    float2 spun = rotate2D(delta, swirl);
    float2 source = center + spun + direction * pull;

    float maxOffset = radius * (1.0 + strength * 0.65);
    float2 offset = source - position;
    float offsetLength = length(offset);
    if (offsetLength > maxOffset) {
        offset *= maxOffset / offsetLength;
        source = position + offset;
    }

    half4 warped = layer.sample(source);
    half3 color = mix(original.rgb, warped.rgb, half(edgeMask * effectAmount));

    float photonSphere = radius * 0.31;
    float ringWidth = max(radius * 0.035, 1.0);
    float ring = exp(-pow((dist - photonSphere) / ringWidth, 2.0)) * effectAmount;

    float split = ring * glow * 3.0;
    float2 tangent = float2(-direction.y, direction.x);
    half4 redSample = layer.sample(source + tangent * split);
    half4 blueSample = layer.sample(source - tangent * split);
    color.r = mix(color.r, redSample.r, half(ring * 0.35 * glow));
    color.b = mix(color.b, blueSample.b, half(ring * 0.25 * glow));

    float absorption = (1.0 - smoothstep(horizon * 0.72, horizon * 1.45, dist)) * effectAmount;
    color *= half(1.0 - darkness * absorption);

    float glowBand = exp(-pow((dist - horizon * 1.35) / max(radius * 0.045, 1.0), 2.0)) * effectAmount;
    half3 warmGlow = half3(1.0, 0.58, 0.20) * half(glowBand * glow * 0.85);
    half3 blueHalo = half3(0.20, 0.48, 1.0) * half(ring * glow * 0.22);
    color += warmGlow + blueHalo;

    color = clamp(color, half3(0.0), half3(1.0));
    return half4(color, original.a);
}
