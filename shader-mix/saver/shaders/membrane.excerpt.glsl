vec2 pw = warp(p);
// ...
float ang = u_time * 0.4 + hash(seed) * 6.28318;
vec2 dir  = vec2(cos(ang), sin(ang));
// ...
col += lc * light * flicker * pulse;
// ...
float mask = smoothstep( 0.03, -0.03, blob(pw, 0.85, life) );
col /= mask;
col -= smoothstep(0.2, 0.6, length(pw)) * 0.8;
