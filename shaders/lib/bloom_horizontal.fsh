#include "/lib/settings.glsl"
uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;
varying vec2 vTexCoord;
/* Loader-only buffer directive; RGBA16F is not a GLSL symbol.
const int colortex2Format = RGBA16F;
*/
const bool colortex2Clear = false;
/* DRAWBUFFERS:2 */
vec3 bright(vec2 uv) {
    vec3 c = texture2D(colortex0,clamp(uv,vec2(0.0),vec2(1.0))).rgb;
    float l = dot(c,vec3(0.2126,0.7152,0.0722));
    float knee = max(l-0.65,0.0);
    return c*(knee/max(l,0.0001));
}
void main() {
    vec2 px = 1.0/vec2(viewWidth,viewHeight);
    vec3 c = vec3(0.0);
#ifdef BLOOM
    // Two vertical taps suppress single-pixel flicker when downsampling.
    for (int i=-4; i<=4; i++) {
        float w = exp(-float(i*i)/8.0);
        vec2 offset = vec2(float(i)*2.0*px.x,px.y*0.5);
        c += (bright(vTexCoord+offset)+bright(vTexCoord+offset*vec2(1.0,-1.0)))*w;
    }
    c /= 9.79606;
#endif
    gl_FragData[0] = vec4(c,1.0);
}
