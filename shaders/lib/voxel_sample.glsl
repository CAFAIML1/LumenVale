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
ivec3 voxelSampleCorner(int index) {return ivec3(index&1,(index>>1)&1,index>>2);}
vec3 voxelFilteredLight(vec3 p) {
    vec4 filtered=texture3D(voxelLightSampler,p/64.0);
    // Final direct A.alpha is a geometry mask, not a light level. Entirely
    // open neighborhoods need only the filtered light lookups.
    if(filtered.a<=0.0) {
        vec3 light=filtered.rgb;
#ifdef COLORED_LIGHT_BOUNCE
        light+=texture3D(voxelLightBSampler,p/64.0).rgb;
#endif
        return max(light,vec3(0.0));
    }
    ivec3 base=ivec3(floor(p-0.5));
    vec3 fraction=fract(p-0.5);
    ivec3 sourceCell=ivec3(floor(p));
    ivec3 sourceCorner=sourceCell-base;
    int sourceIndex=sourceCorner.x+sourceCorner.y*2+sourceCorner.z*4;
    uint materials[8],shapes[8];
    uint openMask=0u,solidMask=0u,partialMask=0u,emitterMask=0u;
    float openWeight=0.0;
    for(int i=0;i<8;i++) {
        ivec3 corner=voxelSampleCorner(i);
        ivec3 cell=base+corner;
        // The caller's border fade guarantees all eight cells are inside.
        uint occupancy=texelFetch(voxelOccupancySampler,cell,0).r;
        materials[i]=occupancy;
        uint bit=1u<<uint(i);
        shapes[i]=(occupancy&LV_PARTIAL)!=0u?texelFetch(voxelShapeSampler,cell,0).r:0u;
        if((occupancy&LV_SOLID)!=0u) solidMask|=bit;
        if((occupancy&LV_PARTIAL)!=0u) partialMask|=bit;
        if(voxelFullCube(occupancy)) {
            if((occupancy&LV_EMITTER)!=0u) emitterMask|=bit;
        } else {
            openMask|=bit;
            vec3 w=mix(1.0-fraction,fraction,vec3(corner));
            openWeight+=w.x*w.y*w.z;
        }
    }
    if(voxelFullCube(materials[sourceIndex])) return vec3(0.0);
    if(shapes[sourceIndex]!=0u && shapeContains(shapes[sourceIndex],p-vec3(sourceCell))) return vec3(0.0);

    // A Cartesian box of open cells is convex (air, flat walls and floors).
    // Non-convex corners need actual segment rejection, including obstacles
    // in intermediate cells rather than only at the two endpoints.
    int spanX=int((openMask&0x55u)!=0u)+int((openMask&0xaau)!=0u);
    int spanY=int((openMask&0x33u)!=0u)+int((openMask&0xccu)!=0u);
    int spanZ=int((openMask&0x0fu)!=0u)+int((openMask&0xf0u)!=0u);
    if(partialMask==0u && bitCount(openMask)==spanX*spanY*spanZ) {
        vec3 light=filtered.rgb;
#ifdef COLORED_LIGHT_BOUNCE
        light+=texture3D(voxelLightBSampler,p/64.0).rgb;
#endif
        if(emitterMask!=0u) {
            // Filter only air beside bright solid emitters. Subtracting a
            // filtered emitter value would amplify texture-weight rounding.
            light=vec3(0.0);
            uint pending=openMask;
            while(pending!=0u) {
                int index=findLSB(pending);pending&=pending-1u;
                ivec3 corner=voxelSampleCorner(index),cell=base+corner;
                vec3 w=mix(1.0-fraction,fraction,vec3(corner));
                vec3 visible=texelFetch(voxelLightSampler,cell,0).rgb;
#ifdef COLORED_LIGHT_BOUNCE
                visible+=texelFetch(voxelLightBSampler,cell,0).rgb;
#endif
                light+=visible*(w.x*w.y*w.z);
            }
        }
        return max(light,vec3(0.0))/max(openWeight,0.00001);
    }

    vec3 light=vec3(0.0);float total=0.0;
    for(int i=0;i<8;i++) {
        if((openMask&(1u<<uint(i)))==0u) continue;
        ivec3 corner=voxelSampleCorner(i),cell=base+corner;
        vec3 weight=mix(1.0-fraction,fraction,vec3(corner));
        float w=weight.x*weight.y*weight.z;
        if(w<=0.0) continue;
        vec3 anchor=vec3(cell)+clamp(p-vec3(cell),vec3(0.04),vec3(0.96));
        bool blocked=false;
        uint pending=solidMask;
        while(pending!=0u) {
            int blocker=findLSB(pending);pending&=pending-1u;
            vec3 offset=vec3(base+voxelSampleCorner(blocker));
            if(!segmentCrossesVoxel(p-offset,anchor-offset)) continue;
            if(voxelFullCube(materials[blocker]))
                blocked=true;
            else
                blocked=shapeSegmentBlocked(shapes[blocker],p-offset,anchor-offset);
            if(blocked) break;
        }
        if(blocked) continue;
        light+=texelFetch(voxelLightSampler,cell,0).rgb*w;
#ifdef COLORED_LIGHT_BOUNCE
        light+=texelFetch(voxelLightBSampler,cell,0).rgb*w;
#endif
        total+=w;
    }
    return light/max(total,0.00001);
}
vec4 voxelLightAt(vec3 scenePos,vec3 normal) {
    vec3 p=scenePos+cameraPosition+normal*0.035-voxelOrigin();
    float border=min(min(min(p.x,p.y),p.z),min(min(64.0-p.x,64.0-p.y),64.0-p.z));
    float fade=smoothstep(0.5,5.0,border);
    if(fade<=0.0) return vec4(0.0);
    return vec4(voxelFilteredLight(p)*VOXEL_STRENGTH,fade);
}
vec4 voxelFogLightAt(vec3 scenePos) {return voxelLightAt(scenePos,vec3(0.0));}
#endif
#endif
