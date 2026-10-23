#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/math.glsl"
#include "/lib/shadow.glsl"
layout(local_size_x=4,local_size_y=4,local_size_z=4) in;
const ivec3 workGroups=ivec3(16,16,16);
#if defined(VOXEL_LIGHTING) && defined(COLORED_LIGHT_BOUNCE)
#include "/lib/voxel_common.glsl"
layout(r32ui) readonly uniform uimage3D voxelOccupancy;
layout(r32ui) readonly uniform uimage3D voxelShape;
layout(r32ui) readonly uniform uimage3D voxelEmit;
layout(r32ui) readonly uniform uimage3D voxelSurface;
layout(rgba16f) readonly uniform image3D voxelLightA;
layout(rgba16f) writeonly uniform image3D voxelLightB;
void main() {
    ivec3 p=ivec3(gl_GlobalInvocationID);
    uint material=imageLoad(voxelOccupancy,p).r;
    vec3 reflected=vec3(0.0);
    float outwardFace=0.0;
    if(!voxelFullCube(material)) {
        vec3 incident=imageLoad(voxelLightA,p).rgb;
        vec3 gradient=vec3(0.0);
        float intensity=voxelBrightness(incident);
        // Estimate the incident direction from the direct radiance gradient.
        // A blocked neighbor uses the center value instead of a false black
        // sample, which would otherwise point every light away from a wall.
        for(int i=0;i<6;i++) {
            ivec3 q=p+LV_AXES[i];
            float sampleIntensity=intensity;
            if(voxelInside(q)) {
                uint occupied=imageLoad(voxelOccupancy,q).r;
                if(!voxelFullCube(occupied) || imageLoad(voxelEmit,q).r!=0u)
                    sampleIntensity=voxelBrightness(imageLoad(voxelLightA,q).rgb);
            }
            gradient+=vec3(LV_AXES[i])*sampleIntensity;
        }
        float directionality=clamp(length(gradient)/max(intensity*0.55,0.0001),0.0,1.0);
        vec3 towardLight=gradient/max(length(gradient),0.0001);
        float strongest=0.0,weights=0.0;
        for(int i=0;i<6;i++) {
            ivec3 q=p+LV_AXES[i];
            if(!voxelInside(q)) continue;
            uint solid=imageLoad(voxelOccupancy,q).r;
            if((solid&LV_SOLID)==0u || imageLoad(voxelEmit,q).r!=0u) continue;
            vec3 normal=-vec3(LV_AXES[i]);
            int face=i^1;
            uint shape=(solid&LV_PARTIAL)!=0u?imageLoad(voxelShape,q).r:0u;
            float faceCoverage=1.0-float(bitCount(voxelOpenFace(solid,shape,face)))/16.0;
            if(faceCoverage<=0.0) continue;
            uint capturedFace=imageLoad(voxelSurface,voxelFaceCell(q,face)).r;
            vec3 albedo=voxelUnpack((capturedFace&LV_SOLID)!=0u?capturedFace:solid);
            // No material may return more than 90% of incident radiance.
            albedo=min(albedo,vec3(0.90));
            float cosine=mix(0.45,max(dot(normal,towardLight),0.0),directionality);
            vec3 contribution=incident*albedo*cosine*0.35;
            float weight=cosine;
#if !defined(DIM_NETHER) && !defined(DIM_END)
            float nl=max(dot(normal,worldDirection(shadowLightPosition)),0.0);
            if(nl>0.01) {
                vec3 surface=voxelOrigin()+vec3(q)+0.5+normal*0.51-cameraPosition;
                vec3 sunlight=sunRadiance()*daylight()*(1.0-rainStrength*0.8)*shadowSingle(surface,0.0003)*shadowTransmission(surface);
                contribution+=albedo*sunlight*nl*0.18;
                weight=max(weight,nl);
            }
#endif
            contribution*=faceCoverage;
            reflected+=contribution;
            weights+=weight*faceCoverage;
            float brightness=voxelBrightness(contribution);
            if(brightness>strongest) { strongest=brightness;outwardFace=float(face+1); }
        }
        // Bound corner accumulation; seed only on the exposed side.
        reflected*=LIGHT_BOUNCE_STRENGTH/max(weights,1.0);
#ifdef COLORED_LIGHT_TRANSMISSION
        if((material&LV_FILTER)!=0u) reflected*=voxelUnpack(material);
#endif
    }
    imageStore(voxelLightB,p,vec4(reflected,outwardFace));
}
#else
void main() {}
#endif
