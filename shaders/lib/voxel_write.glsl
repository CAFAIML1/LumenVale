#ifdef VOXEL_LIGHTING
#include "/lib/voxel_common.glsl"
layout(r32ui) uniform uimage3D voxelOccupancy;
layout(r32ui) uniform uimage3D voxelEmit;
layout(r32ui) uniform uimage3D voxelShape;
#ifdef COLORED_LIGHT_BOUNCE
layout(r32ui) uniform uimage3D voxelSurface;
#endif
attribute vec4 at_midBlock;
uniform sampler2D texture;
void voxelizeBlock(vec3 scenePos,vec2 uv) {
    // Only terrain has render type -1 / +1; entities have no block-center data.
    if (abs(mc_Entity.y)<0.5) return;
    float m=mc_Entity.x;
    if (m>10000.5 && m<10002.5) return; // Water and thin transparent materials.
    vec3 center=scenePos+cameraPosition+at_midBlock.xyz/64.0;
    ivec3 cell=voxelCell(center);
    if (!voxelInside(cell)) return;
    if(lightFilterMaterial(m)) {
#ifdef COLORED_LIGHT_TRANSMISSION
        imageAtomicMax(voxelOccupancy,cell,LV_FILTER|voxelPack(materialTransmission(m)));
#endif
        return;
    }
    // Face centers avoid pulling a neighboring atlas sprite into the bounce.
    vec2 sampleUV=mc_midTexCoord;
    if(sampleUV.x<=0.0 || sampleUV.y<=0.0) sampleUV=uv;
    vec3 albedo=pow(clamp(texture2DLod(texture,sampleUV,0.0).rgb*gl_Color.rgb,0.0,1.0),vec3(2.2));
    int level=clamp(int(at_midBlock.w+0.5),0,15);
    if(level>0) {
        vec3 spectrum=voxelEmissionColor(m);
        if(!mappedEmitter(m)) spectrum=mix(vec3(1.0),albedo/max(max(albedo.r,albedo.g),max(albedo.b,0.001)),0.70);
        vec3 emission=spectrum*pow(float(level)/15.0,1.5);
        imageAtomicMax(voxelEmit,cell,(uint(level)<<24u)|voxelPack(emission));
    }
    bool cutout=m>10003.5 && m<10006.5;
    if(cutout || thinEmitter(m)) return;
    uint shape=voxelShapeId(m);
    if(shape!=0u) imageAtomicMax(voxelShape,cell,shape);
    imageAtomicMax(voxelOccupancy,cell,LV_SOLID|(shape!=0u?LV_PARTIAL:0u)|(level>0?LV_EMITTER:0u)|voxelPack(albedo));
#ifdef COLORED_LIGHT_BOUNCE
    vec3 normal=normalize(mat3(shadowModelViewInverse)*(gl_NormalMatrix*gl_Normal));
    // Six independent faces prevent a colored top from tinting every side.
    imageAtomicMax(voxelSurface,voxelFaceCell(cell,voxelFace(normal)),LV_SOLID|voxelPack(albedo));
#endif
}
#endif
