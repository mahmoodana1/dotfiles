#version 440
// Clear water glass for the island: one surface, no bezel.
//
//   interior  clear; the real screen shows through untouched. Smoke only
//             over bright backdrops (lumTex) or on text-heavy views (smoke).
//   edge      a thin meniscus: ~edgeW px of refracted backdrop sampled just
//             outside the shape (the live capture contains this island, so
//             it never samples itself). Smooth: no ripple or waves.
//   light     a bright meniscus line and a sheen gliding along the top.
//
// Compile: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o water.frag.qsb water.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;     // px, includes shadow padding
    vec2 itemPos;      // px, item top-left in the source
    vec2 srcSize;      // px, source size
    float pad;         // px of shadow padding around the shape
    float radius;      // px corner radius
    float edgeW;       // px width of the refracting meniscus
    float time;        // seconds, drives the sheen along the top
    float smoke;       // 0..1 minimum smoke (text-heavy views)
    float useLum;      // 1: backdrop brightness from lumTex
    float shadow;      // drop shadow strength
    vec4 tint;         // sea tint: rgb (palette accent) + strength in a
    float darkLift;    // 0..1 faint fill + brighter rim over dark backdrops
    vec4 tint2;        // rgb: tint colour toward the bottom-right; a: depth shading 0..1 (1 = water)
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D lumTex;

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 local = qt_TexCoord0 * itemSize;
    vec2 center = itemSize * 0.5;
    vec2 p = local - center;
    vec2 halfBox = center - vec2(pad);
    float r = min(radius, min(halfBox.x, halfBox.y));
    float d = sdRoundBox(p, halfBox, r);

    float e = 0.75;
    vec2 n = normalize(vec2(
        sdRoundBox(p + vec2(e, 0.0), halfBox, r) - sdRoundBox(p - vec2(e, 0.0), halfBox, r),
        sdRoundBox(p + vec2(0.0, e), halfBox, r) - sdRoundBox(p - vec2(0.0, e), halfBox, r)) + 1e-5);

    float inside = clamp(0.5 - d, 0.0, 1.0);          // AA coverage
    float depth = max(-d, 0.0);                        // px in from the edge

    float lum = useLum > 0.5 ? texture(lumTex, vec2(0.5)).r : 0.5;
    float bright = useLum > 0.5 ? smoothstep(0.45, 0.9, lum) : 0.0;
    float dark = useLum > 0.5 ? (1.0 - smoothstep(0.04, 0.3, lum)) * darkLift : 0.0;

    // ---- body: clear, smoked only when it has to be --------------------
    // Smoke behind the content rises with backdrop brightness (starting from
    // mid-bright), so white text stays readable over bright or colourful screens.
    float backing = useLum > 0.5 ? smoothstep(0.22, 0.8, lum) : 0.0;
    float smokeA = max(0.6 * backing, smoke * 0.8);
    vec3 pc = vec3(0.0);                               // premultiplied colour
    float pa = smokeA;

    // ---- sea tint: like looking through seawater, deeper toward the bottom
    float tA = tint.a * mix(1.0, 0.72, qt_TexCoord0.y * tint2.a);
    vec3 tcol = mix(tint.rgb, tint2.rgb, clamp(qt_TexCoord0.x * 0.45 + qt_TexCoord0.y * 0.55, 0.0, 1.0));
    vec3 tc = tcol * mix(1.0, mix(1.05, 0.55, qt_TexCoord0.y), tint2.a);
    pc = pc * (1.0 - tA) + tc * tA;
    pa = pa + tA * (1.0 - pa);

    // over a dark backdrop, a faint milky fill so the glass doesn't vanish
    float lift = 0.07 * dark;
    pc += vec3(lift);
    pa += lift * 0.6;

    // ---- meniscus: thin refracted edge ----------------------------------
    float band = 1.0 - smoothstep(0.0, edgeW, depth);
    vec2 base = itemPos + center + p;
    vec2 q = base + n * (depth + pad + 2.0 + 2.5 * band);
    vec3 refr = texture(source, clamp(q / srcSize, 0.0, 1.0)).rgb;
    float bandA = band * band * 0.8;
    pc = refr * mix(1.0, 0.75, bright) * bandA + pc * (1.0 - bandA);
    pa = bandA + pa * (1.0 - bandA);

    // faint surface glow from above, like light on the water's skin
    float skin = 0.035 * pow(1.0 - qt_TexCoord0.y, 3.0);
    pc += vec3(skin);
    pa += skin * 0.5;

    // meniscus line: brightest facing the light, with a sheen gliding along the top
    vec2 light = normalize(vec2(-0.35, -1.0));
    float key = pow(max(dot(n, light), 0.0), 1.5);
    float line = exp(-pow((depth - 0.7) / 0.9, 2.0));
    float along = fract(time * 0.025);                 // one pass every 40 s
    float sheen = exp(-pow((qt_TexCoord0.x - (along * 1.6 - 0.3)) * 5.0, 2.0))
                * max(-n.y, 0.0);
    float spec = line * (0.18 + 0.42 * key + 0.35 * sheen) * (1.0 + 0.9 * dark);
    pc += vec3(spec);
    pa += spec;

    vec4 glass = vec4(pc, clamp(pa, 0.0, 1.0)) * inside;

    // very soft shadow, just enough to lift it off bright screens
    float sd = sdRoundBox(p - vec2(0.0, 2.0), halfBox, r);
    float shadowA = shadow * (0.4 + 1.6 * bright) * exp(-max(sd, 0.0) / (pad * 0.45))
                  * (1.0 - smoothstep(pad * 0.4, pad - 1.0, sd));
    vec4 shade = vec4(0.0, 0.0, 0.0, shadowA * (1.0 - inside));

    fragColor = (glass + shade) * qt_Opacity;
}
