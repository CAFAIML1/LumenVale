#ifndef LV_HELD_MATERIAL
#define LV_HELD_MATERIAL
#include "/lib/material_light.glsl"
float heldMaterial(int item) {
    if(item==10200) return 10011.0; // Lava bucket has no BlockItem light value.
    if(item==10201) return 10109.0; // Picked glow berries retain their glow.
    return float(item);
}
float heldLevel(int item,int reported) {
    float level=clamp(float(reported),0.0,15.0);
    if(item==10200) level=max(level,15.0);
    if(item==10201) level=max(level,14.0);
    return level;
}
#endif
