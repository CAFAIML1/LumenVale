#include "/lib/settings.glsl"
uniform sampler2D colortex2;
uniform float viewWidth;
uniform float viewHeight;
varying vec2 vTexCoord;
/* Loader-only buffer directive; RGBA16F is not a GLSL symbol.
const int colortex3Format = RGBA16F;
*/
const bool colortex3Clear = false;
/* DRAWBUFFERS:3 */
void main() {
    vec3 c = vec3(0.0);
#ifdef BLOOM
    vec2 texel = 2.0/vec2(viewWidth,viewHeight);
    for (int i=-4; i<=4; i++) {
        float w = exp(-float(i*i)/8.0);
        vec2 uv = clamp(vTexCoord+vec2(0.0,float(i)*texel.y),texel*0.5,vec2(1.0)-texel*0.5);
        c += texture2D(colortex2,uv).rgb*w;
    }
    c /= 4.89803;
#endif
    gl_FragData[0] = vec4(c,1.0);
}
