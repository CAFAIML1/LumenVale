#ifdef CINEMATIC_SURFACES
uniform sampler2D colortex1;
ivec2 surfacePixel(vec2 uv) {
    return clamp(ivec2(uv*vec2(textureSize(depthtex0,0))),ivec2(0),textureSize(depthtex0,0)-1);
}
vec2 reflectionUV(vec3 p) {
    vec4 c=gbufferProjection*vec4(p,1.0);
    return c.xy/c.w*0.5+0.5;
}
float reflectionDelta(vec3 p) {
    vec2 uv=reflectionUV(p);
    float depth=texelFetch(depthtex0,surfacePixel(uv),0).r;
    return depth>=0.999999?-10000.0:viewPosition(uv,depth).z-p.z;
}
// Bilinear color filtering must not blend a hit with the other side of an edge.
vec3 reflectionColor(vec2 uv,vec3 hit,vec3 hitNormal) {
    vec2 size=vec2(textureSize(depthtex0,0));
    vec2 grid=uv*size-0.5;
    ivec2 base=ivec2(floor(grid));
    vec2 f=fract(grid);
    vec3 sum=vec3(0.0);float weight=0.0;
    for(int y=0;y<2;y++) for(int x=0;x<2;x++) {
        ivec2 pixel=clamp(base+ivec2(x,y),ivec2(0),ivec2(size)-1);
        vec2 sampleUV=(vec2(pixel)+0.5)/size;
        vec4 surface=texelFetch(colortex1,pixel,0);
        vec3 normal=normalize(mat3(gbufferModelView)*(surface.rgb*2.0-1.0));
        vec3 point=viewPosition(sampleUV,texelFetch(depthtex0,pixel,0).r);
        float w=(x==0?1.0-f.x:f.x)*(y==0?1.0-f.y:f.y);
        w*=surface.a>=0.0?1.0:0.0;
        w*=smoothstep(0.85,0.98,dot(normal,hitNormal));
        w*=1.0-smoothstep(0.04,0.12+length(hit)*0.003,abs(point.z-hit.z));
        sum+=texelFetch(colortex0,pixel,0).rgb*w;weight+=w;
    }
    return weight>0.0001?sum/weight:texelFetch(colortex0,surfacePixel(uv),0).rgb;
}
vec3 reflectSurface(vec3 color,vec3 view,vec3 worldNormal,float skyLight,float polish) {
    vec3 n=normalize(mat3(gbufferModelView)*worldNormal);
    if(dot(n,-view)<0.0) n=-n;
    vec3 direction=reflect(normalize(view),n);
    float wet=wetness*smoothstep(0.72,0.96,skyLight)*smoothstep(0.1,0.85,worldNormal.y);
    float coverage=max(wet,polish*0.6);
    if(coverage<0.015 || length(view)>80.0) return color;
    float skyVisibility=sq(smoothstep(0.05,0.85,skyLight));
    vec3 fallback=mix(color*0.25,atmosphere(worldDirection(direction)),skyVisibility);
    vec3 reflection=fallback;
    vec3 origin=view+n*0.035;
    float previous=0.0;
    float previousDelta=reflectionDelta(origin);
    for(int i=1;i<=SURFACE_SSR_STEPS;i++) {
        float t=float(i)/float(SURFACE_SSR_STEPS);
        float distance=0.08+48.0*t*t;
        vec3 point=origin+direction*distance;
        if(point.z>=-near) break;
        vec2 uv=reflectionUV(point);
        if(any(lessThan(uv,vec2(0.002))) || any(greaterThan(uv,vec2(0.998)))) break;
        float delta=reflectionDelta(point);
        // Require a front-to-back crossing, rather than accepting nearby depth.
        if(previousDelta<=0.0 && delta>0.0) {
            float lo=previous,hi=distance;
            for(int j=0;j<7;j++) {
                float mid=(lo+hi)*0.5;
                if(reflectionDelta(origin+direction*mid)>0.0) hi=mid;else lo=mid;
            }
            float da=reflectionDelta(origin+direction*lo);
            float db=reflectionDelta(origin+direction*hi);
            float hitT=mix(lo,hi,saturate(-da/max(db-da,0.000001)));
            vec3 rayHit=origin+direction*hitT;
            uv=reflectionUV(rayHit);
            ivec2 pixel=surfacePixel(uv);
            float depth=texelFetch(depthtex0,pixel,0).r;
            vec4 surface=texelFetch(colortex1,pixel,0);
            vec3 hitPoint=viewPosition(uv,depth);
            vec3 hitNormal=normalize(mat3(gbufferModelView)*(surface.rgb*2.0-1.0));
            float tolerance=0.035+length(hitPoint)*0.002;
            float gap=length(hitPoint-rayHit);
            float planeDistance=dot(hitPoint-view,n);
            float incidence=dot(hitNormal,-direction);
            // Reject coplanar self-hits, compressed hand depth and discontinuities.
            if(depth<0.999999 && surface.a>=0.0 && planeDistance>0.055 && gap<tolerance && incidence>0.025) {
                float edge=smoothstep(0.0,0.08,min(min(uv.x,uv.y),min(1.0-uv.x,1.0-uv.y)));
                float confidence=(1.0-smoothstep(tolerance*0.5,tolerance,gap))*smoothstep(0.025,0.20,incidence);
                reflection=mix(fallback,reflectionColor(uv,hitPoint,hitNormal),edge*(1.0-t*t)*confidence);
                break;
            }
        }
        previous=distance;previousDelta=delta;
    }
    float facing=clamp(dot(n,normalize(-view)),0.0,1.0);
    float fresnel=0.035+0.965*pow(1.0-facing,5.0);
    float amount=coverage*clamp(fresnel,0.04,0.72);
    return mix(color*(1.0-wet*0.16),reflection,amount);
}
#endif
