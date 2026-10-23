#ifndef LV_SHADOW
#define LV_SHADOW
#ifdef SHADOWS
uniform sampler2D shadowtex0;
#elif defined(VOXEL_LIGHTING)
uniform sampler2D shadowtex0;
#endif
#if defined(VOXEL_LIGHTING) && defined(COLORED_LIGHT_TRANSMISSION)
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
#endif
vec3 distortShadow(vec3 p) {
    p.xy /= 0.18 + length(p.xy)*0.82;
    p.z *= 0.5;
    return p;
}
float opaqueShadowDepth(vec2 uv) {
#if defined(SHADOWS) || defined(VOXEL_LIGHTING)
#if defined(VOXEL_LIGHTING) && defined(COLORED_LIGHT_TRANSMISSION)
    return texture2D(shadowtex1,uv).r;
#else
    return texture2D(shadowtex0,uv).r;
#endif
#else
    return 1.0;
#endif
}
vec3 shadowTransmission(vec3 scenePos) {
#if defined(SHADOWS) && defined(VOXEL_LIGHTING) && !defined(DIM_NETHER) && !defined(DIM_END)
#ifdef COLORED_LIGHT_TRANSMISSION
    vec4 p=shadowProjection*shadowModelView*vec4(scenePos,1.0);
    vec3 sc=distortShadow(p.xyz/p.w)*0.5+0.5;
    if(any(lessThan(sc,vec3(0.002))) || any(greaterThan(sc,vec3(0.998)))) return vec3(1.0);
    float z=sc.z-0.00035;
    if(texture2D(shadowtex0,sc.xy).r<z && texture2D(shadowtex1,sc.xy).r>=z)
        return clamp(texture2D(shadowcolor0,sc.xy).rgb,vec3(0.0),vec3(1.0));
#endif
#endif
    return vec3(1.0);
}
float shadowSingle(vec3 scenePos, float bias) {
#if defined(SHADOWS) && !defined(DIM_NETHER) && !defined(DIM_END)
    vec4 p=shadowProjection*shadowModelView*vec4(scenePos,1.0);
    vec3 sc=distortShadow(p.xyz/p.w)*0.5+0.5;
    if (any(lessThan(sc,vec3(0.002))) || any(greaterThan(sc,vec3(0.998)))) return 1.0;
    return step(sc.z-bias,opaqueShadowDepth(sc.xy));
#else
    return 1.0;
#endif
}
float shadowVisibility(vec3 scenePos, vec3 normal, float ndotl) {
#if defined(SHADOWS) && !defined(DIM_NETHER) && !defined(DIM_END)
    float distanceFade = smoothstep(shadowDistance*0.72, shadowDistance, length(scenePos.xz));
    if (distanceFade >= 0.999) return 1.0;
    float offset = (0.025 + (1.0-ndotl)*0.07) * (2048.0/float(shadowMapResolution));
    vec4 p = shadowProjection * shadowModelView * vec4(scenePos+normal*offset,1.0);
    vec3 sc = distortShadow(p.xyz/p.w)*0.5+0.5;
    if (min(sc.x, sc.y) < 0.003 || max(sc.x, sc.y) > 0.997 || sc.z <= 0.0 || sc.z >= 1.0) return 1.0;
    sc.z -= 0.00018 + (1.0-ndotl)*0.00022;
    float result = 0.0;
    float r = SHADOW_SOFTNESS / float(shadowMapResolution);
#ifdef SHADOW_PCSS
    float blockers=0.0, blockerDepth=0.0;
    for (int i=0;i<8;i++) {
        float a=float(i)*2.39996323;
        vec2 disk=vec2(cos(a),sin(a))*sqrt((float(i)+0.5)/8.0);
        float d=opaqueShadowDepth(sc.xy+disk*7.0/float(shadowMapResolution));
        if(d<sc.z) { blockerDepth+=d; blockers+=1.0; }
    }
    if(blockers<0.5) return 1.0;
    // A wider filter only where the receiver separates from its blockers.
    float separation=max(sc.z-blockerDepth/blockers,0.0);
    r*=clamp(1.0+separation*900.0,1.0,7.0);
#endif
#if SHADOW_SAMPLES == 1
    result = step(sc.z,opaqueShadowDepth(sc.xy));
#elif SHADOW_SAMPLES == 16
    for(int i=0;i<16;i++) {
        float a=float(i)*2.39996323;
        vec2 disk=vec2(cos(a),sin(a))*sqrt((float(i)+0.5)/16.0);
        result+=step(sc.z,opaqueShadowDepth(sc.xy+disk*r*1.7));
    }
    result/=16.0;
#else
    result += step(sc.z,opaqueShadowDepth(sc.xy+vec2(-0.6,-0.6)*r));
    result += step(sc.z,opaqueShadowDepth(sc.xy+vec2( 0.6,-0.6)*r));
    result += step(sc.z,opaqueShadowDepth(sc.xy+vec2(-0.6, 0.6)*r));
    result += step(sc.z,opaqueShadowDepth(sc.xy+vec2( 0.6, 0.6)*r));
#if SHADOW_SAMPLES == 8
    result += step(sc.z,opaqueShadowDepth(sc.xy+vec2(-1.5, 0.0)*r));
    result += step(sc.z,opaqueShadowDepth(sc.xy+vec2( 1.5, 0.0)*r));
    result += step(sc.z,opaqueShadowDepth(sc.xy+vec2( 0.0,-1.5)*r));
    result += step(sc.z,opaqueShadowDepth(sc.xy+vec2( 0.0, 1.5)*r));
#endif
    result /= float(SHADOW_SAMPLES);
#endif
    return mix(result,1.0,distanceFade);
#else
    return 1.0;
#endif
}
#endif
