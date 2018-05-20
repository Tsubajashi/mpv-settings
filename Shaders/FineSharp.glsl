// FineSharp by Didйe

//!HOOK LUMA
//!BIND HOOKED
//!COMPONENTS 2
//!DESC FineSharp convolution

#define Src(a,b)    HOOKED_texOff(vec2(a,b))

vec4 hook() {
	vec4 o = Src(0,0).xxzw;
	o.x *= 0.25;
	o.x += (Src( 0,-1).x+Src(-1, 0).x+Src( 1, 0).x+Src( 0, 1).x) * 0.125;
	o.x += (Src(-1,-1).x+Src( 1,-1).x+Src(-1, 1).x+Src( 1, 1).x) * 0.0625;

	return o;
}

//!HOOK LUMA
//!BIND HOOKED
//!DESC FineSharp sharpening

#define sstr 1.0    // Strength of sharpening, 0.0 up to 8.0 or more. If you change this, then alter cstr below
#define lstr 1.49   // Modifier for non-linear sharpening
#define pstr 1.272  // Exponent for non-linear sharpening
#define ldmp (sstr+0.1) // "Low damp", to not over-enhance very small differences (noise coming out of flat areas)

#define Src(a,b)    HOOKED_texOff(vec2(a,b))

#define sort(a1,a2)                         (t=min(a1,a2),a2=max(a1,a2),a1=t)
#define median3(a1,a2,a3)                   (sort(a2,a3),sort(a1,a2),min(a2,a3))
#define median5(a1,a2,a3,a4,a5)             (sort(a1,a2),sort(a3,a4),sort(a1,a3),sort(a2,a4),median3(a2,a3,a5))
#define median9(a1,a2,a3,a4,a5,a6,a7,a8,a9) (sort(a1,a2),sort(a3,a4),sort(a5,a6),sort(a7,a8),\
                                             sort(a1,a3),sort(a5,a7),sort(a1,a5),sort(a3,a5),sort(a3,a7),\
                                             sort(a2,a4),sort(a6,a8),sort(a4,a8),sort(a4,a6),sort(a2,a6),median5(a2,a4,a5,a7,a9))

#define SharpDiff(t) (sign(t) * (sstr/255.0) * pow(abs(t)/(lstr/255.0), 1.0/pstr) * (pow(t, 2.0)/(pow(t, 2.0)+ldmp/(255.0*255.0))))

vec4 hook() {
	vec4 o = Src(0,0);

	float t;
	float t1 = Src(-1,-1).x;
	float t2 = Src( 0,-1).x;
	float t3 = Src( 1,-1).x;
	float t4 = Src(-1, 0).x;
	float t5 = o.x;
	float t6 = Src( 1, 0).x;
	float t7 = Src(-1, 1).x;
	float t8 = Src( 0, 1).x;
	float t9 = Src( 1, 1).x;
	o.x = median9(t1,t2,t3,t4,t5,t6,t7,t8,t9);

	o.x = o.y + SharpDiff(o.y-o.x);
	return o;
}

//!HOOK LUMA
//!BIND HOOKED
//!COMPONENTS 1
//!DESC FineSharp equalisation

#define cstr 0.9    // Strength of equalisation, 0.0 to 2.0 or more. Suggested settings for cstr based on sstr value: 
                    // sstr=0->cstr=0, sstr=0.5->cstr=0.1, 1.0->0.6, 2.0->0.9, 2.5->1.00, 3.0->1.09, 3.5->1.15, 4.0->1.19, 8.0->1.249, 255.0->1.5

#define Src(a,b)    HOOKED_texOff(vec2(a,b))
#define sd(a,b)     (Src(a,b).x - Src(a,b).y)

vec4 hook() {
	vec4 o = Src(0,0);
	float c = (o.x-o.y)*0.25;
	c += (sd( 0,-1)+sd(-1, 0)+sd( 1, 0)+sd( 0, 1))*0.125;
	c += (sd(-1,-1)+sd( 1,-1)+sd(-1, 1)+sd( 1, 1))*0.0625;
	o.x -= cstr * c;
	return o;
}
