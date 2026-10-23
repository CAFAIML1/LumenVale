#ifndef LV_SETTINGS
#define LV_SETTINGS

// LumenVale 2.2.0 - Directional face bounce / logical emitter spectra.
#define SHADOWS // Directional shadow mapping.
const int shadowMapResolution = 2048; // [1024 2048 3072 4096]
const float shadowDistance = 96.0; // [48.0 64.0 96.0 128.0 160.0]
#define SHADOW_SAMPLES 4 // [1 4 8 16]
#define SHADOW_SOFTNESS 1.25 // [0.75 1.0 1.25 1.75 2.5]
#define AO_SAMPLES 4 // [0 4 8 12]
#define AO_STRENGTH 0.65 // [0.0 0.35 0.5 0.65 0.8 1.0]
#define CLOUD_QUALITY 1 // [0 1 2 3]
#define CLOUD_COVERAGE 0.48 // [0.3 0.4 0.48 0.55 0.65]
#define WATER_WAVES 0.75 // [0.0 0.4 0.75 1.0 1.4]
#define WATER_DETAIL 1 // [0 1 2 3]
#define WATER_DENSITY 0.8 // [0.35 0.55 0.8 1.0 1.4 2.0]
#define WATER_REFRACTION 0.65 // [0.0 0.35 0.65 1.0]
#define WATER_SSR_STEPS 0 // [0 8 12 16 20 28 32 40]
#define WATER_SSR_DISTANCE 48.0 // [24.0 48.0 64.0]
#define WATER_FOAM 0.3 // [0.0 0.15 0.3 0.5 0.75]
#define WATER_CAUSTICS 0.0 // [0.0 0.15 0.25 0.4]
#define WATER_CLOUD_REFLECTION // Procedural cloud fallback for screen reflections.
//#define WATER_RAIN_RIPPLES // Localized rings during rain.
#define WAVING_FOLIAGE // Animate leaves and plants in geometry and shadows.
#define WIND_STRENGTH 0.65 // [0.0 0.35 0.65 1.0 1.4]
#define HAND_LIGHT // Warm light for emissive items in either hand.
#define BLOOM // Half-resolution, separable highlight bloom.
#define BLOOM_STRENGTH 0.14 // [0.0 0.08 0.14 0.2 0.3]
#define FXAA // Spatial edge antialiasing, without temporal history.
#define EXPOSURE 1.05 // [0.75 0.9 1.0 1.05 1.15 1.3 1.5]
#define SATURATION 1.04 // [0.8 0.9 1.0 1.04 1.1 1.2]
#define FOG_DENSITY 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define NIGHT_BRIGHTNESS 0.28 // [0.15 0.22 0.28 0.4 0.6]
#define VIGNETTE_STRENGTH 0.1 // [0.0 0.05 0.1 0.15 0.25]

//#define VOXEL_LIGHTING // 64-cubed local occluded colored light propagation.
#define VOXEL_STRENGTH 1.0 // [0.5 0.75 1.0 1.25 1.5]
//#define COLORED_LIGHT_BOUNCE // One diffuse bounce using surface albedo.
//#define COLORED_LIGHT_TRANSMISSION // Glass and translucent material filtering.
#define LIGHT_BOUNCE_STRENGTH 0.75 // [0.0 0.35 0.5 0.75 1.0 1.25]
#define GLASS_TINT_STRENGTH 1.0 // [0.0 0.35 0.65 1.0]
//#define VOLUMETRIC_LIGHT // Shadowed atmospheric scattering and local light fog.
#define VOLUMETRIC_STEPS 24 // [12 24 32]
#define VOLUMETRIC_DENSITY 1.0 // [0.5 0.75 1.0 1.5 2.0]
//#define SHADOW_PCSS // Blocker search and variable shadow penumbra.
//#define CINEMATIC_SURFACES // Polished and rain-wet scene reflections.
#define SURFACE_SSR_STEPS 24 // [12 24 40]
//#define CINEMATIC_GRADE // Gentle split-toning and film contrast.
//#define DEPTH_OF_FIELD // Subtle, center-focused lens blur.
#define DOF_STRENGTH 0.35 // [0.0 0.2 0.35 0.6 1.0]

const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize = 2.0;
const float sunPathRotation = -30.0;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const float ambientOcclusionLevel = 0.85;
const float wetnessHalflife = 35.0;
const float drynessHalflife = 70.0;
const float eyeBrightnessHalflife = 6.0;
const float centerDepthHalflife = 0.75;
const float voxelDistance = 48.0;

#endif
