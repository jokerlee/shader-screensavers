import json,sys,os
src=sys.argv[1]; out=sys.argv[2]
s=json.load(open(src))
rp=s['renderpass']; img=[r for r in rp if r['type']=='image'][0]
common=''.join(r['code']+'\n' for r in rp if r['type']=='common')
head='''#version 450
layout(location=0) out vec4 st_out;
layout(std140, binding=0) uniform ST { vec3 iResolution; float iTime; vec4 iMouse; vec4 iDate; float iTimeDelta; int iFrame; float iFrameRate; float iSampleRate; vec3 iChannelResolution[4]; float iChannelTime[4]; };
layout(binding=1) uniform sampler2D iChannel0;
layout(binding=2) uniform sampler2D iChannel1;
layout(binding=3) uniform sampler2D iChannel2;
layout(binding=4) uniform sampler2D iChannel3;
#define texture2D texture
'''
tail='''
void main(){ vec4 c=vec4(0); mainImage(c, vec2(gl_FragCoord.x, iResolution.y-gl_FragCoord.y)); st_out=vec4(c.rgb,1.); }
'''
import re
code=re.sub(r'void\s+mainImage\s*\(\s*out\s+vec4', 'void mainImage(inout vec4', img['code'])
open(out,'w').write(head+common+code+tail)
