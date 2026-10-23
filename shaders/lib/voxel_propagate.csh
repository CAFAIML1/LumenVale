#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
layout(local_size_x=4,local_size_y=4,local_size_z=4) in;
const ivec3 workGroups=ivec3(16,16,16);
#if defined(VOXEL_LIGHTING) && (!defined(VOXEL_INDIRECT_PASS) || defined(COLORED_LIGHT_BOUNCE))
#include "/lib/voxel_common.glsl"
layout(r32ui) readonly uniform uimage3D voxelOccupancy;
layout(r32ui) readonly uniform uimage3D voxelShape;
#ifdef VOXEL_INDIRECT_PASS
#ifdef VOXEL_READ_B
layout(rgba16f) readonly uniform image3D voxelLightB;
layout(rgba16f) writeonly uniform image3D voxelIndirect;
#define LV_READ voxelLightB
#define LV_WRITE voxelIndirect
#else
layout(rgba16f) readonly uniform image3D voxelIndirect;
layout(rgba16f) writeonly uniform image3D voxelLightB;
#define LV_READ voxelIndirect
#define LV_WRITE voxelLightB
#endif
#elif defined(VOXEL_READ_A)
layout(rgba16f) readonly uniform image3D voxelLightA;
layout(rgba16f) writeonly uniform image3D voxelLightB;
#define LV_READ voxelLightA
#define LV_WRITE voxelLightB
#else
layout(rgba16f) readonly uniform image3D voxelLightB;
layout(rgba16f) writeonly uniform image3D voxelLightA;
#define LV_READ voxelLightB
#define LV_WRITE voxelLightA
#endif
void main() {
    ivec3 p=ivec3(gl_GlobalInvocationID);
    vec4 light=imageLoad(LV_READ,p);
    uint material=imageLoad(voxelOccupancy,p).r;
    if (!voxelFullCube(material)) {
        uint shape=(material&LV_PARTIAL)!=0u?imageLoad(voxelShape,p).r:0u;
        vec3 transmission=vec3(1.0);
#ifdef COLORED_LIGHT_TRANSMISSION
        if((material&LV_FILTER)!=0u) transmission=voxelUnpack(material);
#endif
        vec3 sum=vec3(0.0);
        float sumWeight=0.0,strongest=0.0,metadata=0.0;
        for(int i=0;i<6;i++) {
            ivec3 q=p+LV_AXES[i];
            if(!voxelInside(q)) continue;
            vec4 candidate=imageLoad(LV_READ,q);
#ifdef VOXEL_INDIRECT_PASS
            int face=int(candidate.a+0.5)-1;
            if(face<0 || face>5) continue;
            float cosine=dot(-vec3(LV_AXES[i]),vec3(LV_AXES[face]));
            if(cosine<0.0) continue; // Never propagate behind the reflecting face.
            candidate.rgb*=mix(0.65,1.0,max(cosine,0.0));
#else
            if(candidate.a<=1.0) continue;
            candidate.a-=1.0;
#endif
            uint neighbor=imageLoad(voxelOccupancy,q).r;
            uint neighborShape=(neighbor&LV_PARTIAL)!=0u?imageLoad(voxelShape,q).r:0u;
            uint entry=voxelOpenFace(material,shape,i);
            uint exit=voxelOpenFace(neighbor,neighborShape,i^1);
#ifndef VOXEL_INDIRECT_PASS
            // An emitting full block releases light through its actual faces.
            if(voxelFullCube(neighbor) && candidate.a>0.0) exit=65535u;
#endif
            if((entry&exit)==0u) continue;
            candidate.rgb*=0.80*transmission;
            float b=voxelBrightness(candidate.rgb);
            // Convex color mixing instead of separate channel maxima; this
            // cannot manufacture a brighter white from unrelated spectra.
            float w=b*b*b*b;
            sum+=candidate.rgb*w;
            sumWeight+=w;
            if(b>strongest) { strongest=b;metadata=candidate.a; }
        }
        vec3 spread=sum/max(sumWeight,1e-20);
        if(voxelBrightness(spread)>voxelBrightness(light.rgb)+1e-7)
            light=vec4(spread,metadata);
    }
    imageStore(LV_WRITE,p,light);
}
#else
void main() {}
#endif
