#ifndef LV_WATER
#define LV_WATER
// Filled before translucency: these are snapshots, not active render targets.
uniform sampler2D colortex4;
uniform sampler2D depthtex1;

vec3 safeUnit(vec3 v) { return v*inversesqrt(max(dot(v,v),0.000001)); }
vec2 waterProject(vec3 p) {
    vec4 clip = gbufferProjection*vec4(p,1.0);
    return clip.xy/max(clip.w,0.0001)*0.5+0.5;
}
vec2 waveSlope(vec2 p,float footprint) {
#if WATER_DETAIL == 0
    return vec2(0.0);
#else
    float t = frameTimeCounter;
    vec2 slope = vec2(0.0);
    slope += vec2(0.94,0.34)*cos(dot(p,vec2(0.94,0.34))*0.43+t*0.82)*0.049;
    slope += vec2(-0.44,0.90)*cos(dot(p,vec2(-0.44,0.90))*0.77-t*1.08)*0.037;
#if WATER_DETAIL >= 2
    float fine = 1.0-smoothstep(0.12,0.65,footprint);
    slope += vec2(0.68,-0.73)*cos(dot(p,vec2(0.68,-0.73))*1.93+t*1.73)*0.021*fine;
    slope += vec2(0.23,0.97)*cos(dot(p,vec2(0.23,0.97))*3.71-t*2.11)*0.012*fine;
#if WATER_DETAIL == 3
    slope += vec2(-0.81,0.59)*cos(dot(p,vec2(-0.81,0.59))*6.13+t*2.47)*0.009*fine;
    slope += vec2(0.95,-0.31)*cos(dot(p,vec2(0.95,-0.31))*8.27-t*3.07)*0.006*fine;
#endif
#ifdef WATER_RAIN_RIPPLES
    if (rainStrength>0.01) {
        vec2 cell = floor(p*1.35);
        float seed = hash12(cell);
        vec2 centre = vec2(seed,hash12(cell+31.7))*0.4+0.3;
        vec2 q = fract(p*1.35)-centre;
        float radius = length(q);
        float age = fract(t*0.9+seed*7.0);
        float ring = exp(-sq((radius-age*0.55)*20.0));
        float fade = sin(age*PI)*(1.0-smoothstep(0.35,0.5,max(abs(q.x),abs(q.y))));
        slope += q/max(radius,0.02)*ring*cos(radius*50.0-age*25.0)*fade*rainStrength*0.11*fine;
    }
#endif
#endif
    return slope*WATER_WAVES;
#endif
}

// Check a complete bilinear footprint against the actual water plane. A
// view-Z check alone accepts land beside the water and creates ghost banks.
float waterBackgroundClearance(vec2 uv,vec3 surface,vec3 planeNormal) {
    float depth = texture2D(depthtex1,uv).r;
    if (depth>=0.999999) return 64.0;
    vec3 p = viewPosition(uv,depth);
    if (p.z>=surface.z-0.015) return 0.0;
    return max(-dot(p-surface,planeNormal),0.0);
}
float waterFootprintClearance(vec2 uv,vec3 surface,vec3 planeNormal) {
    vec2 px = 1.5/vec2(viewWidth,viewHeight);
    float c = waterBackgroundClearance(uv,surface,planeNormal);
    c = min(c,waterBackgroundClearance(uv+vec2(px.x,px.y),surface,planeNormal));
    c = min(c,waterBackgroundClearance(uv+vec2(-px.x,px.y),surface,planeNormal));
    c = min(c,waterBackgroundClearance(uv+vec2(px.x,-px.y),surface,planeNormal));
    return min(c,waterBackgroundClearance(uv-px,surface,planeNormal));
}

// Conservative screen-space ray traversal, with binary refinement at crossings.
// Missing/off-screen geometry fades to sky; transparent objects aren't traced.
vec4 waterScreenReflection(vec3 surface,vec3 normal,vec3 scenePos,vec3 planeNormal,vec3 ray) {
#if WATER_SSR_STEPS > 0
    vec3 origin = surface+normal*0.10;
    float previousT = 0.12;
    float previousDelta = -1.0;
    for (int i=0; i<WATER_SSR_STEPS; i++) {
        float fraction = (float(i)+1.0)/float(WATER_SSR_STEPS);
        float travel = 0.12+fraction*fraction*WATER_SSR_DISTANCE;
        vec3 point = origin+ray*travel;
        if (point.z>=-0.10) break;
        vec2 uv = waterProject(point);
        if (min(uv.x,uv.y)<=0.002 || max(uv.x,uv.y)>=0.998) break;
        float depth = texture2D(depthtex1,uv).r;
        float sceneZ = viewPosition(uv,depth).z;
        float delta = sceneZ-point.z;
        if (depth<0.999999 && delta>0.0 && previousDelta<=0.0) {
            float a = previousT, b = travel;
            float da = previousDelta, db = delta;
            for (int j=0; j<6; j++) {
                float mid = (a+b)*0.5;
                vec3 probe = origin+ray*mid;
                vec2 q = waterProject(probe);
                float d = texture2D(depthtex1,q).r;
                float dz = viewPosition(q,d).z-probe.z;
                if (dz>0.0) { b=mid; db=dz; } else { a=mid; da=dz; }
            }
            // Interpolate the final bracket to avoid visible contour bands on
            // flat submerged floors with a small ray-step budget.
            float hitT = mix(a,b,saturate(-da/max(db-da,0.00001)));
            point = origin+ray*hitT;
            uv = waterProject(point);
            depth = texture2D(depthtex1,uv).r;
            vec3 hit = viewPosition(uv,depth);
            vec3 hitScene = (gbufferModelViewInverse*vec4(hit,1.0)).xyz;
            float gap = abs(hit.z-point.z);
            float tolerance = 0.16+hitT*0.018;
            if (depth<0.999999 && gap<tolerance &&
                dot(hitScene-scenePos,planeNormal)>-0.04) {
                float border = min(min(uv.x,uv.y),min(1.0-uv.x,1.0-uv.y));
                float confidence = smoothstep(0.015,0.10,border);
                confidence *= 1.0-smoothstep(WATER_SSR_DISTANCE*0.70,WATER_SSR_DISTANCE,hitT);
                confidence *= 1.0-smoothstep(tolerance*0.35,tolerance,gap);
                return vec4(texture2D(colortex4,uv).rgb,confidence);
            }
            // Reject discontinuities instead of painting stretched silhouettes.
            return vec4(0.0);
        }
        previousT=travel;
        previousDelta=delta;
    }
#endif
    return vec4(0.0);
}

vec3 shadeWater(vec3 scenePos,vec3 viewPos,vec3 geometricNormal,vec2 lm,vec3 biomeTint) {
    vec2 screenUV = gl_FragCoord.xy/vec2(viewWidth,viewHeight);
    vec3 worldPos = scenePos+cameraPosition;
    vec3 gn = safeUnit(geometricNormal);
    vec3 V = safeUnit(mat3(gbufferModelViewInverse)*(-viewPos));
    vec3 tangent = abs(gn.y)>0.8 ? vec3(1.0,0.0,0.0) : safeUnit(cross(vec3(0.0,1.0,0.0),gn));
    vec3 bitangent = safeUnit(cross(tangent,gn));
    vec2 waveUV = vec2(dot(worldPos,tangent),dot(worldPos,bitangent));
    float footprint = max(length(dFdx(waveUV)),length(dFdy(waveUV)));
    vec2 slope = waveSlope(waveUV,footprint);
    vec3 normal = safeUnit(gn-tangent*slope.x-bitangent*slope.y);
    if (dot(gn,V)<0.0) { gn=-gn; normal=-normal; }
    normal=safeUnit(mix(gn,normal,smoothstep(0.0,0.08,dot(normal,V))));
    vec3 viewNormal = safeUnit(mat3(gbufferModelView)*normal);
    vec3 viewPlaneNormal = safeUnit(mat3(gbufferModelView)*gn);
    vec3 incident = safeUnit(viewPos);
    float eta = isEyeInWater==1 ? 1.333 : 0.75019;
    vec3 refractedRay = refract(incident,viewNormal,eta);
    float totalInternal = 1.0-step(0.00001,dot(refractedRay,refractedRay));
    // Dielectric Fresnel stays continuous at the underwater critical angle.
    // Schlick plus a binary total-reflection switch creates striped surfaces.
    float cosI = saturate(dot(normal,V));
    float cosT = sqrt(max(1.0-eta*eta*(1.0-cosI*cosI),0.0));
    float rs = (eta*cosI-cosT)/max(eta*cosI+cosT,0.0001);
    float rp = (cosI-eta*cosT)/max(cosI+eta*cosT,0.0001);
    float fresnel = saturate((rs*rs+rp*rp)*0.5);

    float opaqueDepth = texture2D(depthtex1,screenUV).r;
    vec3 behind = viewPosition(screenUV,opaqueDepth);
    float thickness = opaqueDepth>=0.999999 ? 48.0 : clamp(length(behind-viewPos),0.0,64.0);
    // Positive thickness requires opaque geometry behind the surface. Thin
    // plants and coincident faces must not turn into thick blue patches.
    if (opaqueDepth<0.999999 && behind.z>=viewPos.z-0.015) thickness=0.0;
    vec2 refractedUV = screenUV;
    if (WATER_REFRACTION>0.0 && totalInternal<0.5 && thickness>0.01) {
        // Wave-only distortion avoids large flat-surface screen shifts. The
        // latter cannot represent occluded shore geometry in this renderer.
        vec3 flatRay = refract(incident,viewPlaneNormal,eta);
        float reach = min(thickness,8.0);
        vec2 offset = (waterProject(viewPos+refractedRay*reach)-
                       waterProject(viewPos+flatRay*reach))*WATER_REFRACTION;
        vec2 limit = 8.0/vec2(viewWidth,viewHeight);
        offset = clamp(offset,-limit,limit);
        float border = min(min(screenUV.x,screenUV.y),min(1.0-screenUV.x,1.0-screenUV.y));
        offset *= smoothstep(0.005,0.065,border);
        float clearance = waterFootprintClearance(screenUV,viewPos,viewPlaneNormal);
        offset *= smoothstep(0.03,0.45,clearance);
        vec2 candidate = clamp(screenUV+offset,vec2(0.002),vec2(0.998));
        float candidateClearance = waterFootprintClearance(candidate,viewPos,viewPlaneNormal);
        float middleClearance = waterBackgroundClearance((screenUV+candidate)*0.5,viewPos,viewPlaneNormal);
        candidate = mix(screenUV,candidate,smoothstep(0.03,0.35,min(candidateClearance,middleClearance)));
        float d = texture2D(depthtex1,candidate).r;
        // Keep foreground banks from leaking into the water refraction.
        if (viewPosition(candidate,d).z<viewPos.z-0.01 || d>=0.999999) {
            refractedUV=candidate;
            opaqueDepth=d;
            behind=viewPosition(candidate,d);
            thickness=d>=0.999999 ? 48.0 : clamp(length(behind-viewPos),0.0,64.0);
        }
    }
    vec3 background = texture2D(colortex4,refractedUV).rgb;
    vec3 bottomScene = (gbufferModelViewInverse*vec4(behind,1.0)).xyz;
    float verticalDepth = max(scenePos.y-bottomScene.y,0.0);
    float visibility;
    vec3 scatter = surfaceLight(vec3(0.018,0.12,0.16)*mix(vec3(1.0),biomeTint,0.18),
                               normal,scenePos,viewPos,lm,1.0,0.0,visibility);
    if (isEyeInWater!=1) {
        // Beer-Lambert absorption: reds disappear first, shallow water stays clear.
        vec3 absorption = vec3(0.24,0.065,0.035)*WATER_DENSITY;
        absorption *= mix(vec3(1.0),vec3(1.15)-biomeTint*0.25,0.3);
        vec3 transmission = exp(-absorption*thickness);
        if (WATER_CAUSTICS>0.0) {
        vec2 causticUV = bottomScene.xz+cameraPosition.xz;
        float t = frameTimeCounter;
        float c = abs(sin(causticUV.x*2.1+causticUV.y*0.6+t*0.85)+
                      sin(causticUV.y*2.4-causticUV.x*0.4-t*0.67));
        float caustic = pow(saturate(1.0-c),7.0)*WATER_CAUSTICS;
        caustic *= exp(-verticalDepth*0.13)*sq(lm.y)*visibility*daylight()*(1.0-rainStrength);
        background *= 1.0+caustic;
        }
        background = background*transmission+scatter*(vec3(1.0)-transmission);
    } else if (opaqueDepth>=0.999999 && totalInternal<0.5) {
        float skyMask;
        background=skyWithClouds(worldDirection(refractedRay),skyMask);
    }

    vec3 reflectionRay = reflect(incident,viewNormal);
    vec4 reflected = waterScreenReflection(viewPos,viewNormal,scenePos,gn,reflectionRay);
    // Waves can aim a reflection below the geometric surface at grazing
    // angles. Those rays must not pick up the riverbed as reflected land.
    reflected.a*=smoothstep(-0.01,0.06,dot(worldDirection(reflectionRay),gn));
    reflected.a*=smoothstep(0.02,0.30,thickness);
    // Depth reconstruction becomes unstable near the submerged horizon. Fade
    // those poorly constrained hits into the underwater scattering fallback.
    if (isEyeInWater==1) reflected.a*=smoothstep(0.24,0.50,abs(dot(gn,V)));
    vec3 reflection;
    if (reflected.a>0.995) reflection=reflected.rgb;
    else {
        vec3 fallback;
        if (isEyeInWater==1) fallback=scatter;
        else {
            vec3 skyRay = worldDirection(reflectionRay);
#ifdef WATER_CLOUD_REFLECTION
            float cloudMask;
            fallback=skyWithClouds(skyRay,cloudMask);
#else
            fallback=atmosphere(skyRay);
#endif
            fallback*=sq(lm.y);
        }
        reflection=mix(fallback,reflected.rgb,reflected.a);
    }
    vec3 L = worldDirection(shadowLightPosition);
    vec3 H = safeUnit(V+L);
    float roughness = 0.035+rainStrength*0.035;
    float a2 = sq(roughness);
    float nh = saturate(dot(normal,H));
    float denominator = sq(nh*nh*(a2-1.0)+1.0);
    float distribution = a2/max(PI*denominator,0.000001);
    float sunGlint = min(distribution*0.004,4.0)*saturate(dot(normal,L));
    vec3 lightColor = mix(vec3(0.18,0.26,0.45)*NIGHT_BRIGHTNESS,sunRadiance(),daylight());
#if defined(DIM_NETHER) || defined(DIM_END)
    sunGlint=0.0;
#endif
    vec3 color = mix(background,reflection,fresnel);
    color += lightColor*sunGlint*visibility*shadowTransmission(scenePos+normal*0.04)*sq(lm.y)*(1.0-rainStrength*0.75);
    float shore = (1.0-smoothstep(0.015,0.36,verticalDepth))*(1.0-smoothstep(0.12,1.2,thickness));
    float foamPattern = smoothstep(0.36,0.75,valueNoise(worldPos.xz*3.0+frameTimeCounter*0.12));
    float foam = shore*foamPattern*WATER_FOAM*step(0.8,gn.y);
    if (isEyeInWater==1) foam=0.0;
    vec3 foamColor = mix(vec3(0.06,0.09,0.14)*NIGHT_BRIGHTNESS,vec3(0.62,0.72,0.75),daylight());
    return mix(color,foamColor,foam);
}
#endif
