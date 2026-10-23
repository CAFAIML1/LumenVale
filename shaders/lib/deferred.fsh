#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/math.glsl"
#include "/lib/sky.glsl"
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
varying vec2 vTexCoord;
#include "/lib/ao.glsl"
#include "/lib/surface_reflections.glsl"
/* Loader-only buffer directive; RGBA16F is not a GLSL symbol.
const int colortex0Format = RGBA16F;
const int colortex4Format = RGBA16F;
const int colortex1Format = RGBA16F;
*/
const bool colortex0Clear = true;
const bool colortex4Clear = false;
const bool colortex1Clear = true;
const vec4 colortex1ClearColor = vec4(0.5,1.0,0.5,0.0);
const vec4 colortex0ClearColor = vec4(0.0,0.0,0.0,1.0);
/* DRAWBUFFERS:04 */
void main() {
    float depth = texture2D(depthtex0,vTexCoord).r;
    vec3 view = viewPosition(vTexCoord,depth);
    // Derivatives are evaluated before divergent sky/geometry branches.
    vec3 normal = cross(dFdx(view),dFdy(view));
    normal /= max(length(normal),0.00001);
    if (dot(normal,-view)<0.0) normal = -normal;
    vec3 color;
    if (depth >= 0.999999) {
        vec3 ray = worldDirection(view);
        color = celestialSky(ray);
        if (isEyeInWater==1) color = mix(vec3(0.018,0.1,0.13),toLinear(fogColor),0.38);
        if (isEyeInWater==2) color = vec3(1.1,0.16,0.015);
        if (isEyeInWater==3) color = toLinear(fogColor);
        color *= 1.0-max(blindness,darknessFactor*0.85);
    } else {
        color = texture2D(colortex0,vTexCoord).rgb;
#ifdef CINEMATIC_SURFACES
        vec4 surface=texelFetch(colortex1,surfacePixel(vTexCoord),0);
        if(surface.a>=0.0) {
        color *= ambientOcclusion(vTexCoord,view,normal);
        vec3 worldNormal=normalize(surface.xyz*2.0-1.0);
        float polish=step(0.5,surface.a);
        float skyLight=(surface.a-polish*0.5)/0.49;
        color=reflectSurface(color,view,worldNormal,skyLight,polish);
        }
#else
        color *= ambientOcclusion(vTexCoord,view,normal);
#endif
    }
    gl_FragData[0] = vec4(max(color,vec3(0.0)),1.0);
    // Immutable opaque scene for water. Never read the attached color target.
    gl_FragData[1] = vec4(max(color,vec3(0.0)),1.0);
}
