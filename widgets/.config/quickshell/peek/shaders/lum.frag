#version 440
// Backdrop brightness around a glass capsule, smoothed over time.
// Rendered into a 1x1 recursive ShaderEffectSource (GlassLum.qml): each
// frame moves `k` of the way from the previous value toward the current
// measurement, so the glass tint glides instead of jumping.
// Compile: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o lum.frag.qsb lum.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 shape;        // capsule rect in source px (x, y, w, h)
    vec2 srcSize;      // source size px
    float margin;      // sample this far outside the capsule (past the shadow)
    float k;           // 0..1 per-frame blend toward the new value (1 = snap)
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D prev;

float lumAt(vec2 px) {
    return dot(texture(source, clamp(px / srcSize, 0.0, 1.0)).rgb,
               vec3(0.2126, 0.7152, 0.0722));
}

void main() {
    vec2 c = shape.xy + shape.zw * 0.5;
    vec2 h = shape.zw * 0.5 + vec2(margin);
    float acc = 0.0;
    // beside and below (above the bar is the screen's top gap)
    for (int i = 0; i < 5; i++) {
        float a = float(i) * 0.785398;                 // 0°..180°, y down
        acc += lumAt(c + vec2(cos(a), sin(a)) * h);
    }
    // along the bottom edge, for wide capsules
    for (int i = 0; i < 4; i++) {
        float fx = (float(i) + 0.5) / 4.0;
        acc += lumAt(vec2(shape.x + shape.z * fx, shape.y + shape.w + margin));
    }
    float target = acc / 9.0;
    float old = texture(prev, vec2(0.5)).r;
    float v = mix(old, target, clamp(k, 0.0, 1.0));
    fragColor = vec4(v, v, v, 1.0);
}
