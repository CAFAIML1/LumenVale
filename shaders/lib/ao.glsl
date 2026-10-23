float ambientOcclusion(vec2 uv,vec3 p,vec3 normal) {
#if AO_SAMPLES > 0
    if (p.z > -1.0 || length(p)>80.0) return 1.0;
    float radius = 0.85;
    float screenRadius = min(0.09,radius*gbufferProjection[1][1]/max(-p.z,0.1)*0.5);
    float sum = 0.0;
    // Fixed directions avoid temporal noise and history buffers.
    for (int i=0; i<AO_SAMPLES; i++) {
        float angle = (float(i)+0.375)*6.2831853/float(AO_SAMPLES);
        float ring = 0.55+0.45*mod(float(i),2.0);
        vec2 q = uv+vec2(cos(angle)/aspectRatio,sin(angle))*screenRadius*ring;
        if (min(q.x,q.y)>0.001 && max(q.x,q.y)<0.999) {
            float d = texture2D(depthtex0,q).r;
            if (d < 0.999999) {
                vec3 delta = viewPosition(q,d)-p;
                float dist = length(delta);
                float facing = max(dot(normal,delta/max(dist,0.0001))-0.09,0.0);
                sum += facing*(1.0-smoothstep(0.08,radius,dist));
            }
        }
    }
    return clamp(1.0-sum*(AO_STRENGTH*2.0/float(AO_SAMPLES)),0.45,1.0);
#else
    return 1.0;
#endif
}
