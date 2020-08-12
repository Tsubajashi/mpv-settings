//!HOOK LUMA
//!BIND HOOKED
//!DESC gaussian smoothed film grain
//!COMPUTE 32 32

#define INTENSITY 0.015
#define TAPS 3

const uint row_size = 2 * TAPS + 1;
const float weights[row_size] = {
#if TAPS == 1
    0.10650697891920,
    0.78698604216159,
    0.10650697891920,
#endif

#if TAPS == 2
    0.05448868454964,
    0.24420134200323,
    0.40261994689424,
    0.24420134200323,
    0.05448868454964,
#endif

#if TAPS == 3
    0.03663284536919,
    0.11128075847888,
    0.21674532140370,
    0.27068214949642,
    0.21674532140370,
    0.11128075847888,
    0.03663284536919,
#endif

#if TAPS == 4
    0.02763055063889,
    0.06628224528636,
    0.12383153680577,
    0.18017382291138,
    0.20416368871516,
    0.18017382291138,
    0.12383153680577,
    0.06628224528636,
    0.02763055063889,
#endif

#if TAPS == 5
    0.02219054849244,
    0.04558899978527,
    0.07981140824009,
    0.11906462996609,
    0.15136080967773,
    0.16396720767670,
    0.15136080967773,
    0.11906462996609,
    0.07981140824009,
    0.04558899978527,
    0.02219054849244,
#endif
};

const uvec2 isize = uvec2(gl_WorkGroupSize) + uvec2(2 * TAPS);
shared float grain[isize.y][isize.x];

// PRNG
float permute(float x)
{
    x = (34.0 * x + 1.0) * x;
    return fract(x * 1.0/289.0) * 289.0;
}

float seed(uvec2 pos)
{
    const float phi = 1.61803398874989;
    vec3 m = vec3(fract(phi * vec2(pos)), random) + vec3(1.0);
    return permute(permute(m.x) + m.y) + m.z;
}

float rand(inout float state)
{
    state = permute(state);
    return fract(state * 1.0/41.0);
}

// Turns uniform white noise into gaussian white noise by passing it
// through an approximation of the gaussian quantile function
float rand_gaussian(inout float state) {
    const float a0 = 0.151015505647689;
    const float a1 = -0.5303572634357367;
    const float a2 = 1.365020122861334;
    const float b0 = 0.132089632343748;
    const float b1 = -0.7607324991323768;

    float p = 0.95 * rand(state) + 0.025;
    float q = p - 0.5;
    float r = q * q;

    float g = q * (a2 + (a1 * r + a0) / (r*r + b1*r + b0));
    g *= 0.255121822830526; // normalize to [-1,1)
    return g;
}

void hook()
{
    // generate grain in `grain`
    uint num_threads = gl_WorkGroupSize.x * gl_WorkGroupSize.y;
    for (uint i = gl_LocalInvocationIndex; i < isize.y * isize.x; i += num_threads) {
        uvec2 pos = uvec2(i % isize.y, i / isize.y);
        float state = seed(gl_WorkGroupID.xy * gl_WorkGroupSize.xy + pos);
        grain[pos.y][pos.x] = rand_gaussian(state);
    }

    // make writes visible
    barrier();

    // convolve horizontally
    for (uint y = gl_LocalInvocationID.y; y < isize.y; y += gl_WorkGroupSize.y) {
        float hsum = 0;
        for (uint x = 0; x < row_size; x++) {
            float g = grain[y][gl_LocalInvocationID.x + x];
            hsum += weights[x] * g;
        }

        // update grain LUT
        grain[y][gl_LocalInvocationID.x + TAPS] = hsum;
    }

    barrier();

    // convolve vertically
    float vsum = 0.0;
    for (uint y = 0; y < row_size; y++) {
        float g = grain[gl_LocalInvocationID.y + y][gl_LocalInvocationID.x + TAPS];
        vsum += weights[y] * g;
    }

    vec4 color = HOOKED_tex(HOOKED_pos);
    color.rgb += vec3(INTENSITY * vsum);
    imageStore(out_image, ivec2(gl_GlobalInvocationID), color);
}