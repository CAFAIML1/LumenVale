#ifndef LV_VOXEL_COMMON
#define LV_VOXEL_COMMON
#include "/lib/material_light.glsl"
const int LV_VOXEL_SIZE = 64;
const uint LV_SOLID = 0x80000000u;
const uint LV_FILTER = 0x40000000u;
const uint LV_EMITTER = 0x10000000u;
#include "/lib/voxel_shapes.glsl"
vec3 voxelOrigin() { return floor(cameraPosition)-vec3(32.0); }
ivec3 voxelCell(vec3 worldPos) { return ivec3(floor(worldPos-voxelOrigin())); }
bool voxelInside(ivec3 p) { return all(greaterThanEqual(p,ivec3(0))) && all(lessThan(p,ivec3(64))); }
const ivec3 LV_AXES[6]=ivec3[6](ivec3(1,0,0),ivec3(-1,0,0),ivec3(0,1,0),ivec3(0,-1,0),ivec3(0,0,1),ivec3(0,0,-1));
int voxelFace(vec3 n) {
    vec3 a=abs(n);
    if(a.x>=a.y && a.x>=a.z) return n.x>=0.0?0:1;
    if(a.y>=a.z) return n.y>=0.0?2:3;
    return n.z>=0.0?4:5;
}
ivec3 voxelFaceCell(ivec3 p,int face) { return ivec3(p.xy,p.z+face*64); }
float voxelBrightness(vec3 c) { return dot(c,vec3(0.2126,0.7152,0.0722)); }
uint voxelPack(vec3 c) {
    uvec3 v=uvec3(clamp(c,0.0,1.0)*255.0+0.5);
    return v.r | (v.g<<8u) | (v.b<<16u);
}
vec3 voxelUnpack(uint v) { return vec3(v&255u,(v>>8u)&255u,(v>>16u)&255u)/255.0; }
vec3 voxelEmissionColor(float material) {
    return materialEmissionColor(material);
}
#endif
