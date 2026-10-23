#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/math.glsl"
uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
varying vec2 vTexCoord;
float edgeLuma(vec3 c) { float l=luminance(c); return l/(1.0+l); }
vec3 sampleScene(vec2 uv) { return texture2D(colortex0,clamp(uv,vec2(0.0),vec2(1.0))).rgb; }
vec3 antialias(vec2 uv) {
    vec3 center = sampleScene(uv);
#ifdef FXAA
    vec2 px = 1.0/vec2(viewWidth,viewHeight);
    float nw = edgeLuma(sampleScene(uv+vec2(-1.0,-1.0)*px));
    float ne = edgeLuma(sampleScene(uv+vec2( 1.0,-1.0)*px));
    float sw = edgeLuma(sampleScene(uv+vec2(-1.0, 1.0)*px));
    float se = edgeLuma(sampleScene(uv+vec2( 1.0, 1.0)*px));
    float mid = edgeLuma(center);
    float lo = min(mid,min(min(nw,ne),min(sw,se)));
    float hi = max(mid,max(max(nw,ne),max(sw,se)));
    if (hi-lo < max(0.035,hi*0.13)) return center;
    vec2 dir = vec2(-((nw+ne)-(sw+se)),(nw+sw)-(ne+se));
    float reduce = max((nw+ne+sw+se)*0.03125,0.0078125);
    float rcp = 1.0/(min(abs(dir.x),abs(dir.y))+reduce);
    dir = clamp(dir*rcp,vec2(-6.0),vec2(6.0))*px;
    vec3 a = 0.5*(sampleScene(uv-dir/6.0)+sampleScene(uv+dir/6.0));
    vec3 b = a*0.5+0.25*(sampleScene(uv-dir*0.5)+sampleScene(uv+dir*0.5));
    float lb = edgeLuma(b);
    return (lb<lo || lb>hi) ? a : b;
#else
    return center;
#endif
}
vec3 toneMap(vec3 x) {
    // Compact filmic rational curve, with a gentle shoulder for highlights.
    x = max(x*EXPOSURE,vec3(0.0));
    x = (x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14);
    return clamp(x,0.0,1.0);
}
void main() {
    vec3 color = antialias(vTexCoord);
#ifdef DEPTH_OF_FIELD
    float depth=texture2D(depthtex0,vTexCoord).r;
    float distance=length(viewPosition(vTexCoord,depth));
    float focus=max(-viewPosition(vec2(0.5),centerDepthSmooth).z,0.5);
    float coc=clamp(abs(distance-focus)/max(distance,0.5)*DOF_STRENGTH*7.0,0.0,8.0);
    if(coc>0.35 && isEyeInWater==0) {
        vec3 blur=color;
        float total=1.0;
        for(int i=0;i<16;i++) {
            float a=float(i)*2.39996323;
            vec2 offset=vec2(cos(a),sin(a))*sqrt((float(i)+0.5)/16.0)*coc/vec2(viewWidth,viewHeight);
            vec2 uv=clamp(vTexCoord+offset,vec2(0.001),vec2(0.999));
            float tapDistance=length(viewPosition(uv,texture2D(depthtex0,uv).r));
            float weight=1.0-smoothstep(0.05,0.25,abs(tapDistance-distance)/max(distance,1.0));
            blur+=sampleScene(uv)*weight;
            total+=weight;
        }
        color=mix(color,blur/total,smoothstep(0.35,1.5,coc));
    }
#endif
#ifdef BLOOM
    color += texture2D(colortex3,vTexCoord).rgb*BLOOM_STRENGTH;
#endif
    color = toneMap(color);
#ifdef CINEMATIC_GRADE
    float l=luminance(color);
    color*=mix(vec3(0.94,0.99,1.06),vec3(1.045,1.015,0.965),smoothstep(0.15,0.8,l));
    color=mix(color,smoothstep(vec3(0.0),vec3(1.0),color),0.14);
#endif
    color = mix(vec3(luminance(color)),color,SATURATION);
    vec2 p = vTexCoord*(1.0-vTexCoord);
    float vignette = 1.0-VIGNETTE_STRENGTH*(1.0-pow(clamp(p.x*p.y*16.0,0.0,1.0),0.35));
    color *= vignette;
    color = pow(clamp(color,0.0,1.0),vec3(1.0/2.2));
    // Sub-LSB static dither reduces banding in skies, with no temporal shimmer.
    color += (hash12(gl_FragCoord.xy)-0.5)/255.0;
    gl_FragColor = vec4(clamp(color,0.0,1.0),1.0);
}
