#ifndef LV_VOXEL_SAMPLE
#define LV_VOXEL_SAMPLE
#ifdef VOXEL_LIGHTING
#include "/lib/voxel_common.glsl"
uniform sampler3D voxelLightSampler;
uniform usampler3D voxelOccupancySampler;
uniform usampler3D voxelShapeSampler;
#ifdef COLORED_LIGHT_BOUNCE
uniform sampler3D voxelLightBSampler;
#endif
// Fog has many samples per pixel. Keep its filtered lookup separate from the
// eight-neighbor surface filter, while rejecting fog inside actual solids.
vec4 voxelFogLightAt(vec3 scenePos) {
    vec3 p=scenePos+cameraPosition-voxelOrigin();
    float border=min(min(min(p.x,p.y),p.z),min(min(64.0-p.x,64.0-p.y),64.0-p.z));
    float fade=smoothstep(0.5,5.0,border);
    if(fade<=0.0) return vec4(0.0);
    ivec3 cell=ivec3(floor(p));
    uint occupancy=texelFetch(voxelOccupancySampler,cell,0).r;
    if(voxelFullCube(occupancy)) return vec4(0.0);
    if((occupancy&LV_PARTIAL)!=0u && shapeContains(texelFetch(voxelShapeSampler,cell,0).r,p-vec3(cell))) return vec4(0.0);
    vec3 light=texture3D(voxelLightSampler,p/64.0).rgb;
#ifdef COLORED_LIGHT_BOUNCE
    light+=texture3D(voxelLightBSampler,p/64.0).rgb;
#endif
    return vec4(light*VOXEL_STRENGTH,fade);
}
vec4 voxelLightAt(vec3 scenePos,vec3 normal) {
    vec3 p=scenePos+cameraPosition+normal*0.035-voxelOrigin();
    float border=min(min(min(p.x,p.y),p.z),min(min(64.0-p.x,64.0-p.y),64.0-p.z));
    float fade=smoothstep(0.5,5.0,border);
    if (fade<=0.0) return vec4(0.0);
    // Normalize interpolation over air cells. Solid corners must not pull
    // light to black, and a slab's exposed face stays in its own open cell.
    ivec3 base=ivec3(floor(p-0.5));
    vec3 fraction=fract(p-0.5);
    ivec3 sourceCell=ivec3(floor(p));
    uint sourceMaterial=texelFetch(voxelOccupancySampler,sourceCell,0).r;
    uint sourceShape=(sourceMaterial&LV_PARTIAL)!=0u?texelFetch(voxelShapeSampler,sourceCell,0).r:0u;
    vec3 light=vec3(0.0);float total=0.0;
    for(int z=0;z<2;z++) for(int y=0;y<2;y++) for(int x=0;x<2;x++) {
        ivec3 cell=base+ivec3(x,y,z);
        if(!voxelInside(cell)) continue;
        uint occupancy=texelFetch(voxelOccupancySampler,cell,0).r;
        if(voxelFullCube(occupancy)) continue;
        vec3 anchor=vec3(cell)+clamp(p-vec3(cell),vec3(0.04),vec3(0.96));
        if(sourceShape!=0u && shapeSegmentBlocked(sourceShape,p-vec3(sourceCell),anchor-vec3(sourceCell))) continue;
        if((occupancy&LV_PARTIAL)!=0u && any(notEqual(cell,sourceCell))) {
            uint shape=texelFetch(voxelShapeSampler,cell,0).r;
            if(shapeSegmentBlocked(shape,p-vec3(cell),anchor-vec3(cell))) continue;
        }
        vec3 weight=mix(1.0-fraction,fraction,vec3(x,y,z));
        float w=weight.x*weight.y*weight.z;
        light+=texelFetch(voxelLightSampler,cell,0).rgb*w;
#ifdef COLORED_LIGHT_BOUNCE
        light+=texelFetch(voxelLightBSampler,cell,0).rgb*w;
#endif
        total+=w;
    }
    light/=max(total,0.00001);
    return vec4(light*VOXEL_STRENGTH,fade);
}
#endif
#endif
