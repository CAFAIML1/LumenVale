#include "/lib/settings.glsl"
#include "/lib/material_light.glsl"
uniform sampler2D texture;
varying vec2 vTexCoord;
varying float vShadowMaterial;
/* DRAWBUFFERS:0 */
const bool shadowcolor0Clear = true;
// Iris 1.7.6's directive parser requires all four scalar components.
const vec4 shadowcolor0ClearColor = vec4(1.0, 1.0, 1.0, 1.0);
void main() {
    if (vShadowMaterial>10000.5 && vShadowMaterial<10002.5) discard;
    if(lightFilterMaterial(vShadowMaterial)) {
#if defined(VOXEL_LIGHTING) && defined(COLORED_LIGHT_TRANSMISSION)
        gl_FragData[0]=vec4(materialTransmission(vShadowMaterial),1.0);
        return;
#else
        discard;
#endif
    }
    if (texture2D(texture,vTexCoord).a < 0.1) discard;
    gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);
}
