#!/usr/bin/env python3
"""One-off: create shaders/<key>.glsl (compile source) and shaders/manifest.json from the Shadertoy
JSON saved in candidates/src (repository root). The overlay text, shaders/<key>.excerpt.glsl, is a
hand-picked verbatim excerpt of each original and is maintained by hand.

Compile sources are the originals verbatim, except where a file already exists in shaders/
(hand ports: flowingwires, balatroswirl, and the OpenProcessing p5.js shaders converted from
candidates/xhs/glsl with a cover zoom) and colorfulinfinity (one output-identical speed fix).
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')
SRC = os.path.join(ROOT, 'candidates', 'src')
OUT = os.path.join(os.path.dirname(__file__), '..', 'shaders')

SHADERS = [
    # key, shadertoy id, display title, author, license, enabled by default, channel textures
    ('flowingwires', 'DsBczR', 'Flowing Wires', 'kishimisu', 'CC BY-NC-SA 4.0', True, {}),
    ('starship', 'l3cfW4', 'Starship', 'Xor', 'CC BY-NC-SA 3.0', True, {'0': 'starship_iChannel0.jpg'}),
    ('fractalpyramid', 'tsXBzS', 'Fractal Pyramid', 'bradjamesgrant', 'CC BY-NC-SA 3.0', True, {}),
    ('simplicity', 'lslGWr', 'Simplicity', 'JoshP', 'CC BY-NC-SA 3.0', True, {}),
    ('singularity', '3csSWB', 'Singularity', 'Xor', 'CC BY-NC-SA 3.0', True, {}),
    ('ether', 'MsjSW3', 'Ether', 'nimitz', 'CC BY-NC-SA 3.0', True, {}),
    ('colorfulinfinity', 'WtjyzR', 'Path to the colorful infinity', 'benoitM', 'CC BY-NC-SA 3.0', True, {}),
    ('balatroswirl', None, 'Balatro background', 'LocalThunk · port xxidbr9', 'personal use only', True, {}),
    ('spiraliris', None, 'Shader_240422-4', 'SamuelYAN', 'CC BY-NC-SA', True, {}),
    ('membrane', None, 'untitled 2026_0203_3', 'SamuelYAN', 'CC BY-NC-SA', True, {}),
    ('motes', None, '2026_0131', 'SamuelYAN', 'CC BY-NC-SA', True, {}),
    ('hiddenline', None, 'GENUARY 2026_0120', 'SamuelYAN', 'CC BY-NC-SA', True, {}),
    ('apollonian4d', 'N3VXz1', 'Yet Another 4D Apollonian', 'mrange', 'CC0', True, {}),
]

# shaders that are not on Shadertoy (or whose Shadertoy page is a port)
LINKS = {
    'balatroswirl': 'shadertoy.com/view/XXtBRr',
    'spiraliris': 'openprocessing.org/sketch/2247937',
    'membrane': 'openprocessing.org/sketch/2862539',
    'motes': 'openprocessing.org/sketch/2860882',
    'hiddenline': 'openprocessing.org/sketch/2851315',
}


def original_code(sid):
    path = f'{SRC}/{sid}.json'
    if not os.path.exists(path):
        path = f'{SRC}/../xhs/src/{sid}.json'
    d = json.load(open(path))
    return [r for r in d['renderpass'] if r['type'] == 'image'][0]['code']


manifest = []
for key, sid, title, author, lic, enabled, channels in SHADERS:
    comp = os.path.join(OUT, f'{key}.glsl')
    if sid is not None:
        code = original_code(sid)
        if key == 'colorfulinfinity':
            code = code.replace('o/dot(o,o)', 'o*(1./dot(o,o))')
        if not os.path.exists(comp) or key == 'colorfulinfinity':
            open(comp, 'w').write(code)
    link = LINKS.get(key) or f'shadertoy.com/view/{sid}'
    manifest.append({'key': key, 'title': title, 'author': author, 'license': lic, 'link': link,
                     'enabledByDefault': enabled, 'channels': channels})

json.dump(manifest, open(os.path.join(OUT, 'manifest.json'), 'w'), indent=2, ensure_ascii=False)
print('\n'.join(f"{m['key']:18} {m['title']} — {m['author']}" for m in manifest))
