#version 440
// Liquid-glass capsule.
//
// mode 0 (island): the source is a LIVE capture of the screen, which also
//   contains this bar. To avoid sampling itself, the refracting rim only
//   samples pixels just outside the capsule (beyond the shadow), bending
//   them inward like a convex edge. The interior is nearly clear (the real
//   screen shows through, sharp) with a faint tint that turns smoky over
//   bright backdrops so labels stay legible.
// mode 1 (lens): the source is the island itself; the droplet magnifies it.
//
// Compile: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o glass.frag.qsb glass.frag

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
    float bezel;       // px width of the curved rim that refracts
    float refraction;  // px of extra reach for the rim samples
    float magnify;     // lens mode: >1 zooms
    float blurPx;      // softening of samples
    float tint;        // interior tint strength
    float shadow;      // drop shadow strength
    float mode;        // 0 island, 1 lens
};
layout(binding = 1) uniform sampler2D source;

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec4 soft(vec2 px) {
    // 8-tap golden-angle spiral (premultiplied rgba)
    vec4 acc = vec4(0.0);
    for (int i = 0; i < 8; i++) {
        float f = float(i) + 0.5;
        float r = sqrt(f / 8.0) * blurPx;
        float a = f * 2.39996;
        acc += texture(source, clamp((px + vec2(cos(a), sin(a)) * r) / srcSize, 0.0, 1.0));
    }
    return acc / 8.0;
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
    float t = clamp(-d / bezel, 0.0, 1.0);            // 0 at rim -> 1 past bezel
    float edge = 1.0 - t;

    vec3 col;
    float alpha;

    if (mode < 0.5) {
        // ---- island: live refracted rim + translucent interior ----------
        // project to a point outside the capsule, past the shadow; the
        // outermost rim reaches farthest (compressed, lens-like edge)
        float reach = -d + pad + refraction * edge;
        vec2 base = itemPos + center + p;
        vec3 ring;
        ring.r = soft(base + n * reach * 1.05).r;     // slight chromatic fringe
        ring.g = soft(base + n * reach).g;
        ring.b = soft(base + n * reach * 0.95).b;

        // brightness of the backdrop right outside this point
        float lum = dot(ring, vec3(0.2126, 0.7152, 0.0722));
        float bright = smoothstep(0.35, 0.85, lum);

        // interior: light frost over dark backdrops, smoky over bright ones
        vec3 tintCol = mix(vec3(1.0), vec3(0.0), bright);
        float tintA = mix(tint, tint * 2.5, bright);

        // glass thickness: a thin darker line where the rim meets the flat
        float lip = exp(-pow((-d - bezel * 0.85) / 1.2, 2.0));

        float w = pow(edge, 2.2);                     // rim weight, clear middle
        col = mix(tintCol, ring, w);
        alpha = mix(tintA, 0.95, w);
        col = mix(col, vec3(0.0), lip * 0.35);
        alpha = max(alpha, lip * 0.18);
    } else {
        // ---- lens: magnify the island under the droplet -----------------
        vec2 base = itemPos + center + p / magnify;
        vec2 disp = -n * refraction * edge * edge;    // pull rim inward
        vec4 s = soft(base + disp);
        col = s.a > 0.001 ? s.rgb / s.a : vec3(1.0);
        alpha = max(s.a, tint);
        col = mix(col, vec3(1.0), tint);
    }

    // sheen from the top
    col = mix(col, vec3(1.0), 0.08 * (1.0 - qt_TexCoord0.y));

    // specular rim: bright top-left, fainter bottom-right glint
    float rim = 1.0 - smoothstep(0.0, 1.6, -d);
    float glow = 1.0 - smoothstep(0.0, bezel * 0.9, -d);
    vec2 light = normalize(vec2(-0.45, -1.0));
    float key = pow(max(dot(n, light), 0.0), 2.0);
    float back = pow(max(dot(n, -light), 0.0), 3.0);
    float spec = rim * (0.65 * key + 0.30 * back) + glow * 0.10 * key;

    // premultiplied glass + additive highlight
    vec4 glass = vec4(col * alpha + vec3(spec), clamp(alpha + spec, 0.0, 1.0)) * inside;

    // drop shadow outside; fades to zero before the padding edge
    float sd = sdRoundBox(p - vec2(0.0, 2.0), halfBox, r);
    float shadowA = shadow * exp(-max(sd, 0.0) / 4.0)
                  * (1.0 - smoothstep(-1.0, 0.5, -sd))
                  * (1.0 - smoothstep(pad * 0.4, pad - 1.0, sd));
    vec4 shade = vec4(0.0, 0.0, 0.0, shadowA * (1.0 - inside));

    fragColor = (glass + shade) * qt_Opacity;
}
