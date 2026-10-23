#ifndef LV_MATH
#define LV_MATH
const float PI = 3.14159265359;
float saturate(float x) { return clamp(x, 0.0, 1.0); }
float sq(float x) { return x * x; }
float pow5(float x) { float x2 = x*x; return x2*x2*x; }
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 toLinear(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
float valueNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash12(i), hash12(i+vec2(1.0,0.0)), f.x),
               mix(hash12(i+vec2(0.0,1.0)), hash12(i+vec2(1.0)), f.x), f.y);
}
vec3 viewPosition(vec2 uv, float depth) {
    vec4 p = gbufferProjectionInverse * vec4(uv*2.0-1.0, depth*2.0-1.0, 1.0);
    return p.xyz / p.w;
}
vec3 worldDirection(vec3 v) { return normalize(mat3(gbufferModelViewInverse) * v); }
vec3 sunDirection() { return worldDirection(sunPosition); }
float daylight() { return smoothstep(-0.10, 0.15, sunDirection().y); }
vec3 sunRadiance() {
    float elevation = saturate(sunDirection().y * 3.0);
    return mix(vec3(1.7,0.57,0.19), vec3(1.38,1.22,1.02), elevation);
}
#endif
