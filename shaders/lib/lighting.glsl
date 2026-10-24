#ifndef LV_LIGHTING
#define LV_LIGHTING
#include "/lib/shadow.glsl"
#include "/lib/sky.glsl"
#include "/lib/voxel_sample.glsl"
#include "/lib/material_light.glsl"
#include "/lib/hand_light.glsl"
vec3 surfaceLight(vec3 albedo,vec3 normal,vec3 scenePos,vec3 viewPos,vec2 lm,float ao,float material,out float shadowVis) {
    shadowVis = 1.0;
    float block = pow(saturate(lm.x),3.0);
    float sky = sq(saturate(lm.y));
    vec3 blockColor = vec3(1.75,0.88,0.35)*block;
#ifdef VOXEL_LIGHTING
    vec4 voxel=voxelLightAt(scenePos,normal);
    // Do not let vanilla fill bypass occlusion inside the voxel volume.
    // The border fade restores vanilla lighting outside the local field.
    blockColor=mix(blockColor,voxel.rgb,voxel.a);
#endif
#ifdef HAND_LIGHT
    blockColor+=handheldLight(scenePos,normal);
#endif
    vec3 illumination;
#ifdef DIM_NETHER
    illumination = vec3(0.17,0.07,0.038)+toLinear(fogColor)*0.22+blockColor;
#elif defined(DIM_END)
    illumination = vec3(0.20,0.15,0.29)*(0.65+normal.y*0.25)+blockColor;
#else
    float day = daylight();
    vec3 lightDir = worldDirection(shadowLightPosition);
    float nl = max(dot(normal,lightDir),0.0);
    float leaf = step(10003.5,material)*step(material,10006.5);
    float diffuse = mix(nl,abs(dot(normal,lightDir))*0.65+0.25,leaf);
    float visibility = 1.0;
#ifndef NO_SHADOW_RECEIVE
    if (diffuse > 0.01 && lm.y > 0.05)
        visibility = shadowVisibility(scenePos,normal,nl);
#endif
    shadowVis = visibility;
    vec3 direct = mix(vec3(0.25,0.37,0.62)*NIGHT_BRIGHTNESS,sunRadiance(),day);
    vec3 transmitted=shadowTransmission(scenePos+normal*0.04);
    direct *= diffuse*visibility*smoothstep(0.0,0.85,lm.y)*(1.0-rainStrength*0.80);
    direct *= transmitted;
    float hemisphere = 0.65+normal.y*0.22;
    float goldenHour = exp(-abs(sunDirection().y)*9.0)*(1.0-rainStrength);
    vec3 ambientDay = mix(vec3(0.26,0.36,0.49),vec3(0.34,0.29,0.28),goldenHour*0.65);
    vec3 ambient = mix(vec3(0.10,0.16,0.30)*NIGHT_BRIGHTNESS,
                       ambientDay,day)*sky*hemisphere;
    float scatter = pow(saturate(dot(-normalize(viewPos),normalize(shadowLightPosition))),5.0);
    direct += sunRadiance()*scatter*leaf*0.20*visibility*sky*day*(1.0-rainStrength)*transmitted;
    illumination = direct+ambient+blockColor+vec3(0.018,0.022,0.029);
#endif
    illumination = max(illumination,vec3(nightVision*0.75));
    illumination *= 1.0-darknessLightFactor*0.85;
    vec3 color = albedo*illumination*mix(0.38,1.0,ao);
    return color;
}
vec3 applyFog(vec3 color,vec3 scenePos,vec3 viewPos) {
    float distanceToEye = length(viewPos);
    vec3 ray = worldDirection(viewPos);
    vec3 fog = atmosphere(ray);
    float amount;
    if (isEyeInWater == 1) {
        fog = mix(vec3(0.018,0.10,0.13),toLinear(fogColor),0.38);
        amount = 1.0-exp(-distanceToEye*0.075*FOG_DENSITY);
    } else if (isEyeInWater == 2) {
        fog = vec3(1.1,0.16,0.015);
        amount = 1.0-exp(-distanceToEye*1.5);
    } else if (isEyeInWater == 3) {
        fog = toLinear(fogColor);
        amount = 1.0-exp(-distanceToEye*0.35);
    } else {
#ifdef DIM_NETHER
        fog = max(toLinear(fogColor),vec3(0.04,0.008,0.003));
        amount = 1.0-exp(-distanceToEye*0.009*FOG_DENSITY);
#elif defined(DIM_END)
        amount = 1.0-exp(-distanceToEye*0.0025*FOG_DENSITY);
#else
        float lowMist = exp(-max(cameraPosition.y+scenePos.y-62.0,0.0)*0.022);
        float density = (0.00065+rainStrength*0.003+lowMist*0.00055)*FOG_DENSITY;
        float exposure = saturate(float(eyeBrightnessSmooth.y)/240.0);
        amount = (1.0-exp(-distanceToEye*density))*mix(0.12,1.0,exposure);
#endif
        float endDistance = max(min(far,fogEnd),16.0);
        float edge = smoothstep(endDistance*0.68,endDistance*0.99,length(scenePos.xz));
        amount = max(amount,edge);
    }
    color = mix(color,fog,saturate(amount));
    float impairment = max(blindness,darknessFactor*0.85);
    color *= 1.0-smoothstep(1.0,24.0,distanceToEye)*impairment;
    return color;
}
#endif
