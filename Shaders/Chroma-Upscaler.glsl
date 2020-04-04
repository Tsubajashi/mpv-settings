//!DESC Chroma-Upscaler
//!HOOK CHROMA
//!BIND HOOKED
//!BIND LUMA
//!WHEN CHROMA.w LUMA.w <
//!WIDTH CHROMA.w 2 *
//!HEIGHT CHROMA.h 2 *
//!OFFSET ALIGN

#define STRENGTH 0.1
#define SPREAD_STRENGTH 2.0
#define KERNELSIZE 3
#define KERNELHALFSIZE 1
#define KERNELLEN 9


float gaussian(float x, float s, float m) {
	return (1 / (s * sqrt(2 * 3.14159))) * exp(-0.5 * pow(abs(x - m) / s, 2.0));
}

vec4 hook() {
	vec2 d = HOOKED_pt;
	
	float vc = LUMA_tex(HOOKED_pos).x;
	
	float s = vc * STRENGTH + 0.0001;
	float ss = SPREAD_STRENGTH + 0.0001;
	
	vec4 valsum = vec4(0);
	float normsum = 0.000001; //Avoid divide by zero
	
	for (int i=0; i<KERNELLEN; i++) {
		vec2 ipos = vec2((i % KERNELSIZE) - KERNELHALFSIZE, (i / KERNELSIZE) - KERNELHALFSIZE);
		float l = LUMA_tex(HOOKED_pos + ipos * d).x;
		float w = gaussian(vc - l, s, 0) * gaussian(distance(vec2(0), ipos), ss, 0);
		valsum += HOOKED_tex(HOOKED_pos + ipos * d) * w;
		normsum += w;
	}
	
	return valsum / normsum;
}