#version 440
// Liquid-glass capsule. Samples a snapshot of the screen behind the bar and
// bends it like a convex lens: content near the rim is pulled in from outside
// (with slight chromatic fringing), the middle is gently magnified, then a
// light frost, specular rim and drop shadow are added.
// Compile: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o glass.frag.qsb glass.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;     // px, includes shadow padding
    vec2 itemPos;      // px, item top-left in the snapshot
    vec2 srcSize;      // px, snapshot size
    float pad;         // px of shadow padding around the shape
    float radius;      // px corner radius
    float bezel;       // px width of the curved rim that refracts
    float refraction;  // px max displacement at the rim
    float magnify;     // >1 zooms the middle
    float blurPx;      // frost radius
    float tint;        // white sheen amount
    float shadow;      // drop shadow strength
};
layout(binding = 1) uniform sampler2D source;

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 frosted(vec2 px) {
    // 12-tap golden-angle spiral
    vec3 acc = vec3(0.0);
    for (int i = 0; i < 12; i++) {
        float f = float(i) + 0.5;
        float r = sqrt(f / 12.0) * blurPx;
        float a = f * 2.39996;
        vec2 o = vec2(cos(a), sin(a)) * r;
        acc += texture(source, clamp((px + o) / srcSize, 0.0, 1.0)).rgb;
    }
    return acc / 12.0;
}

void main() {
    vec2 local = qt_TexCoord0 * itemSize;             // px inside item
    vec2 center = itemSize * 0.5;
    vec2 p = local - center;
    vec2 halfBox = center - vec2(pad);
    float r = min(radius, min(halfBox.x, halfBox.y));
    float d = sdRoundBox(p, halfBox, r);

    // outward normal from the SDF gradient
    float e = 0.75;
    vec2 n = normalize(vec2(
        sdRoundBox(p + vec2(e, 0.0), halfBox, r) - sdRoundBox(p - vec2(e, 0.0), halfBox, r),
        sdRoundBox(p + vec2(0.0, e), halfBox, r) - sdRoundBox(p - vec2(0.0, e), halfBox, r)) + 1e-5);

    // ---- outside: soft drop shadow only ---------------------------------
    float sd = sdRoundBox(p - vec2(0.0, 2.0), halfBox, r);
    // falls to exactly zero before the padding edge, so no box outline shows
    float shadowA = shadow * exp(-max(sd, 0.0) / 4.0)
                  * (1.0 - smoothstep(-1.0, 0.5, -sd))
                  * (1.0 - smoothstep(pad * 0.4, pad - 1.0, sd));
    float inside = clamp(0.5 - d, 0.0, 1.0);          // AA coverage

    // ---- inside: lens ----------------------------------------------------
    float t = clamp(-d / bezel, 0.0, 1.0);            // 0 at rim -> 1 past bezel
    float edge = 1.0 - t;
    float bend = refraction * edge * edge;            // strongest right at the rim
    vec2 base = itemPos + center + p / magnify;       // magnified middle
    vec2 disp = n * bend;

    vec3 col;
    col.r = frosted(base + disp * 1.06).r;            // tiny chromatic fringe
    col.g = frosted(base + disp).g;
    col.b = frosted(base + disp * 0.94).b;

    // adaptive tone (like iOS): bright backdrops get darker glass so the
    // white labels stay legible
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col *= mix(1.0, 0.60, smoothstep(0.35, 0.85, lum));

    // sheen: brighter at the top like light on curved glass
    float vert = qt_TexCoord0.y;
    col = mix(col, vec3(1.0), tint * (1.15 - 0.5 * vert));
    // gentle lift so dark wallpapers still read as glass
    col = col * 0.92 + 0.06;

    // specular rim: bright top-left, fainter bottom-right glint
    float rim = 1.0 - smoothstep(0.0, 1.6, -d);
    float glow = 1.0 - smoothstep(0.0, bezel * 0.9, -d);
    vec2 light = normalize(vec2(-0.45, -1.0));
    float key = pow(max(dot(n, light), 0.0), 2.0);
    float back = pow(max(dot(n, -light), 0.0), 3.0);
    col += vec3(1.0) * (rim * (0.55 * key + 0.25 * back) + glow * 0.10 * key);

    float a = inside;
    vec4 glass = vec4(col * a, a);
    vec4 shade = vec4(0.0, 0.0, 0.0, shadowA * (1.0 - a));
    fragColor = (glass + shade) * qt_Opacity;
}
