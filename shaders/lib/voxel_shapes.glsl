#ifndef LV_VOXEL_SHAPES
#define LV_VOXEL_SHAPES
#include "/lib/shape_data.glsl"
const uint LV_PARTIAL=0x20000000u;
uniform sampler2D lvShapeTable;
uvec2 shapeRange(uint shape) {return uvec2(texelFetch(lvShapeTable,ivec2(0,int(shape)-1),0).rg+0.5);}
vec3 shapeBoxMin(uint box) {return texelFetch(lvShapeTable,ivec2(0,LV_SHAPE_COUNT+int(box)),0).rgb;}
vec3 shapeBoxMax(uint box) {return texelFetch(lvShapeTable,ivec2(1,LV_SHAPE_COUNT+int(box)),0).rgb;}
bool voxelFullCube(uint material) { return (material&(LV_SOLID|LV_PARTIAL))==LV_SOLID; }
uint voxelShapeId(float material) {
    int shape=int(material+0.5)-20000;
    return shape>0 && shape<=LV_SHAPE_COUNT?uint(shape):0u;
}
uint shapeFaceOpen(uint shape,int face) {
    vec4 data=texelFetch(lvShapeTable,ivec2(face<2?0:1,int(shape)-1),0);
    return uint(data[face<2?face+2:face-2]+0.5);
}
uint voxelOpenFace(uint material,uint shape,int face) {
    if((material&LV_SOLID)==0u) return 65535u;
    if((material&LV_PARTIAL)==0u || shape==0u) return 0u;
    return shapeFaceOpen(shape,face);
}
bool shapeContains(uint shape,vec3 point) {
    if(shape==0u) return true;
    uvec2 range=shapeRange(shape);
    for(uint i=range.x;i<range.x+range.y;i++)
        if(all(greaterThan(point,shapeBoxMin(i)+0.00001)) && all(lessThan(point,shapeBoxMax(i)-0.00001))) return true;
    return false;
}
bool shapeSegmentBlocked(uint shape,vec3 start,vec3 end) {
    if(shape==0u) return true;
    vec3 ray=end-start;
    vec3 inverse=sign(ray)/max(abs(ray),vec3(0.0000001));
    uvec2 range=shapeRange(shape);
    for(uint i=range.x;i<range.x+range.y;i++) {
        vec3 lo=shapeBoxMin(i)+0.00001,hi=shapeBoxMax(i)-0.00001;
        if((abs(ray.x)<0.0000001 && (start.x<lo.x || start.x>hi.x))
        || (abs(ray.y)<0.0000001 && (start.y<lo.y || start.y>hi.y))
        || (abs(ray.z)<0.0000001 && (start.z<lo.z || start.z>hi.z))) continue;
        vec3 a=(lo-start)*inverse,b=(hi-start)*inverse;
        vec3 entry=mix(min(a,b),vec3(-1e20),lessThan(abs(ray),vec3(0.0000001)));
        vec3 exit=mix(max(a,b),vec3(1e20),lessThan(abs(ray),vec3(0.0000001)));
        float first=max(max(entry.x,entry.y),max(entry.z,0.00001));
        float last=min(min(exit.x,exit.y),min(exit.z,0.99999));
        if(first<last) return true;
    }
    return false;
}
#endif
