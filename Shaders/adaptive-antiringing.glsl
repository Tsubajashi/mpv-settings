//!HOOK POSTKERNEL
//!BIND HOOKED
//!BIND PREKERNEL
//!WHEN NATIVE_CROPPED.w POSTKERNEL.w <
//!DESC adaptive-antiringing

#define dark_ringing_str    0.19    // [0.1 - 0.2]
#define bright_ringing_str  0.19    // [0.1 - 0.2]

#define sqr(x)      pow(x, 2.0)
#define GetH(x,y)   HOOKED_texOff(vec2(x,y)).rgb
#define GetL(x,y)   PREKERNEL_tex(PREKERNEL_pt*(pos+vec2(x,y)+vec2(0.5))).rgb
#define Luma(rgb)   ( dot(vec3(0.2126, 0.7152, 0.0722), rgb) )

vec4 hook() {
    vec4 color = HOOKED_texOff(0);

    vec2 pos = PREKERNEL_pos * input_size - vec2(0.5);
    pos = pos - fract(pos) + tex_offset;

    float meanH = clamp(Luma((GetH(0, 0) + (GetH(-1, 0) + GetH(0, 1) + GetH(1, 0) + GetH(0, -1)) / 4.0) / 2.0), 0.00001, 1.0);
    float meanL = clamp(Luma((GetL(0, 0) + (GetL(-1, 0) + GetL(0, 1) + GetL(1, 0) + GetL(0, -1)) / 4.0) / 2.0), 0.00001, 1.0);

    vec3 lo = min(min(GetL(0, 0), GetL(0, 1)), min(GetL(1, 0), GetL(1, 1)));
    vec3 hi = max(max(GetL(0, 0), GetL(0, 1)), max(GetL(1, 0), GetL(1, 1)));

    float d = meanL / meanH;
    float s = mix(dark_ringing_str, bright_ringing_str, step(d, 1.0));
    d = mix(d, 1.0 / d, step(d, 1.0));
    color.rgb = mix(clamp(color.rgb, lo, hi), color.rgb, clamp(min(sqr(meanL - meanH) / ((d - 1.0) * sqr(s)), d) / d, 0.0, 1.0));

    return color;
}
