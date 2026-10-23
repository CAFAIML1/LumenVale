#ifndef LV_COMPATIBILITY
#define LV_COMPATIBILITY
// Optional Iris features are advertised only when the loader can supply them.
// Keep properties resource/pass guards in sync with this condition.
#if !defined(IRIS_FEATURE_CUSTOM_IMAGES) || !defined(IRIS_FEATURE_COMPUTE_SHADERS) || !defined(IRIS_FEATURE_REVERSED_CULLING) || !defined(IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE)
#undef VOXEL_LIGHTING
#undef COLORED_LIGHT_BOUNCE
#undef COLORED_LIGHT_TRANSMISSION
#endif
#endif
