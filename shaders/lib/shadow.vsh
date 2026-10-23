#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/wind.glsl"
#include "/lib/shadow.glsl"
attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;
#include "/lib/voxel_write.glsl"
varying vec2 vTexCoord;
varying float vShadowMaterial;
void main() {
    vTexCoord = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    vec4 scene = shadowModelViewInverse*gl_ModelViewMatrix*gl_Vertex;
    vShadowMaterial=mc_Entity.x;
#ifdef VOXEL_LIGHTING
    voxelizeBlock(scene.xyz,vTexCoord);
#endif
    float top = 1.0-step(mc_midTexCoord.y,vTexCoord.y);
    scene.xyz += foliageOffset(scene.xyz+cameraPosition,mc_Entity.x,top);
    vec4 clip = gl_ProjectionMatrix*shadowModelView*scene;
    clip.xyz = distortShadow(clip.xyz/clip.w)*clip.w;
    gl_Position = clip;
}
