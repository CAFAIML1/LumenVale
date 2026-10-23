#ifndef LV_WIND
#define LV_WIND
// IDs come from block.properties. Root vertices stay still, including shadows.
vec3 foliageOffset(vec3 p, float id, float top) {
    vec3 offset = vec3(0.0);
#ifdef WAVING_FOLIAGE
    float weight = 0.0;
    if (id > 10003.5 && id < 10004.5) weight = top;
    if (id > 10004.5 && id < 10005.5) weight = 1.0;
    if (id > 10005.5 && id < 10006.5) weight = 0.30;
    if (weight > 0.0) {
        float t = frameTimeCounter * 1.35;
        float phase = p.x*0.43 + p.z*0.31;
        float wave = sin(t+phase) + 0.35*sin(t*1.79-phase*1.31);
        float gust = 0.65 + 0.35*sin(t*0.27 + p.x*0.017 + p.z*0.023);
        offset.xz = vec2(wave, sin(t*0.91+phase+1.7)) *
                    (0.075 * WIND_STRENGTH * weight * gust * (1.0+rainStrength*0.5));
    }
#endif
    return offset;
}
#endif
