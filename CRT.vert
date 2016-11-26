#version 330 core
/*
CRT shader

Copyright (C) 2010-2012 cgwg, Themaister and DOLLS

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.

(cgwg gave their consent to have the original version of this shader
distributed under the GPL in this message:

    http://board.byuu.org/viewtopic.php?p=26075#p26075

    "Feel free to distribute my shaders under the GPL. After all, the
    barrel distortion code was taken from the Curvature shader, which is
    under the GPL."
)
*/

layout(location = 0) in vec4 position;
layout(location = 1) in vec2 textureCoord;

layout (std140) uniform program
{
	vec2 video_size;
	vec2 texture_size;
	vec2 output_size;
} IN;


out float CRTgamma;
out float monitorgamma;
out vec2  overscan;
out vec2  aspect;
out float d;
out float R;
out float cornersize;
out float cornersmooth;

out vec3 stretch;
out vec2 sinangle;
out vec2 cosangle;

out vec2 texCoord;
out vec2 rubyInputSize;
out vec2 rubyOutputSize;
out vec2 rubyTextureSize;

out vec2 one;
out float mod_factor;

#define FIX(c) max(abs(c), 1e-5);

float intersect(vec2 xy)
{
        float A = dot(xy, xy) + d * d;
        float B = 2.0 * (R * (dot(xy, sinangle) - d * cosangle.x * cosangle.y) - d * d);
        float C = d * d + 2.0 * R * d * cosangle.x * cosangle.y;
        return (-B -sqrt(B * B - 4.0 * A * C)) / (2.0 * A);
}

vec2 bkwtrans(vec2 xy)
{
        float c = intersect(xy);
        vec2 point = vec2(c) * xy;
        point -= vec2(-R) * sinangle;
        point /= vec2(R);
        vec2 tang = sinangle / cosangle;
        vec2 poc = point / cosangle;
        float A = dot(tang, tang) + 1.0;
        float B = -2.0 * dot(poc, tang);
        float C = dot(poc, poc) - 1.0;
        float a = (-B + sqrt(B * B - 4.0 * A * C)) / (2.0 * A);
        vec2 uv = (point - a * sinangle) / cosangle;
        float r = R * acos(a);
        return uv * r / sin(r / R);
}

vec2 fwtrans(vec2 uv)
{
        float r = FIX(sqrt(dot(uv, uv)));
        uv *= sin(r / R) / r;
        float x = 1.0 - cos(r / R);
        float D = d / R + x * cosangle.x * cosangle.y + dot(uv, sinangle);
        return d * (uv * cosangle - x * sinangle) / D;
}

vec3 maxscale()
{
        vec2 c = bkwtrans(-R * sinangle / (1.0 + R / d * cosangle.x * cosangle.y));
        vec2 a = vec2(0.5, 0.5) * aspect;
        vec2 lo = vec2(fwtrans(vec2(-a.x, c.y)).x, fwtrans(vec2(c.x, -a.y)).y) / aspect;
        vec2 hi = vec2(fwtrans(vec2(+a.x, c.y)).x, fwtrans(vec2(c.x, +a.y)).y) / aspect;
        return vec3((hi + lo) * aspect * 0.5, max(hi.x - lo.x, hi.y - lo.y));
}


void main()
{
        // ----- START of parameters -----
        
        // lengths are measured in units of (approximately) the width of the monitor 
        CRTgamma = 2.4;                     // gamma of simulated CRT
        monitorgamma = 2.2;                 // gamma of display monitor (typically 2.2 is correct)
//        overscan = vec2(1.01, 1.01);        // overscan (e.g. 1.02 for 2% overscan)
        overscan = vec2(1, 1);              // overscan (e.g. 1.02 for 2% overscan)
        aspect = vec2(1.0, 0.75);           // aspect ratio
        d = 2.0;                            // simulated distance from viewer to monitor
//        R = 1.5;                            // radius of curvature
        R = 2.5;                            // radius of curvature
        const vec2 angle = vec2(0.0, 0.01); // tilt angle in radians (behavior might be a bit wrong if both components are nonzero)
//        cornersize = 0.03;                  // size of curved corners
        cornersize = 0.02;                  // size of curved corners
        cornersmooth = 1000.0;              // border smoothness parameter (decrease if borders are too aliased)
        
        // ----- END of parameters -----

        
        // Do the standard vertex processing.
        gl_Position = position;
        rubyInputSize = IN.video_size;
        rubyTextureSize = IN.texture_size;
        rubyOutputSize = IN.output_size;
        
        // Precalculate a bunch of useful values we'll need in the fragment shader.
        sinangle = sin(angle);
        cosangle = cos(angle);
        stretch = maxscale();

        // Texture coords.
        texCoord = vec2((position.x+1.0)/2.0*rubyInputSize.x/rubyTextureSize.x,(1.0-position.y)/2.0*rubyInputSize.y/rubyTextureSize.y);
        
        // The size of one texel, in texture-coordinates.
        one = 1.0 / rubyTextureSize;

        // Resulting X pixel-coordinate of the pixel we're drawing.
        mod_factor = texCoord.x * rubyTextureSize.x * rubyOutputSize.x / rubyInputSize.x;
}

