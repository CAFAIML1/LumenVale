#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/wind.glsl"
#ifdef HAND_STAGE
#include "/lib/held_material.glsl"
#endif
varying vec2 vTexCoord;
varying vec2 vLight;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vScenePos;
varying vec3 vViewPos;
varying float vMaterial;
varying float vEmission;
#ifdef TERRAIN
attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;
attribute vec4 at_midBlock;
#endif
void main() {
    vTexCoord = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    vLight = clamp(((gl_TextureMatrix[1]*gl_MultiTexCoord1).xy*256.0-8.0)/240.0,0.0,1.0);
    vColor = gl_Color;
    vec4 view = gl_ModelViewMatrix*gl_Vertex;
    vec4 scene = gbufferModelViewInverse*view;
    vMaterial = 0.0;
    vEmission = 0.0;
#ifdef HAND_STAGE
    vMaterial=heldMaterial(currentRenderedItemId);
    int level=currentRenderedItemId==heldItemId?heldBlockLightValue:heldBlockLightValue2;
    vEmission=heldLevel(currentRenderedItemId,level)/15.0;
#endif
#ifdef TERRAIN
    vMaterial = mc_Entity.x;
    vEmission = clamp(at_midBlock.w/15.0,0.0,1.0);
    float top = 1.0-step(mc_midTexCoord.y,vTexCoord.y);
    scene.xyz += foliageOffset(scene.xyz+cameraPosition,mc_Entity.x,top);
    view = gbufferModelView*scene;
#endif
    vScenePos = scene.xyz;
    vViewPos = view.xyz;
    vNormal = normalize(mat3(gbufferModelViewInverse)*(gl_NormalMatrix*gl_Normal));
    gl_Position = gl_ProjectionMatrix*view;
}
