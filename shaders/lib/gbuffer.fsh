#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/math.glsl"
#include "/lib/lighting.glsl"
#ifdef TRANSLUCENT
#include "/lib/water.glsl"
#endif
uniform sampler2D texture;
uniform vec4 entityColor;
varying vec2 vTexCoord;
varying vec2 vLight;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vScenePos;
varying vec3 vViewPos;
varying float vMaterial;
varying float vEmission;
#ifdef CINEMATIC_SURFACES
/* DRAWBUFFERS:01 */
#else
/* DRAWBUFFERS:0 */
#endif
void main() {
#ifdef CINEMATIC_SURFACES
    float polished=step(10029.5,vMaterial)*step(vMaterial,10030.5);
    gl_FragData[1]=vec4(vNormal/max(length(vNormal),0.0001)*0.5+0.5,clamp(vLight.y,0.0,1.0)*0.49+polished*0.5);
#ifdef HAND_STAGE
    // Hand projection compresses depth; it is not world geometry for SSR/AO.
    gl_FragData[1].a=-1.0;
#endif
#endif
#ifdef BASIC
    gl_FragData[0] = vec4(toLinear(vColor.rgb),vColor.a);
#else
    vec4 texel = texture2D(texture,vTexCoord);
    float alpha = texel.a;
#ifndef TERRAIN
    alpha *= vColor.a;
#endif
#if defined(TERRAIN) && !defined(TRANSLUCENT)
    if (alpha < 0.10) discard;
#else
    if (alpha < 0.004) discard;
#endif
    vec3 base = texel.rgb*vColor.rgb;
#ifdef ENTITY
    base = mix(base,entityColor.rgb,entityColor.a);
#endif
#ifdef DAMAGE
    gl_FragData[0] = vec4(base,alpha);
#else
    base = toLinear(base);
    float ao = 1.0;
#if defined(TERRAIN) && !defined(TRANSLUCENT)
    ao = vColor.a;
#endif
    vec3 normal = normalize(vNormal);
    float leaf = step(10003.5,vMaterial)*step(vMaterial,10006.5);
    if (!gl_FrontFacing && leaf > 0.5) normal = -normal;
#ifdef EMISSIVE
    vec3 color = base*2.0;
#elif defined(WEATHER)
    vec3 color = base*mix(0.18,0.75,daylight());
    alpha *= 0.6;
#elif defined(GLINT)
    vec3 color = base*0.8;
#else
    float surfaceShadow;
    vec3 color = vec3(0.0);
#ifdef TRANSLUCENT
    if (vMaterial < 10000.5 || vMaterial > 10001.5)
#endif
        color = surfaceLight(base,normal,vScenePos,vViewPos,vLight,ao,vMaterial,surfaceShadow);
    if(mappedEmitter(vMaterial) && vEmission>0.0) {
        float detail=smoothstep(0.04,0.65,max(base.r,max(base.g,base.b)));
        color+=mix(base,materialEmissionColor(vMaterial)*detail,0.30)*pow(vEmission,1.5)*2.5;
    }
#endif
#ifdef TRANSLUCENT
    if (vMaterial > 10000.5 && vMaterial < 10001.5) {
        color = shadeWater(vScenePos,vViewPos,normal,vLight,vColor.rgb);
        // Transmission is already integrated with the opaque snapshot.
        alpha = 1.0;
    }
#endif
#ifndef GLINT
    color = applyFog(color,vScenePos,vViewPos);
#endif
    gl_FragData[0] = vec4(max(color,vec3(0.0)),alpha);
#endif
#endif
}
