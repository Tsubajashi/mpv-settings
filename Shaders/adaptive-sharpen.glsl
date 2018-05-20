// Copyright (c) 2015-2017, bacondither
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer
//    in this position and unchanged.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// Adaptive sharpen - version 2017-12-30 - (requires ps >= 3.0)
// Tuned for use post resize

//!HOOK SCALED
//!BIND HOOKED
//!BIND LINEAR
//!DESC adaptive-sharpen

//--------------------------------------- Settings ------------------------------------------------

#define str             1.0                  // Main control of sharpening strength [>0]
                                             // 0.3 <-> 2.0 is a reasonable range of values

#define video_level_out false                // True to preserve BTB & WTW (minor summation error)
                                             // Normally it should be set to false

// Defined values under this row are "optimal" DO NOT CHANGE IF YOU DO NOT KNOW WHAT YOU ARE DOING!

#define curveslope      0.5                  // Sharpening curve slope, high edge values

#define L_overshoot     0.003                // Max light overshoot before compression [>0.001]
#define L_compr_low     0.167                // Light compression, default (0.169=~9x)
#define L_compr_high    0.334                // Light compression, surrounded by edges (0.337=~4x)

#define D_overshoot     0.009                // Max dark overshoot before compression [>0.001]
#define D_compr_low     0.250                // Dark compression, default (0.253=~6x)
#define D_compr_high    0.500                // Dark compression, surrounded by edges (0.504=~2.5x)

#define scale_lim       0.1                  // Abs max change before compression (0.1=+-10%)
#define scale_cs        0.056                // Compression slope above scale_lim

#define pm_p            sat(1.0/str)         // Power mean p-value [>0-1.0]
//-------------------------------------------------------------------------------------------------

// Soft limit
#define soft_lim(v,s)  ( (exp(2.0*min(abs(v), s*24.0)/s) - 1.0)/(exp(2.0*min(abs(v), s*24.0)/s) + 1.0)*s )

// Weighted power mean
#define wpmean(a,b,c)  ( pow((c*pow(abs(a), pm_p) + (1.0-c)*pow(b, pm_p)), (1.0/pm_p)) )

// Get destination pixel values
#define get(x,y)       ( HOOKED_texOff(vec2(x, y)).xyz )
#define getL(x,y)      ( LINEAR_tex(LINEAR_pt*(LINEAR_pos * input_size + tex_offset + vec2(x,y))).xyz )
#define sat(x)         ( clamp(x, 0.0, 1.0) )

// Colour to luma, fast approx gamma, avg of rec. 709 & 601 luma coeffs
#define CtL(RGB)       ( dot(vec3(0.2558, 0.6511, 0.0931), RGB.rgb) )

// Center pixel diff
#define mdiff(a,b,c,d,e,f,g) ( abs(luma[g] - luma[a]) + abs(luma[g] - luma[b])       \
                             + abs(luma[g] - luma[c]) + abs(luma[g] - luma[d])       \
                             + 0.5*(abs(luma[g] - luma[e]) + abs(luma[g] - luma[f])) )

#define Gamma(x)       ( pow(x, vec3(1.0/2.2)) )
#define GammaInv(x)    ( pow(sat(x), vec3(2.2)) )

vec4 hook() {

    vec4 o = HOOKED_tex(HOOKED_pos);

    // Get points, saturate colour data in c[0]
    // [                c22               ]
    // [           c24, c9,  c23          ]
    // [      c21, c1,  c2,  c3, c18      ]
    // [ c19, c10, c4,  c0,  c5, c11, c16 ]
    // [      c20, c6,  c7,  c8, c17      ]
    // [           c15, c12, c14          ]
    // [                c13               ]
    vec3 c[25] = vec3[](sat(o.rgb), get(-1,-1), get( 0,-1), get( 1,-1), get(-1, 0),
                        get( 1, 0), get(-1, 1), get( 0, 1), get( 1, 1), get( 0,-2),
                        get(-2, 0), get( 2, 0), get( 0, 2), get( 0, 3), get( 1, 2),
                        get(-1, 2), get( 3, 0), get( 2, 1), get( 2,-1), get(-3, 0),
                        get(-2, 1), get(-2,-1), get( 0,-3), get( 1,-2), get(-1,-2));

    // Blur, gauss 3x3
    vec3  blur   = (2.0 * (c[2]+c[4]+c[5]+c[7]) + (c[1]+c[3]+c[6]+c[8]) + 4.0 * c[0]) / 16.0;

    // Contrast compression, center = 0.5, scaled to 1/3
    float c_comp = sat(0.266666681f + 0.9*exp2(dot(blur, vec3(-7.4/3.0))));

    // Edge detection
    // Relative matrix weights
    // [          1          ]
    // [      4,  5,  4      ]
    // [  1,  5,  6,  5,  1  ]
    // [      4,  5,  4      ]
    // [          1          ]
    float edge = length( 1.38*abs(blur - c[0])
                       + 1.15*(abs(blur - c[2]) + abs(blur - c[4]) + abs(blur - c[5]) + abs(blur - c[7]))
                       + 0.92*(abs(blur - c[1]) + abs(blur - c[3]) + abs(blur - c[6]) + abs(blur - c[8])) );

    vec3 blurL = ( (getL(-1, 0) + getL(0, 1) + getL(1, 0) + getL(0, -1)) * 2.0
                 + (getL(-1, 1) + getL(1, 1) + getL(1, -1) + getL(-1, -1))
                 + getL(0, 0) * 4.0) / 16.0;

    float edgeL = length( 1.38*abs(blurL - getL(0, 0))
                        + 1.15*(abs(blurL - getL(0, -1)) + abs(blurL - getL(-1, 0)) + abs(blurL - getL(1, 0)) + abs(blurL - getL(0, 1)))
                        + 0.92*(abs(blurL - getL(-1,-1)) + abs(blurL - getL( 1,-1)) + abs(blurL - getL(-1,1)) + abs(blurL - getL(1, 1))) );

    float curve_height = str * sat(edgeL / edge) * max(LINEAR_pt.y * SCALED_size.y, 1.0);

    edge *= c_comp;

    // RGB to luma
    float c0_Y = CtL(c[0]);

    float luma[25] = float[](c0_Y, CtL(c[1]), CtL(c[2]), CtL(c[3]), CtL(c[4]), CtL(c[5]), CtL(c[6]),
                             CtL(c[7]),  CtL(c[8]),  CtL(c[9]),  CtL(c[10]), CtL(c[11]), CtL(c[12]),
                             CtL(c[13]), CtL(c[14]), CtL(c[15]), CtL(c[16]), CtL(c[17]), CtL(c[18]),
                             CtL(c[19]), CtL(c[20]), CtL(c[21]), CtL(c[22]), CtL(c[23]), CtL(c[24]));

    // Precalculated default squared kernel weights
    const vec3 w1 = vec3(0.5,           1.0, 1.41421356237); // 0.25, 1.0, 2.0
    const vec3 w2 = vec3(0.86602540378, 1.0, 0.54772255751); // 0.75, 1.0, 0.3

    // Transition to a concave kernel if the center edge val is above thr
    vec3 dW = pow(mix( w1, w2, smoothstep( 0.3, 0.8, edge)), vec3(2.0));

    float mdiff_c0  = 0.02 + 3.0*( abs(luma[0]-luma[2]) + abs(luma[0]-luma[4])
                                 + abs(luma[0]-luma[5]) + abs(luma[0]-luma[7])
                                 + 0.25*(abs(luma[0]-luma[1]) + abs(luma[0]-luma[3])
                                        +abs(luma[0]-luma[6]) + abs(luma[0]-luma[8])) );

    // Use lower weights for pixels in a more active area relative to center pixel area
    // This results in narrower and less visible overshoots around sharp edges
    float weights[12]  = float[](( min((mdiff_c0/mdiff(24, 21, 2,  4,  9,  10, 1)),  dW.y) ),
                                 ( dW.x ),
                                 ( min((mdiff_c0/mdiff(23, 18, 5,  2,  9,  11, 3)),  dW.y) ),
                                 ( dW.x ),
                                 ( dW.x ),
                                 ( min((mdiff_c0/mdiff(4,  20, 15, 7,  10, 12, 6)),  dW.y) ),
                                 ( dW.x ),
                                 ( min((mdiff_c0/mdiff(5,  7,  17, 14, 12, 11, 8)),  dW.y) ),
                                 ( min((mdiff_c0/mdiff(2,  24, 23, 22, 1,  3,  9)),  dW.z) ),
                                 ( min((mdiff_c0/mdiff(20, 19, 21, 4,  1,  6,  10)), dW.z) ),
                                 ( min((mdiff_c0/mdiff(17, 5,  18, 16, 3,  8,  11)), dW.z) ),
                                 ( min((mdiff_c0/mdiff(13, 15, 7,  14, 6,  8,  12)), dW.z) ));

    weights[0] = (max(max((weights[8]  + weights[9])/4.0,  weights[0]), 0.25) + weights[0])/2.0;
    weights[2] = (max(max((weights[8]  + weights[10])/4.0, weights[2]), 0.25) + weights[2])/2.0;
    weights[5] = (max(max((weights[9]  + weights[11])/4.0, weights[5]), 0.25) + weights[5])/2.0;
    weights[7] = (max(max((weights[10] + weights[11])/4.0, weights[7]), 0.25) + weights[7])/2.0;

    // Calculate the negative part of the laplace kernel
    float weightsum   = 0.0;
    float neg_laplace = 0.0;

    for (int pix = 0; pix < 12; ++pix)
    {
        neg_laplace  += luma[pix+1]*weights[pix];
        weightsum    += weights[pix];
    }

    neg_laplace = neg_laplace / weightsum;

    // Compute sharpening magnitude function
    float sharpen_val = (curve_height/(curve_height*curveslope*pow((edge), 3.5) + 0.625)) * edge/edgeL;

    // Calculate sharpening diff and scale
    float sharpdiff = (c0_Y - neg_laplace)*(sharpen_val + 0.01);

    // Calculate local near min & max, partial sort
    float temp;

    for (int i1 = 0; i1 < 24; i1 += 2)
    {
        temp = luma[i1];
        luma[i1]   = min(luma[i1], luma[i1+1]);
        luma[i1+1] = max(temp, luma[i1+1]);
    }

    for (int i2 = 24; i2 > 0; i2 -= 2)
    {
        temp = luma[0];
        luma[0]    = min(luma[0], luma[i2]);
        luma[i2]   = max(temp, luma[i2]);

        temp = luma[24];
        luma[24] = max(luma[24], luma[i2-1]);
        luma[i2-1] = min(temp, luma[i2-1]);
    }

    for (int i1 = 1; i1 < 24-1; i1 += 2)
    {
        temp = luma[i1];
        luma[i1]   = min(luma[i1], luma[i1+1]);
        luma[i1+1] = max(temp, luma[i1+1]);
    }

    for (int i2 = 24-1; i2 > 1; i2 -= 2)
    {
        temp = luma[1];
        luma[1]    = min(luma[1], luma[i2]);
        luma[i2]   = max(temp, luma[i2]);

        temp = luma[24-1];
        luma[24-1] = max(luma[24-1], luma[i2-1]);
        luma[i2-1] = min(temp, luma[i2-1]);
    }

    float nmax = (max(luma[23], c0_Y)*3.0 + luma[24])/4.0;
    float nmin = (min(luma[1],  c0_Y)*3.0 + luma[0])/4.0;

    // Calculate tanh scale factors
    float min_dist  = min(abs(nmax - c0_Y), abs(c0_Y - nmin));
    float pos_scale = min_dist + min(L_overshoot, 1.0001 - min_dist - c0_Y);
    float neg_scale = min_dist + min(D_overshoot, 0.0001 + c0_Y - min_dist);

    pos_scale = min(pos_scale, scale_lim*(1.0 - scale_cs) + pos_scale*scale_cs);
    neg_scale = min(neg_scale, scale_lim*(1.0 - scale_cs) + neg_scale*scale_cs);

    // Soft limited anti-ringing with tanh, wpmean to control compression slope
    sharpdiff = wpmean(max(sharpdiff, 0.0), soft_lim( max(sharpdiff, 0.0), pos_scale ), min(1.0 - sat(edge / edgeL), L_compr_high) )
              - wpmean(min(sharpdiff, 0.0), soft_lim( min(sharpdiff, 0.0), neg_scale ), min(1.0 - sat(edge / edgeL), D_compr_high) );

    vec3 res = GammaInv(Gamma(c[0].rgb) + sharpdiff);

    o.rgb = video_level_out == true ? res + o.rgb - c[0].rgb : res;

    return o;
}
