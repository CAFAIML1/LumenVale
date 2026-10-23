#ifndef LV_HAND_LIGHT
#define LV_HAND_LIGHT
#include "/lib/held_material.glsl"
#ifdef HAND_LIGHT
#ifdef VOXEL_LIGHTING
// Traverse each crossed block once, including thin glass filters.
vec3 handTransmission(vec3 start,vec3 end) {
    vec3 a=start+cameraPosition-voxelOrigin();
    vec3 ray=end-start;
    ivec3 cell=ivec3(floor(a));
    ivec3 target=ivec3(floor(end+cameraPosition-voxelOrigin()));
    ivec3 stepDir=ivec3(sign(ray));
    vec3 inv=1.0/max(abs(ray),vec3(0.000001));
    vec3 next=(mix(fract(a),1.0-fract(a),greaterThan(ray,vec3(0.0))))*inv;
    next=mix(next,vec3(1e20),lessThan(abs(ray),vec3(0.000001)));
    vec3 transmission=vec3(1.0);
    for(int i=0;i<32;i++) {
        if(!voxelInside(cell)) break;
        uint occupancy=texelFetch(voxelOccupancySampler,cell,0).r;
        if((occupancy&LV_SOLID)!=0u) {
            uint shape=(occupancy&LV_PARTIAL)!=0u?texelFetch(voxelShapeSampler,cell,0).r:0u;
            if(shapeSegmentBlocked(shape,a-vec3(cell),a+ray-vec3(cell))) return vec3(0.0);
        }
#ifdef COLORED_LIGHT_TRANSMISSION
        if((occupancy&LV_FILTER)!=0u) transmission*=voxelUnpack(occupancy);
#endif
        if(all(equal(cell,target))) break;
        float crossing=min(next.x,min(next.y,next.z));
        if(next.x<=crossing+0.000001) {cell.x+=stepDir.x;next.x+=inv.x;}
        if(next.y<=crossing+0.000001) {cell.y+=stepDir.y;next.y+=inv.y;}
        if(next.z<=crossing+0.000001) {cell.z+=stepDir.z;next.z+=inv.z;}
    }
    return transmission;
}
#endif
vec3 oneHandLight(int item,int reported,float side,vec3 scenePos,vec3 normal) {
    float level=heldLevel(item,reported);
    if(level<=0.0) return vec3(0.0);
    // Separate origins also work when the player's main hand is the left hand.
    vec3 origin=(gbufferModelViewInverse*vec4(side*0.28,-0.22,-0.45,1.0)).xyz;
    vec3 offset=origin-scenePos;
    float distance=length(offset);
    float range=1.2+level*0.72;
    if(distance>=range) return vec3(0.0);
    float falloff=sq(1.0-distance/range)*pow(level/15.0,1.5);
    float diffuse=0.18+0.82*max(dot(normal,offset/max(distance,0.001)),0.0);
    float material=heldMaterial(item);
    vec3 spectrum=mappedEmitter(material)?materialEmissionColor(material):vec3(1.0,0.62,0.30);
    vec3 transmission=vec3(1.0);
#if defined(VOXEL_LIGHTING) && !defined(HAND_STAGE)
    transmission=handTransmission(scenePos+normal*0.08,origin);
#endif
    return spectrum*(2.2*falloff*diffuse)*transmission;
}
vec3 handheldLight(vec3 scenePos,vec3 normal) {
    float mainSide=isRightHanded?1.0:-1.0;
    return oneHandLight(heldItemId,heldBlockLightValue,mainSide,scenePos,normal)
          +oneHandLight(heldItemId2,heldBlockLightValue2,-mainSide,scenePos,normal);
}
#endif
#endif
