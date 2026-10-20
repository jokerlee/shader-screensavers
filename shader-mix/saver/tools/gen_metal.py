#!/usr/bin/env python3
"""Translate shaders/<key>.glsl (Shadertoy mainImage) to Metal via glslang + SPIRV-Cross.
usage: gen_metal.py <out_dir>   (writes <key>.metal for every manifest entry)"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'shaders')
HEAD = '''#version 450
layout(location=0) out vec4 st_out;
layout(std140, binding=0) uniform ST { vec3 iResolution; float iTime; vec4 iMouse; vec4 iDate; float iTimeDelta; int iFrame; float iFrameRate; float iSampleRate; vec3 iChannelResolution[4]; float iChannelTime[4]; };
layout(binding=1) uniform sampler2D iChannel0;
layout(binding=2) uniform sampler2D iChannel1;
layout(binding=3) uniform sampler2D iChannel2;
layout(binding=4) uniform sampler2D iChannel3;
#define texture2D texture
#line 1
'''
# Shadertoy's fragCoord origin is bottom-left; Metal's is top-left. fragColor starts at 0.
TAIL = '''
void main(){ vec4 c=vec4(0); mainImage(c, vec2(gl_FragCoord.x, iResolution.y-gl_FragCoord.y)); st_out=vec4(c.rgb,1.); }
'''

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
for m in json.load(open(os.path.join(HERE, 'manifest.json'))):
    key = m['key']
    src = open(os.path.join(HERE, f'{key}.glsl')).read()
    with tempfile.TemporaryDirectory() as tmp:
        frag, spv = os.path.join(tmp, f'{key}.frag'), os.path.join(tmp, f'{key}.spv')
        open(frag, 'w').write(HEAD + src + TAIL)
        r = subprocess.run(['glslangValidator', '-V', '-S', 'frag', '-o', spv, frag], capture_output=True, text=True)
        if r.returncode:
            sys.exit(f'{key}: glslang failed\n{r.stdout}{r.stderr}')
        r = subprocess.run(['spirv-cross', '--msl', '--msl-version', '20300', '--force-zero-initialized-variables',
                            spv, '--output', os.path.join(out, f'{key}.metal')], capture_output=True, text=True)
        if r.returncode:
            sys.exit(f'{key}: spirv-cross failed\n{r.stdout}{r.stderr}')
    print('metal:', key)
