#ifndef LV_MATERIAL_LIGHT
#define LV_MATERIAL_LIGHT
bool mappedEmitter(float m) {
    return (m>10009.5 && m<10011.5) || (m>10019.5 && m<10025.5)
        || (m>10099.5 && m<10117.5);
}
bool thinEmitter(float m) {
    int id=int(m+0.5);
    return id==10020 || id==10021 || id==10024 || id==10103
        || id==10104 || id==10106 || id==10108 || id==10109
        || id==10114 || id==10115;
}
// Artistic linear-light spectra. Brightness/range come from the block's
// actual emission attribute, so unlit blocks never acquire invented light.
vec3 materialEmissionColor(float m) {
    int id=int(m+0.5);
    if(id==10020 || id==10112 || id==10114 || id==10117) return vec3(1.0,0.40,0.09);
    if(id==10021) return vec3(0.10,0.62,1.0);
    if(id==10022) return vec3(1.0,0.76,0.34); // Glowstone
    if(id==10023) return vec3(0.48,0.84,1.0); // Sea lantern
    if(id==10024) return vec3(1.0,0.035,0.008);
    if(id==10025) return vec3(1.0,0.42,0.78); // Pearlescent froglight
    if(id==10011) return vec3(1.0,0.22,0.025);
    if(id==10100) return vec3(1.0,0.49,0.20); // Shroomlight
    if(id==10101) return vec3(1.0,0.83,0.40); // Ochre froglight
    if(id==10102) return vec3(0.44,1.0,0.57); // Verdant froglight
    if(id==10103) return vec3(1.0,0.90,0.78); // End rod
    if(id==10104) return vec3(0.60,0.27,1.0); // Amethyst buds / cluster
    if(id==10105) return vec3(0.52,0.11,1.0); // Crying obsidian
    if(id==10106 || id==10113 || id==10116) return vec3(0.56,0.18,1.0);
    if(id==10107) return vec3(0.035,0.64,0.87); // Emissive sculk variants
    if(id==10108) return vec3(0.50,1.0,0.77); // Glow lichen
    if(id==10109) return vec3(1.0,0.64,0.17); // Glow berries
    if(id==10110) return vec3(0.88,0.96,1.0); // Beacon
    if(id==10111) return vec3(0.24,0.91,1.0); // Conduit
    if(id==10115) return vec3(1.0,0.56,0.25); // Dim brown mushroom
    return vec3(1.0); // Invisible light / unknown source
}
bool lightFilterMaterial(float m) { return m>10039.5 && m<10059.5; }
vec3 materialTransmission(float m) {
    // Linear RGB transmittance, not the displayed surface color. All sixteen
    // dye colors have separate IDs; clear glass, ice, honey and slime follow.
    vec3 c=vec3(0.97);
    int id=int(m+0.5)-10040;
    if(id==0) c=vec3(0.90,0.94,0.98);       // White
    else if(id==1) c=vec3(0.98,0.40,0.055); // Orange
    else if(id==2) c=vec3(0.86,0.08,0.65);  // Magenta
    else if(id==3) c=vec3(0.16,0.56,0.95);  // Light blue
    else if(id==4) c=vec3(0.98,0.83,0.07);  // Yellow
    else if(id==5) c=vec3(0.43,0.95,0.07);  // Lime
    else if(id==6) c=vec3(0.98,0.30,0.56);  // Pink
    else if(id==7) c=vec3(0.24,0.27,0.30);  // Gray
    else if(id==8) c=vec3(0.58,0.61,0.64);  // Light gray
    else if(id==9) c=vec3(0.045,0.72,0.77); // Cyan
    else if(id==10) c=vec3(0.43,0.065,0.87);// Purple
    else if(id==11) c=vec3(0.065,0.18,0.96);// Blue
    else if(id==12) c=vec3(0.48,0.18,0.055);// Brown
    else if(id==13) c=vec3(0.15,0.55,0.045);// Green
    else if(id==14) c=vec3(0.95,0.055,0.04);// Red
    else if(id==15) c=vec3(0.055,0.06,0.07);// Black
    else if(id==17) c=vec3(0.72,0.87,0.97);// Ice
    else if(id==18) c=vec3(0.94,0.58,0.12);// Honey
    else if(id==19) c=vec3(0.42,0.92,0.25);// Slime
    return mix(vec3(0.97),c,GLASS_TINT_STRENGTH);
}
#endif
