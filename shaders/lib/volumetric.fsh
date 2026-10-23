#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/math.glsl"
#include "/lib/sky.glsl"
#include "/lib/shadow.glsl"
#include "/lib/voxel_sample.glsl"
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
varying vec2 vTexCoord;
/* DRAWBUFFERS:0 */
void main() {
    vec3 color=texture2D(colortex0,vTexCoord).rgb;
#ifdef VOLUMETRIC_LIGHT
    if(isEyeInWater==0) {
        float depth=texture2D(depthtex0,vTexCoord).r;
        vec3 view=viewPosition(vTexCoord,depth);
        vec3 ray=worldDirection(view);
        float distance=min(length(view),112.0);
        float stepSize=distance/float(VOLUMETRIC_STEPS);
        float density=(0.0018+rainStrength*0.004)*VOLUMETRIC_DENSITY;
        float transmittance=1.0;
        vec3 scatter=vec3(0.0);
        float mu=dot(ray,sunDirection());
        float phase=0.10+0.075/pow(max(1.0+0.65*0.65-1.3*mu,0.08),1.5);
        float jitter=hash12(gl_FragCoord.xy);
        for(int i=0;i<VOLUMETRIC_STEPS;i++) {
            vec3 p=ray*(float(i)+jitter)*stepSize;
            float altitude=exp(-max(cameraPosition.y+p.y-64.0,0.0)*0.025);
            float extinction=density*altitude;
            float segment=1.0-exp(-extinction*stepSize);
#ifdef DIM_NETHER
            vec3 light=max(toLinear(fogColor)*0.3,vec3(0.035,0.006,0.002));
#elif defined(DIM_END)
            vec3 light=vec3(0.04,0.015,0.07);
#else
            vec3 light=vec3(0.025,0.045,0.07);
#endif
#if !defined(DIM_NETHER) && !defined(DIM_END)
            light+=sunRadiance()*daylight()*phase*shadowSingle(p,0.00025)*shadowTransmission(p)*(1.0-rainStrength*0.65);
#endif
#ifdef VOXEL_LIGHTING
            vec4 localLight=voxelFogLightAt(p);
            light+=localLight.rgb*localLight.a*0.32;
#endif
            scatter+=transmittance*segment*light;
            transmittance*=1.0-segment;
        }
        scatter*=1.0-max(blindness,darknessFactor*0.85);
        color=color*transmittance+scatter;
    }
#endif
    gl_FragData[0]=vec4(max(color,vec3(0.0)),1.0);
}
