#version 440
// Clear water glass for the island: one surface, no bezel.
//
//   interior  clear; the real screen shows through untouched. Smoke only
//             over bright backdrops (lumTex) or on text-heavy views (smoke).
//   edge      a thin meniscus: ~edgeW px of refracted backdrop sampled just
//             outside the shape (the live capture contains this island, so
//             it never samples itself), with a sub-pixel ripple.
//   light     slow caustic filaments drifting across the body (a few %),
//             a bright meniscus line, and a sheen gliding along the top.
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
    float time;        // seconds, drives the drifting light
    float smoke;       // 0..1 minimum smoke (text-heavy views)
    float useLum;      // 1: backdrop brightness from lumTex
    float shadow;      // drop shadow strength
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D lumTex;

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// thin bright filaments, like sunlight through a water surface
float caustic(vec2 p, float t) {
    vec2 w = vec2(noise(p * 0.8 + vec2(t * 0.050, 0.0)),
                  noise(p * 0.8 + vec2(3.1, -t * 0.040)));
    vec2 q = p + w * 1.4;
    float n = noise(q + vec2(t * 0.035, -t * 0.025)) * 0.65
            + noise(q * 2.1 - vec2(t * 0.030, t * 0.045)) * 0.35;
    return pow(1.0 - abs(n * 2.0 - 1.0), 7.0);
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

    float bright = useLum > 0.5 ? smoothstep(0.45, 0.9, texture(lumTex, vec2(0.5)).r) : 0.0;

    // ---- body: clear, smoked only when it has to be --------------------
    float smokeA = max(0.26 * bright, smoke * 0.8);
    vec3 pc = vec3(0.0);                               // premultiplied colour
    float pa = smokeA;

    // ---- meniscus: thin refracted edge with a sub-pixel ripple ---------
    float band = 1.0 - smoothstep(0.0, edgeW, depth);
    float ripple = (noise(local * 0.06 + vec2(time * 0.18, -time * 0.13)) - 0.5) * 1.1;
    vec2 base = itemPos + center + p;
    vec2 q = base + n * (depth + pad + 2.0 + 2.5 * band + ripple);
    vec3 refr = texture(source, clamp(q / srcSize, 0.0, 1.0)).rgb;
    float bandA = band * band * 0.8;
    pc = refr * mix(1.0, 0.75, bright) * bandA + pc * (1.0 - bandA);
    pa = bandA + pa * (1.0 - bandA);

    // ---- drifting light --------------------------------------------------
    float c = caustic(local / 70.0, time) * (1.0 - band);
    float cAmt = 0.055 * (1.0 - 0.6 * max(bright, smoke));
    pc += vec3(c * cAmt);
    pa += c * cAmt * 0.5;

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
    float spec = line * (0.18 + 0.42 * key + 0.35 * sheen);
    pc += vec3(spec);
    pa += spec;

    vec4 glass = vec4(pc, clamp(pa, 0.0, 1.0)) * inside;

    // very soft shadow, just enough to lift it off bright screens
    float sd = sdRoundBox(p - vec2(0.0, 2.0), halfBox, r);
    float shadowA = shadow * (0.4 + 1.6 * bright) * exp(-max(sd, 0.0) / 5.0)
                  * (1.0 - smoothstep(pad * 0.4, pad - 1.0, sd));
    vec4 shade = vec4(0.0, 0.0, 0.0, shadowA * (1.0 - inside));

    fragColor = (glass + shade) * qt_Opacity;
}
