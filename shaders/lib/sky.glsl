#ifndef LV_SKY
#define LV_SKY
float cloudNoise(vec2 p) {
    float n = valueNoise(p)*0.57;
#if CLOUD_QUALITY >= 2
    n += valueNoise(p*2.03+vec2(7.1,13.7))*0.29;
    n += valueNoise(p*4.11+vec2(19.3,3.7))*0.14;
#else
    n += valueNoise(p*2.03+vec2(7.1,13.7))*0.43;
#endif
    return n;
}
vec3 atmosphere(vec3 ray) {
#ifdef DIM_NETHER
    return max(toLinear(fogColor)*0.8,vec3(0.025,0.006,0.003));
#elif defined(DIM_END)
    float glow = pow(1.0-abs(ray.y),4.0);
    return mix(vec3(0.014,0.009,0.034),vec3(0.09,0.035,0.13),glow);
#else
    vec3 sun = sunDirection();
    float day = smoothstep(-0.10,0.15,sun.y);
    float height = pow(saturate(ray.y),0.45);
    float sunset = exp(-abs(sun.y)*9.0) * (1.0-rainStrength*0.7);
    float facing = pow(saturate(dot(ray,sun)*0.5+0.5),6.0);
    vec3 zenith = mix(vec3(0.004,0.009,0.025)*NIGHT_BRIGHTNESS/0.28,
                      vec3(0.075,0.25,0.55),day);
    vec3 horizon = mix(vec3(0.024,0.032,0.065)*NIGHT_BRIGHTNESS/0.28,
                       vec3(0.50,0.68,0.83),day);
    horizon = mix(horizon,vec3(0.95,0.29,0.075),sunset*day*(0.22+0.42*facing));
    vec3 sky = mix(horizon,zenith,height);
    sky += vec3(0.75,0.22,0.045)*sunset*pow(1.0-height,3.0)*(0.28+facing);
    sky += sunRadiance()*pow(saturate(dot(ray,sun)),24.0)*0.08*day;
    sky = mix(sky,vec3(luminance(sky))*vec3(0.86,0.96,1.08),rainStrength*0.75);
    sky *= 1.0-rainStrength*0.3;
    float below = 1.0-smoothstep(-0.35,0.0,ray.y);
    return mix(sky,horizon*0.65,below);
#endif
}
vec3 skyWithClouds(vec3 ray,out float cloudMask) {
    vec3 sky = atmosphere(ray);
    cloudMask = 0.0;
#if !defined(DIM_NETHER) && !defined(DIM_END) && CLOUD_QUALITY > 0
    float t = (192.0-cameraPosition.y) / (abs(ray.y)<0.025 ? 0.025 : ray.y);
    if (t > 0.0 && abs(ray.y) > 0.025) {
        vec2 p = (cameraPosition.xz+ray.xz*t)*0.0018;
        p += vec2(frameTimeCounter*0.003,frameTimeCounter*0.0012);
        float n = cloudNoise(p);
        float threshold = 1.0-CLOUD_COVERAGE-rainStrength*0.09;
        float density = smoothstep(threshold,threshold+0.20,n);
        float edge = smoothstep(threshold-0.025,threshold+0.055,n)*(1.0-density);
        float day = daylight();
        float rim = pow(saturate(dot(ray,sunDirection())),10.0);
        vec3 cloud = mix(vec3(0.022,0.030,0.058)*NIGHT_BRIGHTNESS/0.28,
                         mix(vec3(0.72,0.79,0.88),sunRadiance()*0.70,0.35),day);
        cloud *= 1.0-density*0.22-rainStrength*0.35;
        cloud += sunRadiance()*edge*rim*0.45*day;
        float fade = smoothstep(0.025,0.16,abs(ray.y))*exp(-t*0.000035);
        cloudMask = density*fade*0.92;
        sky = mix(sky,cloud,cloudMask);
#if CLOUD_QUALITY == 3
        float wisps = valueNoise(p*2.0+vec2(23.0,17.0));
        float high = smoothstep(0.65,0.88,wisps)*fade*0.16;
        sky = mix(sky,cloud*1.05,high);
        cloudMask = 1.0-(1.0-cloudMask)*(1.0-high);
#endif
    }
#endif
    return sky;
}
vec3 celestialSky(vec3 ray) {
    float cloudMask;
    vec3 sky = skyWithClouds(ray,cloudMask);
#ifndef DIM_NETHER
    float day = daylight();
#ifdef DIM_END
    day = 0.0;
#endif
    if (ray.y > 0.0 && day < 0.99) {
        vec2 starUV = vec2(atan(ray.z,ray.x),asin(clamp(ray.y,-1.0,1.0)))*120.0;
        vec2 cell = floor(starUV);
        float seed = hash12(cell);
        vec2 centre = vec2(hash12(cell+71.0),hash12(cell+19.0))*0.65+0.175;
        float dist = length(fract(starUV)-centre);
        float aa = max(length(fwidth(starUV))*0.6,0.012);
        float star = (1.0-smoothstep(0.025,0.025+aa,dist))*step(0.993,seed);
        float twinkle = 0.88+0.12*sin(frameTimeCounter*0.8+seed*300.0);
        sky += mix(vec3(0.65,0.78,1.0),vec3(1.0,0.85,0.65),seed)*star*twinkle*
               (1.0-day)*(1.0-rainStrength)*(1.0-cloudMask)*smoothstep(0.0,0.2,ray.y)*1.6;
    }
#ifndef DIM_END
    vec3 sun = sunDirection();
    float sunDisc = smoothstep(0.99970,0.99975,dot(ray,sun));
    float moonDisc = smoothstep(0.99972,0.99977,dot(ray,-sun));
    vec3 moonDir = -sun;
    vec3 right = normalize(cross(moonDir,vec3(0.0,1.0,0.0)));
    vec3 up = cross(right,moonDir);
    vec2 moonUV = vec2(dot(ray,right),dot(ray,up))/0.024;
    float phase = float(moonPhase)*PI/4.0;
    float facing = moonUV.x*sin(phase)+sqrt(max(0.0,1.0-dot(moonUV,moonUV)))*cos(phase);
    float moonMask = smoothstep(-0.08,0.08,facing);
    float visible = (1.0-rainStrength*0.9)*(1.0-cloudMask);
    sky += sunRadiance()*sunDisc*5.0*visible;
    sky += vec3(0.50,0.64,0.91)*moonDisc*moonMask*visible;
#endif
#endif
    return sky;
}
#endif
