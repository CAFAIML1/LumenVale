#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/math.glsl"
#include "/lib/voxel_common.glsl"
#include "/lib/shadow.glsl"
layout(local_size_x=4,local_size_y=4,local_size_z=4) in;
const ivec3 workGroups=ivec3(16,16,16);
#ifdef VOXEL_LIGHTING
layout(r32ui) readonly uniform uimage3D voxelOccupancy;
layout(r32ui) readonly uniform uimage3D voxelEmit;
layout(rgba16f) writeonly uniform image3D voxelLightA;
layout(rgba16f) writeonly uniform image3D voxelLightB;
void main() {
    ivec3 p=ivec3(gl_GlobalInvocationID);
    uint emitter=imageLoad(voxelEmit,p).r;
    vec3 light=voxelUnpack(emitter)*4.0;
    imageStore(voxelLightA,p,vec4(light,float((emitter>>24u)&15u)));
    imageStore(voxelLightB,p,vec4(0.0));
}
#else
void main() {}
#endif
